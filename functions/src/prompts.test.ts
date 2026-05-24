import assert from "node:assert/strict";
import test from "node:test";
import {buildChatPrompt} from "./prompts.js";

test("buildChatPrompt includes rich financial context signals", () => {
  const prompt = buildChatPrompt("Can I buy new shoes?", {
    balanceKobo: 10000000,
    spendableBalanceKobo: 9500000,
    vaultProtectionKobo: 500000,
    daysSinceLastIncome: 4,
    periodTotals: {
      incomeKobo: 2500000,
      expenseKobo: 170000,
      savingsKobo: 500000,
    },
    budgetCategories: [
      {
        name: "Food & Snacks",
        allocatedKobo: 200000,
        spentKobo: 120000,
        remainingKobo: 80000,
        progress: 0.6,
      },
    ],
    recentTransactions: [
      {
        amountKobo: 120000,
        type: "expense",
        category: "Food & Snacks",
        description: "Dinner",
        date: "2026-05-24T20:00:00.000",
        source: "sms",
        merchantName: "Chicken Republic",
      },
    ],
    vaults: [
      {
        name: "Rent",
        targetKobo: 3000000,
        currentKobo: 500000,
        deadline: "2026-08-01T00:00:00.000",
      },
    ],
    dueBills: [
      {
        name: "Data renewal",
        amountKobo: 100000,
        frequency: "monthly",
        nextDue: "2026-05-26T00:00:00.000",
        active: true,
        daysUntilDue: 2,
      },
    ],
    gigSummary: {
      totalThisMonthKobo: 2500000,
      totalThisYearKobo: 2500000,
      daysSinceLastGig: 4,
    },
  });

  assert.match(prompt, /Spendable balance: .*95,000.00/);
  assert.match(prompt, /Vault-protected money: .*5,000.00/);
  assert.match(prompt, /Food & Snacks .*spent .*1,200.00.*remaining .*800.00/);
  assert.match(prompt, /Due bills: Data renewal .*in 2 days/);
  assert.match(prompt, /Gig income: .*25,000.00 this month/);
  assert.match(prompt, /Days since last income: 4/);
});
