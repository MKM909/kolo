import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/financial_calculator.dart';

class AiContextBuilder {
  AiContextBuilder._();

  static Map<String, Object?> build(DashboardState state, {DateTime? now}) {
    final anchor = now ?? DateTime.now();
    final periodTransactions = state.transactions
        .where((transaction) => _isSameMonth(transaction.date, anchor))
        .toList(growable: false);
    final summary = FinancialCalculator.summarize(
      balanceKobo: state.balanceKobo,
      budget: state.budgetPlan,
      transactions: periodTransactions,
      vaults: state.vaults,
    );
    final vaultProtectionKobo = state.vaults.fold(
      0,
      (total, vault) => total + vault.currentKobo,
    );

    return {
      'balanceKobo': state.balanceKobo,
      'spendableBalanceKobo': state.balanceKobo - vaultProtectionKobo,
      'vaultProtectionKobo': vaultProtectionKobo,
      'daysSinceLastIncome': _daysSinceLastIncome(state.transactions, anchor),
      'periodTotals': {
        'incomeKobo': summary.totalIncomeKobo,
        'expenseKobo': summary.totalExpenseKobo,
        'savingsKobo': summary.totalSavingsKobo,
      },
      'budgetCategories': [
        for (final category in state.budgetPlan.categories)
          _budgetCategoryPayload(category, summary),
      ],
      'recentTransactions': [
        for (final tx in state.transactions.take(20)) _transactionPayload(tx),
      ],
      'vaults': [for (final vault in state.vaults) _vaultPayload(vault)],
      'owings': [
        for (final owing in state.owings)
          {
            'person': owing.person,
            'amountKobo': owing.amountKobo,
            'type': owing.type.name,
            'settled': owing.settled,
            'dueDate': owing.dueDate?.toIso8601String(),
          },
      ],
      'bills': [for (final bill in state.bills) _billPayload(bill, anchor)],
      'dueBills': [
        for (final bill in state.bills)
          if (bill.active && _daysUntil(bill.nextDue, anchor) <= 3)
            _billPayload(bill, anchor),
      ],
      'gigSummary': _gigSummary(state.gigs, anchor),
      'spendingPatterns': _spendingPatterns(periodTransactions),
    };
  }

  static Map<String, Object?> _budgetCategoryPayload(
    BudgetCategory category,
    FinancialSummary summary,
  ) {
    final spentKobo = summary.categorySpendKobo[category.name] ?? 0;
    return {
      'name': category.name,
      'allocatedKobo': category.allocatedKobo,
      'spentKobo': spentKobo,
      'remainingKobo': category.allocatedKobo - spentKobo,
      'progress': summary.categoryProgress(category.name),
    };
  }

  static Map<String, Object?> _transactionPayload(TransactionRecord tx) {
    return {
      'amountKobo': tx.amountKobo,
      'type': tx.type.name,
      'category': tx.category,
      'description': tx.description,
      'date': tx.date.toIso8601String(),
      'source': tx.source.name,
      'merchantName': tx.merchantName,
    };
  }

  static Map<String, Object?> _vaultPayload(SavingsVault vault) {
    return {
      'name': vault.name,
      'targetKobo': vault.targetKobo,
      'currentKobo': vault.currentKobo,
      'deadline': vault.deadline?.toIso8601String(),
    };
  }

  static Map<String, Object?> _billPayload(BillReminder bill, DateTime now) {
    return {
      'name': bill.name,
      'amountKobo': bill.amountKobo,
      'frequency': bill.frequency,
      'nextDue': bill.nextDue.toIso8601String(),
      'active': bill.active,
      'daysUntilDue': _daysUntil(bill.nextDue, now),
    };
  }

  static Map<String, Object?> _gigSummary(List<GigRecord> gigs, DateTime now) {
    final monthly = gigs.where((gig) => _isSameMonth(gig.date, now));
    final yearly = gigs.where((gig) => gig.date.year == now.year);
    final lastGig = _latestDate(gigs.map((gig) => gig.date));

    return {
      'totalThisMonthKobo': monthly.fold<int>(
        0,
        (total, gig) => total + gig.amountKobo,
      ),
      'totalThisYearKobo': yearly.fold<int>(
        0,
        (total, gig) => total + gig.amountKobo,
      ),
      'daysSinceLastGig': lastGig == null ? null : _daysBetween(lastGig, now),
    };
  }

