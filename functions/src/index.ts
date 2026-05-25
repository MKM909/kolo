import {genkit, z} from "genkit";
import {googleAI} from "@genkit-ai/googleai";
import {onCallGenkit} from "firebase-functions/https";
import {
  fallbackInterventionMessage,
  fallbackReminderDraft,
  fallbackTransactionCategorization,
  fallbackWeeklyInsight,
  interventionInputSchema,
  interventionMessageSchema,
  reminderDraftSchema,
  reminderInputSchema,
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
export const categorizeTransaction = onCallGenkit(categorizeTransactionFlow);
export const draftReminder = onCallGenkit(draftReminderFlow);
export const analyzeSpending = onCallGenkit(analyzeSpendingFlow);
