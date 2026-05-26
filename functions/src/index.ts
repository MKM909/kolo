import {createHash} from "node:crypto";
import {genkit, z} from "genkit";
import {googleAI} from "@genkit-ai/googleai";
import {HttpsError, onCall, onCallGenkit} from "firebase-functions/https";
import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {
  fallbackInterventionMessage,
  fallbackReminderDraft,
  fallbackSpendingJustificationDecision,
  fallbackTransactionCategorization,
  fallbackWeeklyInsight,
  interventionInputSchema,
  interventionMessageSchema,
  reminderDraftSchema,
  reminderInputSchema,
  smsReceivedInputSchema,
  smsReceivedOutputSchema,
  spendingJustificationDecisionSchema,
  spendingJustificationInputSchema,
  transactionCategorizationInputSchema,
  transactionCategorizationSchema,
  weeklyInsightInputSchema,
  weeklyInsightSchema,
} from "./ai_contracts.js";
import {requireCallableAuth} from "./callable_guards.js";
import {buildChatPrompt, KoloAiContext} from "./prompts.js";

const DEFAULT_GEMINI_MODEL = "gemini-3.1-flash-lite";
const SUPPORTED_KOLO_GEMINI_MODELS = [
  DEFAULT_GEMINI_MODEL,
  "gemini-3.1-flash",
  "gemini-3.1-pro",
] as const;
const modelNameSchema = z.enum(SUPPORTED_KOLO_GEMINI_MODELS);
const geminiApiKey = process.env.GEMINI_API_KEY;
if (getApps().length === 0) initializeApp();
const firestore = getFirestore();

const ai = genkit({
  plugins: [geminiApiKey ? googleAI({apiKey: geminiApiKey}) : googleAI()],
  model: googleAI.model(DEFAULT_GEMINI_MODEL),
});

function resolveGeminiModelName(model?: string | null): string {
  if (
    model &&
    SUPPORTED_KOLO_GEMINI_MODELS.includes(
      model as (typeof SUPPORTED_KOLO_GEMINI_MODELS)[number],
    )
  ) {
    return model;
  }
  return DEFAULT_GEMINI_MODEL;
}

function selectedGeminiModel(model?: string | null) {
  return googleAI.model(resolveGeminiModelName(model));
}

function smsDedupKey(input: z.infer<typeof smsReceivedInputSchema>): string {
  const sourceEventId = input.sourceEventId?.trim();
  const basis =
    sourceEventId && sourceEventId.length > 0
      ? `event:${sourceEventId}`
      : `sms:${input.sender ?? ""}:${input.receivedAt ?? ""}:${input.rawText}`;
  return createHash("sha256").update(basis).digest("hex").slice(0, 40);
}

function smsTransactionId(
  input: z.infer<typeof smsReceivedInputSchema>,
): string {
  return `sms_${smsDedupKey(input)}`;
}

function smsAiMessageId(input: z.infer<typeof smsReceivedInputSchema>): string {
  return `${smsTransactionId(input)}_ai`;
}

const chatSchema = z.object({
  message: z.string().min(1),
  model: modelNameSchema.optional(),
  context: z.object({
    balanceKobo: z.number(),
    spendableBalanceKobo: z.number().optional(),
    vaultProtectionKobo: z.number().optional(),
    daysSinceLastIncome: z.number().nullable().optional(),
    periodTotals: z
      .object({
        incomeKobo: z.number(),
        expenseKobo: z.number(),
        savingsKobo: z.number(),
      })
      .optional(),
    budgetCategories: z.array(
      z.object({
        name: z.string(),
        allocatedKobo: z.number(),
        spentKobo: z.number().optional(),
        remainingKobo: z.number().optional(),
        progress: z.number().optional(),
      }),
    ),
    recentTransactions: z.array(
      z.object({
        amountKobo: z.number(),
        type: z.string(),
        category: z.string(),
        description: z.string(),
        date: z.string().optional(),
        source: z.string().optional(),
        merchantName: z.string().nullable().optional(),
      }),
    ),
    vaults: z.array(
      z.object({
        name: z.string(),
        targetKobo: z.number(),
        currentKobo: z.number(),
        deadline: z.string().nullable().optional(),
      }),
    ),
    owings: z
      .array(
        z.object({
          person: z.string(),
          amountKobo: z.number(),
          type: z.string(),
          settled: z.boolean(),
          dueDate: z.string().nullable().optional(),
        }),
      )
      .optional(),
    bills: z
      .array(
        z.object({
          name: z.string(),
          amountKobo: z.number(),
          frequency: z.string(),
          nextDue: z.string(),
          active: z.boolean(),
          daysUntilDue: z.number(),
        }),
      )
      .optional(),
    dueBills: z
      .array(
        z.object({
          name: z.string(),
          amountKobo: z.number(),
          frequency: z.string(),
          nextDue: z.string(),
          active: z.boolean(),
          daysUntilDue: z.number(),
        }),
      )
      .optional(),
    gigSummary: z
      .object({
        totalThisMonthKobo: z.number(),
        totalThisYearKobo: z.number(),
        daysSinceLastGig: z.number().nullable().optional(),
      })
      .optional(),
    spendingPatterns: z
      .object({
        byWeekday: z
          .array(
            z.object({
              weekday: z.string(),
              expenseKobo: z.number(),
              transactionCount: z.number(),
            }),
          )
          .optional(),
        byTimeOfDay: z
          .array(
            z.object({
              window: z.string(),
              expenseKobo: z.number(),
              transactionCount: z.number(),
            }),
          )
          .optional(),
        byCategoryTimeOfDay: z
          .array(
            z.object({
              category: z.string(),
              window: z.string(),
              expenseKobo: z.number(),
              transactionCount: z.number(),
            }),
          )
          .optional(),
      })
      .optional(),
  }),
});

