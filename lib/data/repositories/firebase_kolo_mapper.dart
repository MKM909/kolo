import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/ai_model_config.dart';

class FirebaseKoloMapper {
  FirebaseKoloMapper._();

  static DashboardState dashboardFromPayload({
    required String uid,
    required Map<String, dynamic> user,
    required List<Map<String, dynamic>> balanceAdjustments,
    required List<Map<String, dynamic>> transactions,
    required List<Map<String, dynamic>> aiMessages,
    required List<Map<String, dynamic>> vaults,
    required List<Map<String, dynamic>> owings,
    required List<Map<String, dynamic>> gigs,
    required List<Map<String, dynamic>> bills,
    required List<Map<String, dynamic>> watchedApps,
    required List<Map<String, dynamic>> partnerShares,
    required List<Map<String, dynamic>> insights,
    required DateTime now,
  }) {
    return DashboardState(
      profile: _profile(uid, user, now),
      balanceKobo: _int(user['balanceKobo']),
      balanceAdjustments: balanceAdjustments.map(_balanceAdjustment).toList(),
      budgetPlan: _budget(user['budgetPlan']),
      transactions: transactions.map(_transaction).toList(),
      aiMessages: aiMessages.map(_aiMessage).toList(),
      vaults: vaults.map(_vault).toList(),
      owings: owings.map(_owing).toList(),
      gigs: gigs.map(_gig).toList(),
      bills: bills.map(_bill).toList(),
      watchedApps: watchedApps.map(_watchedApp).toList(),
      partnerShares: partnerShares.map(_partnerShare).toList(),
      insights: insights.map(_insight).toList(),
      permissions: _permissions(user['permissions']),
    );
  }

  static Map<String, Object?> transactionToJson(TransactionRecord transaction) {
    return {
      'amountKobo': transaction.amountKobo,
      'type': transaction.type.name,
      'category': transaction.category,
      'description': transaction.description,
      'date': Timestamp.fromDate(transaction.date),
      'source': transaction.source.name,
      'merchantName': transaction.merchantName,
      'aiApproved': transaction.aiApproved,
      'aiNote': transaction.aiNote,
    };
  }

  static Map<String, Object?> balanceAdjustmentToJson(
    BalanceAdjustment adjustment,
  ) {
    return {
      'previousBalanceKobo': adjustment.previousBalanceKobo,
      'newBalanceKobo': adjustment.newBalanceKobo,
      'note': adjustment.note,
      'createdAt': Timestamp.fromDate(adjustment.createdAt),
    };
  }

  static Map<String, Object?> vaultToJson(SavingsVault vault) {
    return {
      'name': vault.name,
      'targetKobo': vault.targetKobo,
      'currentKobo': vault.currentKobo,
      'deadline': vault.deadline == null
          ? null
          : Timestamp.fromDate(vault.deadline!),
    };
  }

  static Map<String, Object?> owingToJson(Owing owing) {
    return {
      'type': owing.type.name,
      'person': owing.person,
      'amountKobo': owing.amountKobo,
      'date': Timestamp.fromDate(owing.date),
      'settled': owing.settled,
      'note': owing.note,
      'dueDate': owing.dueDate == null
          ? null
          : Timestamp.fromDate(owing.dueDate!),
    };
  }

  static Map<String, Object?> gigToJson(GigRecord gig) {
    return {
      'client': gig.client,
      'amountKobo': gig.amountKobo,
      'date': Timestamp.fromDate(gig.date),
      'projectType': gig.projectType,
      'note': gig.note,
    };
  }

  static Map<String, Object?> billToJson(BillReminder bill) {
    return {
      'name': bill.name,
      'amountKobo': bill.amountKobo,
      'frequency': bill.frequency,
      'nextDue': Timestamp.fromDate(bill.nextDue),
      'active': bill.active,
    };
  }

  static Map<String, Object?> partnerShareToJson(PartnerShare share) {
    return {
      'partnerEmail': share.partnerEmail,
      'status': share.status.name,
      'permissions': share.permissions.toList()..sort(),
      'createdAt': Timestamp.fromDate(share.createdAt),
      'revokedAt': share.revokedAt == null
          ? null
          : Timestamp.fromDate(share.revokedAt!),
    };
  }

  static Map<String, Object?> watchedAppToJson(WatchedApp app) {
    return {
      'packageName': app.packageName,
      'displayName': app.displayName,
      'enabled': app.enabled,
      'blockLevel': app.blockLevel.name,
    };
  }

