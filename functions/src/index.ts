import {genkit, z} from "genkit";
import {googleAI, gemini20Flash} from "@genkit-ai/googleai";
import {onCallGenkit} from "firebase-functions/https";
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
  async ({message, context}) => {
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
  async ({answers}) => {
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

const simpleTextFlow = (name: string, purpose: string) =>
  ai.defineFlow(
    {
      name,
      inputSchema: z.object({context: z.record(z.string(), z.unknown()).optional()}),
      outputSchema: z.object({content: z.string()}),
    },
    async ({context}) => {
      const response = await ai.generate({
        prompt: `${purpose}\nContext JSON: ${JSON.stringify(context ?? {})}`,
      });
      return {content: response.text};
    },
  );

export const chatWithKolo = onCallGenkit(chatFlow);
export const generateBudget = onCallGenkit(generateBudgetFlow);
export const interventionMessage = onCallGenkit(
  simpleTextFlow("interventionMessageFlow", "Write a short Kolo spending intervention."),
);
export const categorizeTransaction = onCallGenkit(
  simpleTextFlow("categorizeTransactionFlow", "Categorize this Nigerian transaction."),
);
export const draftReminder = onCallGenkit(
  simpleTextFlow("draftReminderFlow", "Draft a polite money reminder message."),
);
export const analyzeSpending = onCallGenkit(
  simpleTextFlow("analyzeSpendingFlow", "Summarize one weekly Kolo spending insight."),
);
