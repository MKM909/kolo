export type KoloAiContext = {
  balanceKobo: number;
  spendableBalanceKobo?: number;
  vaultProtectionKobo?: number;
  daysSinceLastIncome?: number | null;
  periodTotals?: {
    incomeKobo: number;
    expenseKobo: number;
    savingsKobo: number;
  };
  budgetCategories: Array<{
    name: string;
    allocatedKobo: number;
    spentKobo?: number;
    remainingKobo?: number;
    progress?: number;
  }>;
  recentTransactions: Array<{
    amountKobo: number;
    type: string;
    category: string;
    description: string;
    date?: string;
    source?: string;
    merchantName?: string | null;
  }>;
  vaults: Array<{
    name: string;
    targetKobo: number;
    currentKobo: number;
    deadline?: string | null;
  }>;
  owings?: Array<{
    person: string;
    amountKobo: number;
    type: string;
    settled: boolean;
    dueDate?: string | null;
  }>;
  bills?: Array<{
    name: string;
    amountKobo: number;
    frequency: string;
    nextDue: string;
    active: boolean;
    daysUntilDue: number;
  }>;
  dueBills?: Array<{
    name: string;
    amountKobo: number;
    frequency: string;
    nextDue: string;
    active: boolean;
    daysUntilDue: number;
  }>;
  gigSummary?: {
    totalThisMonthKobo: number;
    totalThisYearKobo: number;
    daysSinceLastGig?: number | null;
  };
  spendingPatterns?: {
    byWeekday?: Array<{
      weekday: string;
      expenseKobo: number;
      transactionCount: number;
    }>;
    byTimeOfDay?: Array<{
      window: string;
      expenseKobo: number;
      transactionCount: number;
    }>;
    byCategoryTimeOfDay?: Array<{
      category: string;
      window: string;
      expenseKobo: number;
      transactionCount: number;
    }>;
  };
};

export function nairaFromKobo(kobo: number): string {
  return `₦${(kobo / 100).toLocaleString("en-NG", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

export function buildChatPrompt(message: string, context: KoloAiContext): string {
  return [
    "You are Kolo, a warm but direct Nigerian personal money manager.",
    "You do not move money, promise loans, or shame the user.",
    `Current balance: ${nairaFromKobo(context.balanceKobo)}.`,
    `Spendable balance: ${nairaFromKobo(context.spendableBalanceKobo ?? context.balanceKobo)}.`,
    `Vault-protected money: ${nairaFromKobo(context.vaultProtectionKobo ?? 0)}.`,
    `Period totals: income ${nairaFromKobo(context.periodTotals?.incomeKobo ?? 0)}, expenses ${nairaFromKobo(context.periodTotals?.expenseKobo ?? 0)}, savings ${nairaFromKobo(context.periodTotals?.savingsKobo ?? 0)}.`,
    `Days since last income: ${context.daysSinceLastIncome ?? "unknown"}.`,
    `Spending patterns: ${(context.spendingPatterns?.byWeekday ?? [])
      .map(
        (pattern) =>
          `${pattern.weekday} ${nairaFromKobo(pattern.expenseKobo)} across ${pattern.transactionCount} expense${pattern.transactionCount === 1 ? "" : "s"}`,
      )
      .join(", ") || "none"}.`,
    `Time windows: ${(context.spendingPatterns?.byTimeOfDay ?? [])
      .map(
        (pattern) =>
          `${pattern.window} ${nairaFromKobo(pattern.expenseKobo)} across ${pattern.transactionCount} expense${pattern.transactionCount === 1 ? "" : "s"}`,
      )
      .join(", ") || "none"}.`,
    `Category time patterns: ${(context.spendingPatterns?.byCategoryTimeOfDay ?? [])
      .map(
        (pattern) =>
          `${pattern.category} ${pattern.window} ${nairaFromKobo(pattern.expenseKobo)} across ${pattern.transactionCount} expense${pattern.transactionCount === 1 ? "" : "s"}`,
      )
      .join(", ") || "none"}.`,
    `Budget categories: ${context.budgetCategories
      .map(
        (category) =>
          `${category.name} allocated ${nairaFromKobo(category.allocatedKobo)}, spent ${nairaFromKobo(category.spentKobo ?? 0)}, remaining ${nairaFromKobo(category.remainingKobo ?? category.allocatedKobo)}`,
      )
      .join(", ")}.`,
    `Recent transactions: ${context.recentTransactions
      .map(
        (tx) =>
          `${tx.type} ${nairaFromKobo(tx.amountKobo)} ${tx.category}: ${tx.description}${tx.merchantName ? ` at ${tx.merchantName}` : ""}${tx.source ? ` via ${tx.source}` : ""}`,
      )
      .join("; ")}.`,
    `Vaults: ${context.vaults
      .map(
        (vault) =>
          `${vault.name} ${nairaFromKobo(vault.currentKobo)} saved of ${nairaFromKobo(vault.targetKobo)}`,
      )
      .join(", ")}.`,
    `Owings: ${(context.owings ?? [])
      .map(
        (owing) =>
          `${owing.person} ${owing.type === "theyOweMe" ? "owes you" : "is owed"} ${nairaFromKobo(owing.amountKobo)}${owing.settled ? " settled" : ""}${owing.dueDate ? ` due ${owing.dueDate.slice(0, 10)}` : ""}`,
      )
      .join("; ") || "none"}.`,
    `Bills: ${(context.bills ?? [])
      .map(
        (bill) =>
          `${bill.name} ${nairaFromKobo(bill.amountKobo)} ${bill.active ? `in ${bill.daysUntilDue} days` : "paused"}`,
      )
      .join("; ") || "none"}.`,
    `Due bills: ${(context.dueBills ?? [])
      .map((bill) => `${bill.name} ${nairaFromKobo(bill.amountKobo)} in ${bill.daysUntilDue} days`)
      .join(", ") || "none"}.`,
    `Gig income: ${nairaFromKobo(context.gigSummary?.totalThisMonthKobo ?? 0)} this month, ${nairaFromKobo(context.gigSummary?.totalThisYearKobo ?? 0)} this year, last gig ${context.gigSummary?.daysSinceLastGig ?? "unknown"} days ago.`,
    `User asks: ${message}`,
    "Answer with concrete Naira amounts and one clear recommendation.",
  ].join("\n");
}