const budgetSchema = z.object({
  model: modelNameSchema.optional(),
  answers: z.object({
    incomeSource: z.string(),
    incomeFrequency: z.string(),
    currentBalanceKobo: z.number(),
    biggestProblem: z.string(),
    savingsGoal: z.string().optional().nullable(),
  }),
});

const chatFlow = ai.defineFlow(
  {
    name: "chatWithKoloFlow",
    inputSchema: chatSchema,
    outputSchema: z.object({content: z.string()}),
  },
  async ({message, context, model}, {context: flowContext}) => {
    requireCallableAuth(flowContext);
    const response = await ai.generate({
      model: selectedGeminiModel(model),
      prompt: buildChatPrompt(message, context as KoloAiContext),
    });
    return {content: response.text};
  },
);

const generateBudgetFlow = ai.defineFlow(
  {
    name: "generateBudgetFlow",
    inputSchema: budgetSchema,
    outputSchema: z.object({
      monthlyIncomeKobo: z.number(),
      incomeType: z.string(),
      savingsTargetKobo: z.number(),
      savingsGoal: z.string(),
      aiNotes: z.string(),
      categories: z.array(
        z.object({
          name: z.string(),
          emoji: z.string(),
          allocatedKobo: z.number(),
          priority: z.number(),
        }),
      ),
    }),
  },
  async ({answers, model}, {context: flowContext}) => {
    requireCallableAuth(flowContext);
    const balance = answers.currentBalanceKobo;
    const response = await ai.generate({
      model: selectedGeminiModel(model),
      prompt: [
        "Create a strict but kind Nigerian Naira budget for Kolo.",
        `Income source: ${answers.incomeSource}.`,
        `Frequency: ${answers.incomeFrequency}.`,
        `Current balance kobo: ${balance}.`,
        `Biggest problem: ${answers.biggestProblem}.`,
        `Savings goal: ${answers.savingsGoal ?? "Emergency buffer"}.`,
        "Return JSON only with monthlyIncomeKobo, incomeType, savingsTargetKobo, savingsGoal, aiNotes, categories.",
      ].join("\n"),
      output: {
        schema: z.object({
          monthlyIncomeKobo: z.number(),
          incomeType: z.string(),
          savingsTargetKobo: z.number(),
          savingsGoal: z.string(),
          aiNotes: z.string(),
          categories: z.array(
            z.object({
              name: z.string(),
              emoji: z.string(),
              allocatedKobo: z.number(),
              priority: z.number(),
            }),
          ),
        }),
      },
    });
    return response.output!;
  },
);

const interventionMessageFlow = ai.defineFlow(
  {
    name: "interventionMessageFlow",
    inputSchema: interventionInputSchema.extend({
      model: modelNameSchema.optional(),
    }),
    outputSchema: interventionMessageSchema,
  },
  async ({context: inputContext, model}, {context: flowContext}) => {
    requireCallableAuth(flowContext);
    const response = await ai.generate({
      model: selectedGeminiModel(model),
      prompt: [
        "Write a short Kolo spending intervention.",
        "Use Nigerian Naira context. Be warm, direct, and never shame the user.",
        `Context JSON: ${JSON.stringify(inputContext ?? {})}`,
      ].join("\n"),
      output: {schema: interventionMessageSchema},
    });
    return response.output ?? fallbackInterventionMessage();
  },
);

