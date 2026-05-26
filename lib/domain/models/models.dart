import 'package:kolo/domain/services/ai_model_config.dart';

enum TransactionType { income, expense }

enum TransactionSource { sms, notification, manual, watchedApp }

enum AiRole { user, assistant, system }

enum OwingType { theyOweMe, iOweThem }

enum ShareStatus { pending, active, revoked }

enum WatchedAppBlockLevel { soft, explain, hardLock }

enum KoloPermission {
  sms,
  notifications,
  overlay,
  accessibility,
  backgroundService,
}

enum PermissionGrantState { granted, denied, notRequested }

enum SpendingDecisionStatus { approved, caution, advisedAgainst }

class SpendingJustificationDecision {
  const SpendingJustificationDecision({
    required this.status,
    required this.message,
    required this.aiNote,
  });

  factory SpendingJustificationDecision.fromJson(Map<String, Object?> json) {
    return SpendingJustificationDecision(
      status: _statusFromJson(json['status']),
      message: json['message'] as String? ?? '',
      aiNote: json['aiNote'] as String? ?? '',
    );
  }

  final SpendingDecisionStatus status;
  final String message;
  final String aiNote;

  bool get approved => status == SpendingDecisionStatus.approved;

  bool get requiresOverride => !approved;

  Map<String, Object?> toJson() {
    return {'status': status.name, 'message': message, 'aiNote': aiNote};
  }

  static SpendingDecisionStatus _statusFromJson(Object? value) {
    for (final status in SpendingDecisionStatus.values) {
      if (status.name == value) return status;
    }
    return SpendingDecisionStatus.caution;
  }
}

class PartnerInviteRef {
  const PartnerInviteRef({required this.ownerUid, required this.shareId});

  final String ownerUid;
  final String shareId;

  Uri get deepLink {
    return Uri(
      scheme: 'kolo',
      host: 'app',
      path: '/partner/invite',
      queryParameters: {'ownerUid': ownerUid, 'shareId': shareId},
    );
  }

  static PartnerInviteRef? fromUri(Uri uri) {
    final isDeepLink =
        uri.scheme == 'kolo' &&
        uri.host == 'app' &&
        uri.path == '/partner/invite';
    final isInAppRoute =
        uri.scheme.isEmpty && uri.host.isEmpty && uri.path == '/partner/invite';
    if (!isDeepLink && !isInAppRoute) {
      return null;
    }
    final ownerUid = uri.queryParameters['ownerUid'];
    final shareId = uri.queryParameters['shareId'];
    if (ownerUid == null ||
        ownerUid.isEmpty ||
        shareId == null ||
        shareId.isEmpty) {
      return null;
    }
    return PartnerInviteRef(ownerUid: ownerUid, shareId: shareId);
  }

  @override
  bool operator ==(Object other) {
    return other is PartnerInviteRef &&
        other.ownerUid == ownerUid &&
        other.shareId == shareId;
  }

  @override
  int get hashCode => Object.hash(ownerUid, shareId);
}

class InstalledAppCandidate {
  const InstalledAppCandidate({
    required this.packageName,
    required this.displayName,
    required this.installed,
    this.isKnownFinancialApp = false,
  });

  final String packageName;
  final String displayName;
  final bool installed;
  final bool isKnownFinancialApp;

  int get sortRank {
    if (isKnownFinancialApp && installed) return 0;
    if (isKnownFinancialApp) return 1;
    if (installed) return 2;
    return 3;
  }

  WatchedApp toWatchedApp({bool enabled = false}) {
    return WatchedApp(
      packageName: packageName,
      displayName: displayName,
      enabled: enabled,
    );
  }
}

class ReminderScheduleIntent {
  const ReminderScheduleIntent({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.payload,
  });

  factory ReminderScheduleIntent.bill({
    required String billId,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required int daysBeforeDue,
  }) {
    return ReminderScheduleIntent(
      id: 'bill-$billId-${daysBeforeDue}d',
      title: title,
      body: body,
      scheduledAt: scheduledAt,
      payload: {
        'kind': 'bill',
        'billId': billId,
        'daysBeforeDue': daysBeforeDue,
      },
    );
  }