  static Map<String, Object?> aiMessageToJson(AiMessage message) {
    return {
      'role': message.role.name,
      'content': message.content,
      'timestamp': Timestamp.fromDate(message.timestamp),
      'context': message.context,
    };
  }

  static Map<String, Object?> insightToJson(WeeklyInsight insight) {
    return {
      'title': insight.title,
      'body': insight.body,
      'createdAt': Timestamp.fromDate(insight.createdAt),
    };
  }

  static Map<String, Object?> budgetToJson(BudgetPlan budget) {
    return {
      'monthlyIncomeKobo': budget.monthlyIncomeKobo,
      'incomeType': budget.incomeType,
      'savingsTargetKobo': budget.savingsTargetKobo,
      'savingsGoal': budget.savingsGoal,
      'aiNotes': budget.aiNotes,
      'categories': [
        for (final category in budget.categories)
          {
            'name': category.name,
            'emoji': category.emoji,
            'allocatedKobo': category.allocatedKobo,
            'priority': category.priority,
          },
      ],
    };
  }

  static UserProfile _profile(
    String uid,
    Map<String, dynamic> user,
    DateTime now,
  ) {
    return UserProfile(
      uid: uid,
      name: _string(user['name'], fallback: 'Kolo User'),
      email: _string(user['email']),
      createdAt: _date(user['createdAt'], fallback: now),
      onboardingComplete: _bool(user['onboardingComplete']),
      avatarUrl: user['avatarUrl'] as String?,
      preferredAiModel: koloAiModelNameOrDefault(
        user['preferredAiModel'] as String?,
      ),
      notificationPreferences: NotificationPreferences.fromJson(
        _map(user['notificationPreferences']),
      ),
    );
  }

  static BudgetPlan _budget(Object? value) {
    final map = _map(value);
    final rawCategories = map['categories'];
    final categories = rawCategories is List
        ? rawCategories
              .whereType<Map<Object?, Object?>>()
              .map((item) => _budgetCategory(Map<String, dynamic>.from(item)))
              .toList()
        : <BudgetCategory>[];

    return BudgetPlan(
      monthlyIncomeKobo: _int(map['monthlyIncomeKobo']),
      incomeType: _string(map['incomeType'], fallback: 'irregular'),
      categories: categories.isEmpty ? _defaultBudgetCategories : categories,
      savingsTargetKobo: _int(map['savingsTargetKobo']),
      savingsGoal: _string(map['savingsGoal'], fallback: 'Emergency buffer'),
      aiNotes: _string(
        map['aiNotes'],
        fallback: 'Kolo will shape this budget as you add real spending.',
      ),
    );
  }

  static BudgetCategory _budgetCategory(Map<String, dynamic> map) {
    return BudgetCategory(
      name: _string(map['name'], fallback: 'Miscellaneous'),
      emoji: _string(map['emoji'], fallback: '*'),
      allocatedKobo: _int(map['allocatedKobo']),
      priority: _int(map['priority'], fallback: 9),
    );
  }

  static TransactionRecord _transaction(Map<String, dynamic> map) {
    return TransactionRecord(
      id: _string(map['id'], fallback: 'transaction'),
      amountKobo: _int(map['amountKobo']),
      type: _enumByName(
        TransactionType.values,
        map['type'],
        TransactionType.expense,
      ),
      category: _string(map['category'], fallback: 'Miscellaneous'),
      description: _string(map['description'], fallback: 'Transaction'),
      date: _date(map['date']),
      source: _enumByName(
        TransactionSource.values,
        map['source'],
        TransactionSource.manual,
      ),
      merchantName: map['merchantName'] as String?,
      aiApproved: map['aiApproved'] as bool?,
      aiNote: map['aiNote'] as String?,
    );
  }

  static BalanceAdjustment _balanceAdjustment(Map<String, dynamic> map) {
    return BalanceAdjustment(
      id: _string(map['id'], fallback: 'adjustment'),
      previousBalanceKobo: _int(map['previousBalanceKobo']),
      newBalanceKobo: _int(map['newBalanceKobo']),
      note: _string(map['note'], fallback: 'Balance correction'),
      createdAt: _date(map['createdAt']),
    );
  }

  static AiMessage _aiMessage(Map<String, dynamic> map) {
    return AiMessage(
      id: _string(map['id'], fallback: 'message'),
      role: _enumByName(AiRole.values, map['role'], AiRole.assistant),
      content: _string(map['content']),
      timestamp: _date(map['timestamp']),
      context: _string(map['context'], fallback: 'chat'),
    );
  }

