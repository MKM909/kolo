import assert from "node:assert/strict";
import test from "node:test";
import {
  fallbackInterventionMessage,
  fallbackReminderDraft,
  smsReceivedInputSchema,
  smsReceivedOutputSchema,
  fallbackTransactionCategorization,
  fallbackWeeklyInsight,
  transactionCategorizationSchema,
  interventionMessageSchema,
  weeklyInsightSchema,
} from "./ai_contracts.js";

test("transactionCategorizationSchema accepts a typed transaction draft", () => {
  const parsed = transactionCategorizationSchema.parse({
    amountKobo: 125000,
    type: "expense",
    category: "Food & Snacks",
    description: "Chicken Republic",
    merchantName: "Chicken Republic",
    confidence: 0.92,
    reason: "Merchant name matches restaurant spending.",
  });

  assert.equal(parsed.type, "expense");
  assert.equal(parsed.confidence, 0.92);
});

test("transactionCategorizationSchema rejects unsafe confidence values", () => {
  assert.equal(
    transactionCategorizationSchema.safeParse({
      amountKobo: 125000,
      type: "expense",
      category: "Food & Snacks",
      description: "Chicken Republic",
      confidence: 2,
      reason: "Too confident.",
    }).success,
    false,
  );
});

test("sms received contracts include raw alert text and logged outputs", () => {
  const input = smsReceivedInputSchema.parse({
    rawText: "GTBank debit NGN 1,250 at Chicken Republic",
    sender: "GTBank",
    receivedAt: "2026-05-25T10:00:00.000Z",
  });
  const output = smsReceivedOutputSchema.parse({
    transactionId: "tx-1",
    aiMessageId: "ai-1",
    transaction: {
      amountKobo: 125000,
      type: "expense",
      category: "Food & Snacks",
      description: "Chicken Republic",
      merchantName: "Chicken Republic",
      confidence: 0.9,
      reason: "SMS mentions a known food merchant.",
    },
    aiMessage: {
      content: "GTBank debit noted.",
      severity: "safe",
      suggestedAction: "Keep an eye on food spending.",
    },
  });

  assert.equal(input.sender, "GTBank");
  assert.equal(output.transaction.type, "expense");
  assert.equal(output.transactionId, "tx-1");
});

test("sms received contracts reject empty SMS text", () => {
  assert.equal(
    smsReceivedInputSchema.safeParse({rawText: ""}).success,
    false,
  );
});

test("intervention and insight contracts expose user-facing copy", () => {
  assert.equal(
    interventionMessageSchema.parse({
      content: "Pause before opening the bank app.",
      severity: "caution",
      suggestedAction: "Check today's food spend first.",
    }).severity,
    "caution",
  );

  assert.equal(
    weeklyInsightSchema.parse({
      title: "Late food spending is rising",
      body: "Most food expenses happened after 8pm.",
      severity: "warning",
    }).severity,
    "warning",
  );
});

test("fallback outputs satisfy the typed AI contracts", () => {
  assert.equal(
    transactionCategorizationSchema.safeParse(
      fallbackTransactionCategorization({
        rawText: "POS debit Chicken Republic NGN 1250",
        source: "sms",
      }),
    ).success,
    true,
  );

  assert.equal(
    interventionMessageSchema.safeParse(fallbackInterventionMessage()).success,
    true,
  );
  assert.equal(
    fallbackReminderDraft({
      owing: {
        person: "Sade",
        amountKobo: 1200000,
        note: null,
      },
    }).tone,
    "friendly",
  );
  assert.equal(weeklyInsightSchema.safeParse(fallbackWeeklyInsight()).success, true);
});
