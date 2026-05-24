import {genkit, z} from "genkit";
import {googleAI, gemini20Flash} from "@genkit-ai/googleai";
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

const ai = genkit({
  plugins: [googleAI()],
  model: gemini20Flash,
});

const chatSchema = z.object({
  message: z.string().min(1),
  context: z.object({
    balanceKobo: z.number(),
    budgetCategories: z.array(
      z.object({name: z.string(), allocatedKobo: z.number()}),
    ),
    recentTransactions: z.array(
      z.object({
        amountKobo: z.number(),
        type: z.string(),
        category: z.string(),
        description: z.string(),
      }),
    ),
    vaults: z.array(
      z.object({
        name: z.string(),
        targetKobo: z.number(),
        currentKobo: z.number(),
      }),
    ),
  }),
});

const budgetSchema = z.object({
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
  async ({message, context}, {context: flowContext}) => {
    requireCallableAuth(flowContext);
    const response = await ai.generate({
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
  async ({answers}, {context: flowContext}) => {
    requireCallableAuth(flowContext);
    const balance = answers.currentBalanceKobo;
    const response = await ai.generate({
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
    inputSchema: interventionInputSchema,
    outputSchema: interventionMessageSchema,
  },
  async ({context: inputContext}, {context: flowContext}) => {
    requireCallableAuth(flowContext);
    const response = await ai.generate({
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
    inputSchema: transactionCategorizationInputSchema,
    outputSchema: transactionCategorizationSchema,
  },
  async (input, {context: flowContext}) => {
    requireCallableAuth(flowContext);
    const response = await ai.generate({
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
    inputSchema: reminderInputSchema,
    outputSchema: reminderDraftSchema,
  },
  async (input, {context: flowContext}) => {
    requireCallableAuth(flowContext);
    const response = await ai.generate({
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
    inputSchema: weeklyInsightInputSchema,
    outputSchema: weeklyInsightSchema,
  },
  async ({context: inputContext}, {context: flowContext}) => {
    requireCallableAuth(flowContext);
    const response = await ai.generate({
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