const evaluateSpendingJustificationFlow = ai.defineFlow(
  {
    name: "evaluateSpendingJustificationFlow",
    inputSchema: spendingJustificationInputSchema.extend({
      model: modelNameSchema.optional(),
    }),
    outputSchema: spendingJustificationDecisionSchema,
  },
  async (input, {context: flowContext}) => {
    requireCallableAuth(flowContext);
    const response = await ai.generate({
      model: selectedGeminiModel(input.model),
      prompt: [
        "Evaluate this Kolo spending justification.",
        "Return approved, caution, or advisedAgainst. Be warm, direct, and never shame the user.",
        `Transaction JSON: ${JSON.stringify(input.transaction)}`,
        `User justification: ${input.justification}`,
        `Financial context JSON: ${JSON.stringify(input.context ?? {})}`,
      ].join("\n"),
      output: {schema: spendingJustificationDecisionSchema},
    });
    return response.output ?? fallbackSpendingJustificationDecision();
  },
);

const categorizeTransactionFlow = ai.defineFlow(
  {
    name: "categorizeTransactionFlow",
    inputSchema: transactionCategorizationInputSchema.extend({
      model: modelNameSchema.optional(),
    }),
    outputSchema: transactionCategorizationSchema,
  },
  async (input, {context: flowContext}) => {
    requireCallableAuth(flowContext);
    const response = await ai.generate({
      model: selectedGeminiModel(input.model),
      prompt: [
        "Categorize this Nigerian transaction for Kolo.",
        "Return amount in kobo, type, category, description, merchant name, confidence, and reason.",
        `Source: ${input.source ?? "unknown"}.`,
        `Raw text: ${input.rawText}`,
        `Context JSON: ${JSON.stringify(input.context ?? {})}`,
      ].join("\n"),
      output: {schema: transactionCategorizationSchema},
    });
    return response.output ?? fallbackTransactionCategorization(input);
  },
);

const onSmsReceivedFlow = ai.defineFlow(
  {
    name: "onSmsReceivedFlow",
    inputSchema: smsReceivedInputSchema.extend({
      model: modelNameSchema.optional(),
    }),
    outputSchema: smsReceivedOutputSchema,
  },
  async (input, {context: flowContext}) => {
    const uid = requireCallableAuth(flowContext);
    const response = await ai.generate({
      model: selectedGeminiModel(input.model),
      prompt: [
        "Parse this Nigerian bank SMS for Kolo and return a transaction draft.",
        "Use kobo for amountKobo. Choose income for credits and expense for debits.",
        "If present, return the bank-reported balance after the alert as balanceAfterKobo and the transaction time as occurredAt in ISO-8601 format.",
        `Sender: ${input.sender ?? "unknown"}.`,
        `Raw SMS: ${input.rawText}`,
        `Context JSON: ${JSON.stringify(input.context ?? {})}`,
      ].join("\n"),
      output: {schema: transactionCategorizationSchema},
    });
    const transaction =
      response.output ??
      fallbackTransactionCategorization({
        rawText: input.rawText,
        source: "sms",
        context: input.context,
      });
    const transactionDate = parseDateOrNow(transaction.occurredAt ?? input.receivedAt);
    const userRef = firestore.collection("users").doc(uid);
    const dedupKey = smsDedupKey(input);
    const transactionRef = userRef
      .collection("transactions")
      .doc(smsTransactionId(input));
    const aiMessageRef = userRef
      .collection("aiMessages")
      .doc(smsAiMessageId(input));
    const deltaKobo =
      transaction.type === "income"
        ? transaction.amountKobo
        : -transaction.amountKobo;
    const aiMessage = smsAiMessage(transaction);
    const balanceUpdate =
      typeof transaction.balanceAfterKobo === "number"
        ? {balanceKobo: transaction.balanceAfterKobo}
        : {balanceKobo: FieldValue.increment(deltaKobo)};

    await firestore.runTransaction(async (dbTransaction) => {
      const existingTransaction = await dbTransaction.get(transactionRef);
      if (existingTransaction.exists) return;

      dbTransaction.set(transactionRef, {
        amountKobo: transaction.amountKobo,
        type: transaction.type,
        category: transaction.category,
        description: transaction.description,
        source: "sms",
        date: Timestamp.fromDate(transactionDate),
        merchantName: transaction.merchantName ?? null,
        occurredAt: transaction.occurredAt ?? null,
        balanceAfterKobo: transaction.balanceAfterKobo ?? null,
        aiApproved: null,
        aiNote: transaction.reason,
        rawText: input.rawText,
        sourceEventId: input.sourceEventId ?? null,
        dedupKey,
        sender: input.sender ?? null,
        createdAt: FieldValue.serverTimestamp(),
      });
      dbTransaction.set(aiMessageRef, {
        role: "assistant",
        content: aiMessage.content,
        timestamp: Timestamp.fromDate(new Date()),
        context: "sms_transaction",
      });
      dbTransaction.set(
        userRef,
        balanceUpdate,
        {merge: true},
      );
    });

    return {
      transactionId: transactionRef.id,
      aiMessageId: aiMessageRef.id,
      transaction,
      aiMessage,
    };
  },
);

