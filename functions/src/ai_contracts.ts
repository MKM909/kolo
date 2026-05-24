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
  confidence: z.number().min(0).max(1),
  reason: z.string().min(1),
});

export const interventionInputSchema = z.object({
  context: z.record(z.string(), z.unknown()).optional(),
});

export const interventionMessageSchema = z.object({
  content: z.string().min(1),
  severity: z.enum(["safe", "caution", "stop"]),
  suggestedAction: z.string().min(1),
});

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

export const weeklyInsightInputSchema = z.object({
  context: z.record(z.string(), z.unknown()).optional(),
});

export const weeklyInsightSchema = z.object({
  title: z.string().min(1),
  body: z.string().min(1),
  category: z.string().optional().nullable(),
  severity: z.enum(["safe", "warning", "risk"]),
});