  static SavingsVault _vault(Map<String, dynamic> map) {
    return SavingsVault(
      id: _string(map['id'], fallback: 'vault'),
      name: _string(map['name'], fallback: 'Savings'),
      targetKobo: _int(map['targetKobo']),
      currentKobo: _int(map['currentKobo']),
      deadline: map.containsKey('deadline') ? _date(map['deadline']) : null,
    );
  }

  static Owing _owing(Map<String, dynamic> map) {
    return Owing(
      id: _string(map['id'], fallback: 'owing'),
      type: _enumByName(OwingType.values, map['type'], OwingType.theyOweMe),
      person: _string(map['person'], fallback: 'Someone'),
      amountKobo: _int(map['amountKobo']),
      date: _date(map['date']),
      settled: _bool(map['settled']),
      note: map['note'] as String?,
      dueDate: map.containsKey('dueDate') ? _date(map['dueDate']) : null,
    );
  }

  static GigRecord _gig(Map<String, dynamic> map) {
    return GigRecord(
      id: _string(map['id'], fallback: 'gig'),
      client: _string(map['client'], fallback: 'Client'),
      amountKobo: _int(map['amountKobo']),
      date: _date(map['date']),
      projectType: _string(map['projectType'], fallback: 'Gig'),
      note: map['note'] as String?,
    );
  }

  static BillReminder _bill(Map<String, dynamic> map) {
    return BillReminder(
      id: _string(map['id'], fallback: 'bill'),
      name: _string(map['name'], fallback: 'Bill'),
      amountKobo: _int(map['amountKobo']),
      frequency: _string(map['frequency'], fallback: 'Monthly'),
      nextDue: _date(map['nextDue']),
      active: _bool(map['active'], fallback: true),
    );
  }

  static WatchedApp _watchedApp(Map<String, dynamic> map) {
    return WatchedApp(
      packageName: _string(map['packageName']),
      displayName: _string(map['displayName'], fallback: 'App'),
      enabled: _bool(map['enabled']),
      blockLevel: _enumByName(
        WatchedAppBlockLevel.values,
        map['blockLevel'],
        WatchedAppBlockLevel.soft,
      ),
    );
  }

  static PartnerShare _partnerShare(Map<String, dynamic> map) {
    final rawPermissions = map['permissions'];
    return PartnerShare(
      id: _string(map['id'], fallback: 'share'),
      partnerEmail: _string(map['partnerEmail']),
      status: _enumByName(
        ShareStatus.values,
        map['status'],
        ShareStatus.pending,
      ),
      permissions: rawPermissions is Iterable
          ? rawPermissions.map((item) => item.toString()).toSet()
          : const {},
      createdAt: _date(map['createdAt']),
      revokedAt: map.containsKey('revokedAt') ? _date(map['revokedAt']) : null,
    );
  }

  static WeeklyInsight _insight(Map<String, dynamic> map) {
    return WeeklyInsight(
      id: _string(map['id'], fallback: 'insight'),
      title: _string(map['title'], fallback: 'Kolo insight'),
      body: _string(map['body']),
      createdAt: _date(map['createdAt']),
    );
  }

  static Map<KoloPermission, PermissionGrantState> _permissions(Object? value) {
    final map = _map(value);
    return {
      for (final permission in KoloPermission.values)
        permission: _enumByName(
          PermissionGrantState.values,
          map[permission.name],
          PermissionGrantState.notRequested,
        ),
    };
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map<Object?, Object?>) return Map<String, dynamic>.from(value);
    return const {};
  }

  static String _string(Object? value, {String fallback = ''}) {
    if (value is String && value.isNotEmpty) return value;
    return fallback;
  }

  static int _int(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return fallback;
  }

  static bool _bool(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    return fallback;
  }

  static DateTime _date(Object? value, {DateTime? fallback}) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      return DateTime.tryParse(value) ?? fallback ?? DateTime(1970);
    }
    return fallback ?? DateTime(1970);
  }

  static T _enumByName<T extends Enum>(
    Iterable<T> values,
    Object? value,
    T fallback,
  ) {
    if (value is String) {
      for (final item in values) {
        if (item.name == value) return item;
      }
    }
    return fallback;
  }

  static const _defaultBudgetCategories = [
    BudgetCategory(
      name: 'Food & Snacks',
      emoji: 'food',
      allocatedKobo: 0,
      priority: 1,
    ),
    BudgetCategory(
      name: 'Transport',
      emoji: 'bus',
      allocatedKobo: 0,
      priority: 2,
    ),
    BudgetCategory(
      name: 'Data & Airtime',
      emoji: 'data',
      allocatedKobo: 0,
      priority: 3,
    ),
  ];
}