  final String id;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final Map<String, Object?> payload;
}

class CachedDashboardMetadata {
  const CachedDashboardMetadata({
    required this.uid,
    required this.cachedAt,
    this.source = 'firestore',
  });

  final String uid;
  final DateTime cachedAt;
  final String source;
}

class CachedDashboardEntry {
  const CachedDashboardEntry({required this.dashboard, required this.metadata});

  final DashboardState dashboard;
  final CachedDashboardMetadata metadata;
}

class NotificationPreferences {
  const NotificationPreferences({
    this.transactionAlerts = true,
    this.budgetWarnings = true,
    this.billReminders = true,
    this.weeklyInsights = true,
    this.bubbleInterventions = true,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      transactionAlerts: _boolOrDefault(json['transactionAlerts']),
      budgetWarnings: _boolOrDefault(json['budgetWarnings']),
      billReminders: _boolOrDefault(json['billReminders']),
      weeklyInsights: _boolOrDefault(json['weeklyInsights']),
      bubbleInterventions: _boolOrDefault(json['bubbleInterventions']),
    );
  }

  final bool transactionAlerts;
  final bool budgetWarnings;
  final bool billReminders;
  final bool weeklyInsights;
  final bool bubbleInterventions;

  NotificationPreferences copyWith({
    bool? transactionAlerts,
    bool? budgetWarnings,
    bool? billReminders,
    bool? weeklyInsights,
    bool? bubbleInterventions,
  }) {
    return NotificationPreferences(
      transactionAlerts: transactionAlerts ?? this.transactionAlerts,
      budgetWarnings: budgetWarnings ?? this.budgetWarnings,
      billReminders: billReminders ?? this.billReminders,
      weeklyInsights: weeklyInsights ?? this.weeklyInsights,
      bubbleInterventions: bubbleInterventions ?? this.bubbleInterventions,
    );
  }

  Map<String, bool> toJson() {
    return {
      'transactionAlerts': transactionAlerts,
      'budgetWarnings': budgetWarnings,
      'billReminders': billReminders,
      'weeklyInsights': weeklyInsights,
      'bubbleInterventions': bubbleInterventions,
    };
  }

  static bool _boolOrDefault(Object? value) {
    if (value is bool) return value;
    return true;
  }
}

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.createdAt,
    this.onboardingComplete = false,
    this.avatarUrl,
    this.preferredAiModel = defaultGeminiModelName,
    this.notificationPreferences = const NotificationPreferences(),
  });

  final String uid;
  final String name;
  final String email;
  final DateTime createdAt;
  final bool onboardingComplete;
  final String? avatarUrl;
  final String preferredAiModel;
  final NotificationPreferences notificationPreferences;

  UserProfile copyWith({
    String? uid,
    String? name,
    String? email,
    DateTime? createdAt,
    bool? onboardingComplete,
    String? avatarUrl,
    String? preferredAiModel,
    NotificationPreferences? notificationPreferences,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      preferredAiModel: preferredAiModel ?? this.preferredAiModel,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
    );
  }
}

class OnboardingAnswers {
  const OnboardingAnswers({
    required this.incomeSource,
    required this.incomeFrequency,
    required this.currentBalanceKobo,
    required this.biggestProblem,
    this.savingsGoal,
  });

  final String incomeSource;
  final String incomeFrequency;
  final int currentBalanceKobo;
  final String biggestProblem;
  final String? savingsGoal;
}

