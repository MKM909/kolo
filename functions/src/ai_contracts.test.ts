import assert from "node:assert/strict";
import test from "node:test";
import {
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
