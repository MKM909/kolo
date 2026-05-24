export type KoloAiContext = {
  balanceKobo: number;
  budgetCategories: Array<{name: string; allocatedKobo: number}>;
  recentTransactions: Array<{
    amountKobo: number;
    type: string;
    category: string;
    description: string;
  }>;
  vaults: Array<{name: string; targetKobo: number; currentKobo: number}>;
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
    `Budget categories: ${context.budgetCategories
      .map((category) => `${category.name} ${nairaFromKobo(category.allocatedKobo)}`)
      .join(", ")}.`,
    `Recent transactions: ${context.recentTransactions
      .map((tx) => `${tx.type} ${nairaFromKobo(tx.amountKobo)} ${tx.category}: ${tx.description}`)
      .join("; ")}.`,
    `Vaults: ${context.vaults
      .map((vault) => `${vault.name} ${nairaFromKobo(vault.currentKobo)} saved`)
      .join(", ")}.`,
    `User asks: ${message}`,
    "Answer with concrete Naira amounts and one clear recommendation.",
  ].join("\n");
}