const draftReminderFlow = ai.defineFlow(
  {
    name: "draftReminderFlow",
    inputSchema: reminderInputSchema.extend({
      model: modelNameSchema.optional(),
    }),
    outputSchema: reminderDraftSchema,
  },
  async (input, {context: flowContext}) => {
    requireCallableAuth(flowContext);
    const response = await ai.generate({
      model: selectedGeminiModel(input.model),
      prompt: [
        "Draft a polite money reminder message for Kolo.",
        `Person: ${input.owing.person}.`,
        `Amount kobo: ${input.owing.amountKobo}.`,
        `Note: ${input.owing.note ?? "none"}.`,
        `Context JSON: ${JSON.stringify(input.context ?? {})}`,
      ].join("\n"),
      output: {schema: reminderDraftSchema},
    });
    return response.output ?? fallbackReminderDraft(input);
  },
);

const analyzeSpendingFlow = ai.defineFlow(
  {
    name: "analyzeSpendingFlow",
    inputSchema: weeklyInsightInputSchema.extend({
      model: modelNameSchema.optional(),
    }),
    outputSchema: weeklyInsightSchema,
  },
  async ({context: inputContext, model}, {context: flowContext}) => {
    requireCallableAuth(flowContext);
    const response = await ai.generate({
      model: selectedGeminiModel(model),
      prompt: [
        "Summarize one weekly Kolo spending insight.",
        "Return a title, body, optional category, and severity.",
        `Context JSON: ${JSON.stringify(inputContext ?? {})}`,
      ].join("\n"),
      output: {schema: weeklyInsightSchema},
    });
    return response.output ?? fallbackWeeklyInsight();
  },
);

export const chatWithKolo = onCallGenkit(chatFlow);
export const generateBudget = onCallGenkit(generateBudgetFlow);
export const interventionMessage = onCallGenkit(interventionMessageFlow);
export const evaluateSpendingJustification = onCallGenkit(
  evaluateSpendingJustificationFlow,
);
export const categorizeTransaction = onCallGenkit(categorizeTransactionFlow);
export const onSmsReceived = onCallGenkit(onSmsReceivedFlow);
export const draftReminder = onCallGenkit(draftReminderFlow);
export const analyzeSpending = onCallGenkit(analyzeSpendingFlow);

export const acceptPartnerShare = onCall(async (request) => {
  if (!request.auth?.uid || !request.auth.token.email) {
    throw new HttpsError("unauthenticated", "Sign in to accept a share.");
  }
  const uid = request.auth.uid;
  const partnerEmail = request.auth.token.email;

  const ownerUid = String(request.data?.ownerUid ?? "");
  const shareId = String(request.data?.shareId ?? "");
  if (!ownerUid || !shareId) {
    throw new HttpsError("invalid-argument", "ownerUid and shareId are required.");
  }
  if (ownerUid === uid) {
    throw new HttpsError("failed-precondition", "Owners cannot accept their own share.");
  }

  const ownerRef = firestore.collection("users").doc(ownerUid);
  const shareRef = ownerRef.collection("partnerShares").doc(shareId);
  const summaryRef = ownerRef.collection("partnerSummaries").doc(shareId);
  const shareSnapshot = await shareRef.get();
  if (!shareSnapshot.exists) {
    throw new HttpsError("not-found", "Partner share not found.");
  }

  const share = shareSnapshot.data() ?? {};
  const invitedEmail = String(share.partnerEmail ?? "").toLowerCase();
  if (invitedEmail !== partnerEmail.toLowerCase()) {
    throw new HttpsError("permission-denied", "This invite is for another email.");
  }
  if (share.status === "revoked") {
    throw new HttpsError("failed-precondition", "This partner share was revoked.");
  }

  const permissions = Array.isArray(share.permissions) ? share.permissions : [];
  const batch = firestore.batch();
  batch.set(
    shareRef,
    {
      status: "active",
      acceptedByUid: uid,
      acceptedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  batch.set(
    summaryRef,
    {
      shareId,
      ownerUid,
      partnerEmail,
      status: "active",
      permissions,
      sections: {},
      generatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  await batch.commit();

  return {
    ownerUid,
    shareId,
    status: "active",
    partnerEmail,
    permissions,
  };
});

function parseDateOrNow(value?: string | null): Date {
  if (!value) return new Date();
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return new Date();
  return parsed;
}

function smsAiMessage(transaction: z.infer<typeof transactionCategorizationSchema>) {
  const verb = transaction.type === "income" ? "credit" : "debit";
  const amount = `NGN ${(transaction.amountKobo / 100).toLocaleString("en-NG", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
  return {
    content: `SMS ${verb} noted: ${amount} for ${transaction.description}.`,
    severity: transaction.type === "expense" ? "caution" as const : "safe" as const,
    suggestedAction:
      transaction.type === "expense"
        ? "Review the category if this was not right."
        : "Consider assigning this income to your current budget.",
  };
}