class BalanceAdjustment {
  const BalanceAdjustment({
    required this.id,
    required this.previousBalanceKobo,
    required this.newBalanceKobo,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final int previousBalanceKobo;
  final int newBalanceKobo;
  final String note;
  final DateTime createdAt;

  int get deltaKobo => newBalanceKobo - previousBalanceKobo;
}

class BudgetPlan {
  const BudgetPlan({
    required this.monthlyIncomeKobo,
    required this.incomeType,
    required this.categories,
    required this.savingsTargetKobo,
    required this.savingsGoal,
    required this.aiNotes,
  });

  final int monthlyIncomeKobo;
  final String incomeType;
  final List<BudgetCategory> categories;
  final int savingsTargetKobo;
  final String savingsGoal;
  final String aiNotes;

  int get totalAllocatedKobo =>
      categories.fold(0, (total, category) => total + category.allocatedKobo);
}

class BudgetCategory {
  const BudgetCategory({
    required this.name,
    required this.emoji,
    required this.allocatedKobo,
    required this.priority,
  });

  final String name;
  final String emoji;
  final int allocatedKobo;
  final int priority;
}

class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.amountKobo,
    required this.type,
    required this.category,
    required this.description,
    required this.date,
    required this.source,
    this.merchantName,
    this.aiApproved,
    this.aiNote,
  });

  factory TransactionRecord.income({
    required String id,
    required int amountKobo,
    required String category,
    required String description,
    required DateTime date,
    required TransactionSource source,
    String? merchantName,
    String? aiNote,
  }) {
    return TransactionRecord(
      id: id,
      amountKobo: amountKobo,
      type: TransactionType.income,
      category: category,
      description: description,
      date: date,
      source: source,
      merchantName: merchantName,
      aiApproved: true,
      aiNote: aiNote,
    );
  }

  factory TransactionRecord.expense({
    required String id,
    required int amountKobo,
    required String category,
    required String description,
    required DateTime date,
    required TransactionSource source,
    String? merchantName,
    bool? aiApproved,
    String? aiNote,
  }) {
    return TransactionRecord(
      id: id,
      amountKobo: amountKobo,
      type: TransactionType.expense,
      category: category,
      description: description,
      date: date,
      source: source,
      merchantName: merchantName,
      aiApproved: aiApproved,
      aiNote: aiNote,
    );
  }

  final String id;
  final int amountKobo;
  final TransactionType type;
  final String category;
  final String description;
  final DateTime date;
  final TransactionSource source;
  final String? merchantName;
  final bool? aiApproved;
  final String? aiNote;

  int get signedKobo =>
      type == TransactionType.income ? amountKobo : -amountKobo;
}

class TransactionDraft {
  const TransactionDraft({
    required this.amountKobo,
    required this.type,
    required this.merchantName,
    required this.source,
    required this.rawText,
    this.balanceAfterKobo,
    this.category = 'Miscellaneous',
    this.occurredAt,
  });

  final int amountKobo;
  final TransactionType type;
  final String merchantName;
  final TransactionSource source;
  final String rawText;
  final int? balanceAfterKobo;
  final String category;
  final DateTime? occurredAt;
}

class AiMessage {
  const AiMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    required this.context,
  });

  final String id;
  final AiRole role;
  final String content;
  final DateTime timestamp;
  final String context;
}

class SavingsVault {
  const SavingsVault({
    required this.id,
    required this.name,
    required this.targetKobo,
    required this.currentKobo,
    this.deadline,
  });

  final String id;
  final String name;
  final int targetKobo;
  final int currentKobo;
  final DateTime? deadline;

  double get progress =>
      targetKobo <= 0 ? 0 : (currentKobo / targetKobo).clamp(0, 1).toDouble();
}

class Owing {
  const Owing({
    required this.id,
    required this.type,
    required this.person,
    required this.amountKobo,
    required this.date,
    this.settled = false,
    this.note,
    this.dueDate,
  });

  final String id;
  final OwingType type;
  final String person;
  final int amountKobo;
  final DateTime date;
  final bool settled;
  final String? note;
  final DateTime? dueDate;
}

class GigRecord {
  const GigRecord({
    required this.id,
    required this.client,
    required this.amountKobo,
    required this.date,
    required this.projectType,
    this.note,
  });

  final String id;
  final String client;
  final int amountKobo;
  final DateTime date;
  final String projectType;
  final String? note;
}

class BillReminder {
  const BillReminder({
    required this.id,
    required this.name,
    required this.amountKobo,
    required this.frequency,
    required this.nextDue,
    this.active = true,
  });

  final String id;
  final String name;
  final int amountKobo;
  final String frequency;
  final DateTime nextDue;
  final bool active;
}

