import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";

test("Gemini callable exports use typed AI contract schemas", () => {
  const source = readFileSync("src/index.ts", "utf8");

  assert.match(source, /DEFAULT_GEMINI_MODEL = "gemini-3\.1-flash-lite"/);
  assert.match(source, /process\.env\.GEMINI_API_KEY/);
  assert.match(source, /googleAI\.model\(resolveGeminiModelName/);
  assert.match(source, /model: modelNameSchema\.optional\(\)/);
  assert.match(source, /transactionCategorizationSchema/);
  assert.match(source, /interventionMessageSchema/);
  assert.match(source, /reminderDraftSchema/);
  assert.match(source, /weeklyInsightSchema/);
  assert.match(source, /spendingJustificationDecisionSchema/);
  assert.match(source, /spendingJustificationInputSchema/);
  assert.match(source, /smsReceivedInputSchema/);
  assert.match(source, /smsReceivedOutputSchema/);
  assert.match(source, /createHash/);
  assert.match(source, /smsTransactionId\(input\)/);
  assert.match(
    source,
    /collection\("transactions"\)[\s\S]*\.doc\(smsTransactionId\(input\)\)/,
  );
  assert.match(source, /dbTransaction\.get\(transactionRef\)/);
  assert.match(source, /existingTransaction\.exists/);
  assert.match(source, /getFirestore\(\)/);
  assert.match(source, /collection\("transactions"\)/);
  assert.match(source, /collection\("aiMessages"\)/);
  assert.match(source, /balanceKobo: FieldValue\.increment/);
  assert.doesNotMatch(source, /balance: FieldValue\.increment/);
  assert.match(source, /export const onSmsReceived = onCallGenkit/);
  assert.match(source, /export const evaluateSpendingJustification = onCallGenkit/);
  assert.match(source, /export const acceptPartnerShare = onCall/);
  assert.match(source, /partnerShares"\)\.doc\(shareId\)/);
  assert.match(source, /partnerSummaries"\)\.doc\(shareId\)/);
  assert.match(source, /request\.auth\.token\.email/);
  assert.doesNotMatch(source, /simpleTextFlow/);
});
