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
  assert.match(source, /smsReceivedInputSchema/);
  assert.match(source, /smsReceivedOutputSchema/);
  assert.match(source, /getFirestore\(\)/);
  assert.match(source, /collection\("transactions"\)/);
  assert.match(source, /collection\("aiMessages"\)/);
  assert.match(source, /export const onSmsReceived = onCallGenkit/);
  assert.doesNotMatch(source, /simpleTextFlow/);
});