class WatchedApp {
  const WatchedApp({
    required this.packageName,
    required this.displayName,
    this.enabled = false,
    this.blockLevel = WatchedAppBlockLevel.soft,
  });

  final String packageName;
  final String displayName;
  final bool enabled;
  final WatchedAppBlockLevel blockLevel;
}

class NativeAndroidEvent {
  const NativeAndroidEvent({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.payload,
  });

  final String id;
  final String type;
  final DateTime createdAt;
  final Map<String, Object?> payload;
}

class PartnerShare {
  const PartnerShare({
    required this.id,
    required this.partnerEmail,
    required this.status,
    required this.permissions,
    required this.createdAt,
    this.revokedAt,
  });

  final String id;
  final String partnerEmail;
  final ShareStatus status;
  final Set<String> permissions;
  final DateTime createdAt;
  final DateTime? revokedAt;
}

class WeeklyInsight {
  const WeeklyInsight({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
}

class FinancialSummary {
  const FinancialSummary({
    required this.balanceKobo,
    required this.totalIncomeKobo,
    required this.totalExpenseKobo,
    required this.totalSavingsKobo,
    required this.categorySpendKobo,
    required this.categoryBudgetKobo,
    required this.totalBudgetKobo,
  });

  final int balanceKobo;
  final int totalIncomeKobo;
  final int totalExpenseKobo;
  final int totalSavingsKobo;
  final int totalBudgetKobo;
  final Map<String, int> categorySpendKobo;
  final Map<String, int> categoryBudgetKobo;

  double categoryProgress(String category) {
    final spent = categorySpendKobo[category] ?? 0;
    final budget = categoryBudgetKobo[category] ?? 0;
    if (budget <= 0) return 0;
    return spent / budget;
  }
}

class DashboardState {
  const DashboardState({
    required this.profile,
    required this.balanceKobo,
    required this.balanceAdjustments,
    required this.budgetPlan,
    required this.transactions,
    required this.aiMessages,
    required this.vaults,
    required this.owings,
    required this.gigs,
    required this.bills,
    required this.watchedApps,
    required this.partnerShares,
    required this.insights,
    required this.permissions,
  });

  final UserProfile profile;
  final int balanceKobo;
  final List<BalanceAdjustment> balanceAdjustments;
  final BudgetPlan budgetPlan;
  final List<TransactionRecord> transactions;
  final List<AiMessage> aiMessages;
  final List<SavingsVault> vaults;
  final List<Owing> owings;
  final List<GigRecord> gigs;
  final List<BillReminder> bills;
  final List<WatchedApp> watchedApps;
  final List<PartnerShare> partnerShares;
  final List<WeeklyInsight> insights;
  final Map<KoloPermission, PermissionGrantState> permissions;

  DashboardState copyWith({
    UserProfile? profile,
    int? balanceKobo,
    List<BalanceAdjustment>? balanceAdjustments,
    BudgetPlan? budgetPlan,
    List<TransactionRecord>? transactions,
    List<AiMessage>? aiMessages,
    List<SavingsVault>? vaults,
    List<Owing>? owings,
    List<GigRecord>? gigs,
    List<BillReminder>? bills,
    List<WatchedApp>? watchedApps,
    List<PartnerShare>? partnerShares,
    List<WeeklyInsight>? insights,
    Map<KoloPermission, PermissionGrantState>? permissions,
  }) {
    return DashboardState(
      profile: profile ?? this.profile,
      balanceKobo: balanceKobo ?? this.balanceKobo,
      balanceAdjustments: balanceAdjustments ?? this.balanceAdjustments,
      budgetPlan: budgetPlan ?? this.budgetPlan,
      transactions: transactions ?? this.transactions,
      aiMessages: aiMessages ?? this.aiMessages,
      vaults: vaults ?? this.vaults,
      owings: owings ?? this.owings,
      gigs: gigs ?? this.gigs,
      bills: bills ?? this.bills,
      watchedApps: watchedApps ?? this.watchedApps,
      partnerShares: partnerShares ?? this.partnerShares,
      insights: insights ?? this.insights,
      permissions: permissions ?? this.permissions,
    );
  }
}
