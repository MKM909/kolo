import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/financial_calculator.dart';
import 'package:kolo/domain/services/money_formatter.dart';
import 'package:kolo/domain/services/transaction_parser.dart';

void main() {
  group('MoneyFormatter', () {
    test('formats integer kobo as Nigerian Naira', () {
      expect(MoneyFormatter.formatKobo(5000000), '₦50,000.00');
      expect(MoneyFormatter.formatKobo(-125000), '-₦1,250.00');
    });

    test('parses human Naira input into integer kobo', () {
      expect(MoneyFormatter.parseNairaToKobo('2,500'), 250000);
      expect(MoneyFormatter.parseNairaToKobo('₦1,250.50'), 125050);
      expect(MoneyFormatter.parseNairaToKobo('bad input'), isNull);
    });
  });

  group('FinancialCalculator', () {
    test('summarizes budget progress from transactions and vaults', () {
      final budget = BudgetPlan(
        monthlyIncomeKobo: 12000000,
        incomeType: 'irregular',
        savingsTargetKobo: 2500000,
        savingsGoal: 'New laptop',
        aiNotes: 'Protect savings first.',
        categories: const [
          BudgetCategory(
            name: 'Food & Snacks',
            emoji: '🍜',
            allocatedKobo: 3000000,
            priority: 1,
          ),
          BudgetCategory(
            name: 'Transport',
            emoji: '🚌',
            allocatedKobo: 1500000,
            priority: 2,
          ),
        ],
      );

      final transactions = [
        TransactionRecord.expense(
          id: 'tx-1',
          amountKobo: 1250000,
          category: 'Food & Snacks',
          description: 'Lunch',
          date: DateTime(2026, 5, 20),
          source: TransactionSource.manual,
        ),
        TransactionRecord.income(
          id: 'tx-2',
          amountKobo: 7000000,
          category: 'Gig Income',
          description: 'Design gig',
          date: DateTime(2026, 5, 20),
          source: TransactionSource.manual,
        ),
      ];

      final summary = FinancialCalculator.summarize(
        balanceKobo: 9800000,
        budget: budget,
        transactions: transactions,
        vaults: const [
          SavingsVault(
            id: 'vault-1',
            name: 'New Phone',
            targetKobo: 3000000,
            currentKobo: 900000,
          ),
        ],
      );

      expect(summary.totalIncomeKobo, 7000000);
      expect(summary.totalExpenseKobo, 1250000);
      expect(summary.totalSavingsKobo, 900000);
      expect(summary.categorySpendKobo['Food & Snacks'], 1250000);
      expect(summary.categoryProgress('Food & Snacks'), closeTo(0.416, 0.01));
    });
  });

  group('TransactionParser', () {
    test('parses Nigerian bank debit SMS into a transaction draft', () {
      const sms =
          'GTBank Alert: Acct 0123456789 DR NGN2,500.00 at Chicken Republic. Bal: NGN47,500.00';

      final draft = TransactionParser.parse(sms);

      expect(draft, isNotNull);
      expect(draft!.type, TransactionType.expense);
      expect(draft.amountKobo, 250000);
      expect(draft.merchantName, 'Chicken Republic');
      expect(draft.balanceAfterKobo, 4750000);
      expect(draft.source, TransactionSource.sms);
    });

    test('parses fintech credit notification into a transaction draft', () {
      const notification =
          'Kuda: You received ₦15,000 from Timi Ade. Your balance is ₦22,400';

      final draft = TransactionParser.parse(notification);

      expect(draft, isNotNull);
      expect(draft!.type, TransactionType.income);
      expect(draft.amountKobo, 1500000);
      expect(draft.merchantName, 'Timi Ade');
      expect(draft.balanceAfterKobo, 2240000);
      expect(draft.source, TransactionSource.notification);
    });

    test('parses Zenith credit alerts without keeping date fragments', () {
      const sms =
          'ZenithBank: Acct credited with NGN45,000.00 by ACME LTD on 24-May-2026. Bal: NGN90,000.00';

      final draft = TransactionParser.parse(sms);

      expect(draft, isNotNull);
      expect(draft!.type, TransactionType.income);
      expect(draft.amountKobo, 4500000);
      expect(draft.merchantName, 'ACME LTD');
      expect(draft.balanceAfterKobo, 9000000);
    });

    test('parses Access debit descriptions into airtime category', () {
      const sms =
          'AccessMore: Debit Amt: NGN7,500.00 Desc: MTN AIRTIME Bal: NGN15,000.00';

      final draft = TransactionParser.parse(sms);

      expect(draft, isNotNull);
      expect(draft!.type, TransactionType.expense);
      expect(draft.amountKobo, 750000);
      expect(draft.merchantName, 'MTN AIRTIME');
      expect(draft.category, 'Data & Airtime');
      expect(draft.balanceAfterKobo, 1500000);
    });

    test('parses Polaris POS debit merchant and balance', () {
      const sms =
          'PolarisMobile: Account debit of N3,200.00 for POS/WEB Purchase - Jumia Nigeria. Available Balance: N12,800.00';

      final draft = TransactionParser.parse(sms);

      expect(draft, isNotNull);
      expect(draft!.type, TransactionType.expense);
      expect(draft.amountKobo, 320000);
      expect(draft.merchantName, 'Jumia Nigeria');
      expect(draft.balanceAfterKobo, 1280000);
    });

    test('parses Stanbic credit references as income merchant context', () {
      const sms =
          'Stanbic IBTC: Your account has been credited with NGN30,000.00 Ref: Freelance Logo. Available Bal: NGN45,000.00';

      final draft = TransactionParser.parse(sms);

      expect(draft, isNotNull);
      expect(draft!.type, TransactionType.income);
      expect(draft.amountKobo, 3000000);
      expect(draft.merchantName, 'Freelance Logo');
      expect(draft.balanceAfterKobo, 4500000);
    });

    test('parses PalmPay payment notifications without success suffixes', () {
      const notification =
          'PalmPay: Payment of N3,450 to NETFLIX successful. Available balance N8,200';

      final draft = TransactionParser.parse(notification);

      expect(draft, isNotNull);
      expect(draft!.type, TransactionType.expense);
      expect(draft.amountKobo, 345000);
      expect(draft.merchantName, 'NETFLIX');
      expect(draft.source, TransactionSource.notification);
      expect(draft.balanceAfterKobo, 820000);
    });

    test('classifies FairMoney alerts as fintech notifications', () {
      const notification =
          'FairMoney: Loan repayment of N5,000 successful. Balance: N12,000';

      final draft = TransactionParser.parse(notification);

      expect(draft, isNotNull);
      expect(draft!.type, TransactionType.expense);
      expect(draft.amountKobo, 500000);
      expect(draft.source, TransactionSource.notification);
      expect(draft.balanceAfterKobo, 1200000);
    });

    test('parses First Bank purchase alerts', () {
      const sms =
          'FirstBank Alert: Account 1234567890 DR NGN12,750.00 POS/Web Purchase: BOLT TRIP. Avail Bal: NGN8,250.00';

      final draft = TransactionParser.parse(sms);

      expect(draft, isNotNull);
      expect(draft!.type, TransactionType.expense);
      expect(draft.amountKobo, 1275000);
      expect(draft.merchantName, 'BOLT TRIP');
      expect(draft.category, 'Transport');
      expect(draft.balanceAfterKobo, 825000);
    });

    test('parses UBA credit alerts', () {
      const sms =
          'UBA Alert: CR Amt NGN25,000.00 From Okoh Michael. Avail Bal NGN40,000.00';

      final draft = TransactionParser.parse(sms);

      expect(draft, isNotNull);
      expect(draft!.type, TransactionType.income);
      expect(draft.amountKobo, 2500000);
      expect(draft.merchantName, 'Okoh Michael');
      expect(draft.balanceAfterKobo, 4000000);
    });

    test('parses OPay transfer notifications', () {
      const notification =
          'OPay: Transfer of N2,000 to Ade Store successful. Balance: N5,500';

      final draft = TransactionParser.parse(notification);

      expect(draft, isNotNull);
      expect(draft!.type, TransactionType.expense);
      expect(draft.amountKobo, 200000);
      expect(draft.merchantName, 'Ade Store');
      expect(draft.source, TransactionSource.notification);
      expect(draft.balanceAfterKobo, 550000);
    });

    test('parses Moniepoint income sender without invoice note', () {
      const notification =
          'Moniepoint: You received NGN18,000 from Chika for invoice. Bal: NGN30,000';

      final draft = TransactionParser.parse(notification);

      expect(draft, isNotNull);
      expect(draft!.type, TransactionType.income);
      expect(draft.amountKobo, 1800000);
      expect(draft.merchantName, 'Chika');
      expect(draft.source, TransactionSource.notification);
      expect(draft.balanceAfterKobo, 3000000);
    });

    test('parses Carbon card payment notifications', () {
      const notification =
          'Carbon: Card payment of N4,200 at Shoprite was successful. Balance N10,500';

      final draft = TransactionParser.parse(notification);

      expect(draft, isNotNull);
      expect(draft!.type, TransactionType.expense);
      expect(draft.amountKobo, 420000);
      expect(draft.merchantName, 'Shoprite');
      expect(draft.source, TransactionSource.notification);
      expect(draft.balanceAfterKobo, 1050000);
    });
  });
}
