import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";

test("Gemini callable exports use typed AI contract schemas", () => {
  const source = readFileSync("src/index.ts", "utf8");

  assert.match(source, /transactionCategorizationSchema/);
  assert.match(source, /interventionMessageSchema/);
  assert.match(source, /reminderDraftSchema/);
  assert.match(source, /weeklyInsightSchema/);
  assert.doesNotMatch(source, /simpleTextFlow/);
});
