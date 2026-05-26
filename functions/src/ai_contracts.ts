import {z} from "genkit";

export const transactionCategorizationInputSchema = z.object({
  rawText: z.string().min(1).max(2000),
  source: z.enum(["sms", "notification", "manual", "watchedApp"]).optional(),
  context: z.record(z.string(), z.unknown()).optional(),
});

export const transactionCategorizationSchema = z.object({
  amountKobo: z.number().int().nonnegative(),
  type: z.enum(["income", "expense"]),
  category: z.string().min(1),
  description: z.string().min(1),
  merchantName: z.string().optional().nullable(),
  occurredAt: z.string().optional().nullable(),
  balanceAfterKobo: z.number().int().nonnegative().optional().nullable(),
  confidence: z.number().min(0).max(1),
  reason: z.string().min(1),
});

export type TransactionCategorizationInput = z.infer<
  typeof transactionCategorizationInputSchema
>;
export type TransactionCategorization = z.infer<
  typeof transactionCategorizationSchema
>;

export const smsReceivedInputSchema = z.object({
  rawText: z.string().min(1).max(2000),
  sourceEventId: z.string().optional().nullable(),
  sender: z.string().optional().nullable(),
  receivedAt: z.string().optional().nullable(),
  context: z.record(z.string(), z.unknown()).optional(),
});

export const smsReceivedOutputSchema = z.object({
  transactionId: z.string().min(1),
  aiMessageId: z.string().min(1),
  transaction: transactionCategorizationSchema,
  aiMessage: z.object({
    content: z.string().min(1),
    severity: z.enum(["safe", "caution", "stop"]),
    suggestedAction: z.string().min(1),
  }),
});

export type SmsReceivedInput = z.infer<typeof smsReceivedInputSchema>;
export type SmsReceivedOutput = z.infer<typeof smsReceivedOutputSchema>;

export const interventionInputSchema = z.object({
  context: z.record(z.string(), z.unknown()).optional(),
});

export const interventionMessageSchema = z.object({
  content: z.string().min(1),
  severity: z.enum(["safe", "caution", "stop"]),
  suggestedAction: z.string().min(1),
});

export type InterventionMessage = z.infer<typeof interventionMessageSchema>;

export const spendingJustificationInputSchema = z.object({
  transaction: z.object({
    amountKobo: z.number().int().nonnegative(),
    type: z.enum(["income", "expense"]),
    category: z.string().min(1),
    description: z.string().min(1),
    source: z
      .enum(["sms", "notification", "manual", "watchedApp"])
      .optional(),
    merchantName: z.string().optional().nullable(),
  }),
  justification: z.string().min(1).max(2000),
  context: z.record(z.string(), z.unknown()).optional(),
});

export const spendingJustificationDecisionSchema = z.object({
  status: z.enum(["approved", "caution", "advisedAgainst"]),
  message: z.string().min(1),
  aiNote: z.string().min(1),
});

export type SpendingJustificationInput = z.infer<
  typeof spendingJustificationInputSchema
>;
export type SpendingJustificationDecision = z.infer<
  typeof spendingJustificationDecisionSchema
>;

export const reminderInputSchema = z.object({
  owing: z.object({
    person: z.string().min(1),
    amountKobo: z.number().int().nonnegative(),
    note: z.string().optional().nullable(),
  }),
  context: z.record(z.string(), z.unknown()).optional(),
});

export const reminderDraftSchema = z.object({
  message: z.string().min(1),
  tone: z.enum(["friendly", "firm", "urgent"]),
});

export type ReminderInput = z.infer<typeof reminderInputSchema>;
export type ReminderDraft = z.infer<typeof reminderDraftSchema>;

export const weeklyInsightInputSchema = z.object({
  context: z.record(z.string(), z.unknown()).optional(),
});

export const weeklyInsightSchema = z.object({
  title: z.string().min(1),
  body: z.string().min(1),
  category: z.string().optional().nullable(),
  severity: z.enum(["safe", "warning", "risk"]),
});

export type WeeklyInsight = z.infer<typeof weeklyInsightSchema>;

export function fallbackTransactionCategorization(
  input: TransactionCategorizationInput,
): TransactionCategorization {
  return {
    amountKobo: 0,
    type: "expense",
    category: "Miscellaneous",
    description: input.rawText.slice(0, 120),
    merchantName: null,
    confidence: 0,
    reason: "Gemini did not return a structured transaction draft.",
  };
}

export function fallbackInterventionMessage(): InterventionMessage {
  return {
    content: "Pause for a moment and check your Kolo balance before spending.",
    severity: "caution",
    suggestedAction: "Open Kolo and review today's budget.",
  };
}

export function fallbackSpendingJustificationDecision():
  SpendingJustificationDecision {
  return {
    status: "caution",
    message:
      "I could not fully evaluate this right now. If it matters, log it with a note and I will keep it visible.",
    aiNote: "Caution - Gemini unavailable, user explanation kept for history.",
  };
}

export function fallbackReminderDraft(input: ReminderInput): ReminderDraft {
  return {
    message: `Hi ${input.owing.person}, gentle reminder about the ${formatKobo(
      input.owing.amountKobo,
    )} we noted. Please send it when you can.`,
    tone: "friendly",
  };
}

export function fallbackWeeklyInsight(): WeeklyInsight {
  return {
    title: "Spending pattern needs more data",
    body: "Kolo needs more transactions before it can produce a confident weekly insight.",
    category: null,
    severity: "safe",
  };
}

function formatKobo(kobo: number): string {
  return `NGN ${(kobo / 100).toLocaleString("en-NG", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}