  static Map<String, Object?> _spendingPatterns(
    List<TransactionRecord> transactions,
  ) {
    final byWeekday = <String, _SpendingPatternBucket>{};
    final byTimeOfDay = <String, _SpendingPatternBucket>{};
    final byCategoryTimeOfDay = <String, _CategoryTimePatternBucket>{};

    for (final transaction in transactions) {
      if (transaction.type != TransactionType.expense) continue;

      final weekday = _weekdayName(transaction.date.weekday);
      final timeWindow = _timeWindow(transaction.date.hour);
      _addPatternBucket(byWeekday, weekday, transaction.amountKobo);
      _addPatternBucket(byTimeOfDay, timeWindow, transaction.amountKobo);

      final categoryTimeKey = '${transaction.category}::$timeWindow';
      final categoryTimeBucket = byCategoryTimeOfDay.putIfAbsent(
        categoryTimeKey,
        () => _CategoryTimePatternBucket(
          category: transaction.category,
          window: timeWindow,
        ),
      );
      categoryTimeBucket.add(transaction.amountKobo);
    }

    return {
      'byWeekday': _patternBucketPayloads(byWeekday, 'weekday'),
      'byTimeOfDay': _patternBucketPayloads(byTimeOfDay, 'window'),
      'byCategoryTimeOfDay': _categoryTimePatternPayloads(
        byCategoryTimeOfDay,
      ),
    };
  }

  static void _addPatternBucket(
    Map<String, _SpendingPatternBucket> buckets,
    String label,
    int amountKobo,
  ) {
    final bucket = buckets.putIfAbsent(
      label,
      () => _SpendingPatternBucket(label),
    );
    bucket.add(amountKobo);
  }

  static List<Map<String, Object?>> _patternBucketPayloads(
    Map<String, _SpendingPatternBucket> buckets,
    String labelKey,
  ) {
    final sortedBuckets = buckets.values.toList()
      ..sort(_compareSpendingPatternBuckets);

    return [
      for (final bucket in sortedBuckets)
        {
          labelKey: bucket.label,
          'expenseKobo': bucket.expenseKobo,
          'transactionCount': bucket.transactionCount,
        },
    ];
  }

  static List<Map<String, Object?>> _categoryTimePatternPayloads(
    Map<String, _CategoryTimePatternBucket> buckets,
  ) {
    final sortedBuckets = buckets.values.toList()
      ..sort(_compareCategoryTimePatternBuckets);

    return [
      for (final bucket in sortedBuckets)
        {
          'category': bucket.category,
          'window': bucket.window,
          'expenseKobo': bucket.expenseKobo,
          'transactionCount': bucket.transactionCount,
        },
    ];
  }

  static int _compareSpendingPatternBuckets(
    _SpendingPatternBucket a,
    _SpendingPatternBucket b,
  ) {
    final amountComparison = b.expenseKobo.compareTo(a.expenseKobo);
    if (amountComparison != 0) return amountComparison;
    return a.label.compareTo(b.label);
  }

  static int _compareCategoryTimePatternBuckets(
    _CategoryTimePatternBucket a,
    _CategoryTimePatternBucket b,
  ) {
    final amountComparison = b.expenseKobo.compareTo(a.expenseKobo);
    if (amountComparison != 0) return amountComparison;
    final categoryComparison = a.category.compareTo(b.category);
    if (categoryComparison != 0) return categoryComparison;
    return a.window.compareTo(b.window);
  }

  static String _weekdayName(int weekday) {
    return switch (weekday) {
      DateTime.monday => 'Monday',
      DateTime.tuesday => 'Tuesday',
      DateTime.wednesday => 'Wednesday',
      DateTime.thursday => 'Thursday',
      DateTime.friday => 'Friday',
      DateTime.saturday => 'Saturday',
      DateTime.sunday => 'Sunday',
      _ => 'Unknown',
    };
  }

  static String _timeWindow(int hour) {
    if (hour < 5 || hour >= 21) return 'lateNight';
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  static int? _daysSinceLastIncome(
    List<TransactionRecord> transactions,
    DateTime now,
  ) {
    final lastIncome = _latestDate(
      transactions
          .where((transaction) => transaction.type == TransactionType.income)
          .map((transaction) => transaction.date),
    );
    return lastIncome == null ? null : _daysBetween(lastIncome, now);
  }

  static DateTime? _latestDate(Iterable<DateTime> dates) {
    DateTime? latest;
    for (final date in dates) {
      if (latest == null || date.isAfter(latest)) latest = date;
    }
    return latest;
  }

  static bool _isSameMonth(DateTime value, DateTime now) {
    return value.year == now.year && value.month == now.month;
  }

  static int _daysUntil(DateTime value, DateTime now) {
    return _dateOnly(value).difference(_dateOnly(now)).inDays;
  }

  static int _daysBetween(DateTime value, DateTime now) {
    return _dateOnly(now).difference(_dateOnly(value)).inDays;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}

class _SpendingPatternBucket {
  _SpendingPatternBucket(this.label);

  final String label;
  int expenseKobo = 0;
  int transactionCount = 0;

  void add(int amountKobo) {
    expenseKobo += amountKobo;
    transactionCount += 1;
  }
}

class _CategoryTimePatternBucket {
  _CategoryTimePatternBucket({required this.category, required this.window});

  final String category;
  final String window;
  int expenseKobo = 0;
  int transactionCount = 0;

  void add(int amountKobo) {
    expenseKobo += amountKobo;
    transactionCount += 1;
  }
}
