import 'package:hive/hive.dart';
import 'package:kolo/data/repositories/firebase_kolo_mapper.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/dashboard_cache_store.dart';

const koloDashboardCacheBoxName = 'kolo_dashboard_cache';

class MemoryDashboardCacheStore implements DashboardCacheStore {
  final Map<String, CachedDashboardEntry> _entries = {};

  @override
  Future<CachedDashboardEntry?> load(String uid) async => _entries[uid];

  @override
  Future<void> save({
    required String uid,
    required DashboardState dashboard,
    required CachedDashboardMetadata metadata,
  }) async {
    _entries[uid] = CachedDashboardEntry(
      dashboard: dashboard,
      metadata: metadata,
    );
  }

  @override
  Future<void> clear(String uid) async {
    _entries.remove(uid);
  }
}

class HiveDashboardCacheStore implements DashboardCacheStore {
  HiveDashboardCacheStore(this._box);

  final Box<Object?> _box;

  @override
  Future<CachedDashboardEntry?> load(String uid) async {
    final rawEntry = _box.get(_key(uid));
    if (rawEntry is! Map) return null;
    final entry = Map<String, Object?>.from(rawEntry);
    final metadata = _metadataFromJson(entry['metadata']);
    final payload = _payload(entry['dashboard']);
    if (metadata == null || payload == null) return null;

    return CachedDashboardEntry(
      dashboard: FirebaseKoloMapper.dashboardFromPayload(
        uid: uid,
        user: _map(payload['user']),
        balanceAdjustments: _listOfMaps(payload['balanceAdjustments']),
        transactions: _listOfMaps(payload['transactions']),
        aiMessages: _listOfMaps(payload['aiMessages']),
        vaults: _listOfMaps(payload['vaults']),
        owings: _listOfMaps(payload['owings']),
        gigs: _listOfMaps(payload['gigs']),
        bills: _listOfMaps(payload['bills']),
        watchedApps: _listOfMaps(payload['watchedApps']),
        partnerShares: _listOfMaps(payload['partnerShares']),
        insights: _listOfMaps(payload['insights']),
        now: DateTime.now(),
      ),
      metadata: metadata,
    );
  }

  @override
  Future<void> save({
    required String uid,
    required DashboardState dashboard,
    required CachedDashboardMetadata metadata,
  }) {
    return _box.put(_key(uid), {
      'metadata': _metadataToJson(metadata),
      'dashboard': _dashboardToJson(dashboard),
    });
  }

  @override
  Future<void> clear(String uid) {
    return _box.delete(_key(uid));
  }

  String _key(String uid) => 'dashboard_$uid';

  Map<String, Object?> _metadataToJson(CachedDashboardMetadata metadata) {
    return {
      'uid': metadata.uid,
      'cachedAt': metadata.cachedAt.toIso8601String(),
      'source': metadata.source,
    };
  }

  CachedDashboardMetadata? _metadataFromJson(Object? value) {
    final map = _map(value);
    final uid = map['uid'] as String?;
    final cachedAt = DateTime.tryParse(map['cachedAt'] as String? ?? '');
    if (uid == null || cachedAt == null) return null;
    return CachedDashboardMetadata(
      uid: uid,
      cachedAt: cachedAt,
      source: map['source'] as String? ?? 'firestore',
    );
  }

  Map<String, Object?> _dashboardToJson(DashboardState dashboard) {
    return {
      'user': {
        'name': dashboard.profile.name,
        'email': dashboard.profile.email,
        'createdAt': _date(dashboard.profile.createdAt),
        'onboardingComplete': dashboard.profile.onboardingComplete,
        'avatarUrl': dashboard.profile.avatarUrl,
        'preferredAiModel': dashboard.profile.preferredAiModel,
        'notificationPreferences': dashboard.profile.notificationPreferences
            .toJson(),
        'balanceKobo': dashboard.balanceKobo,
        'budgetPlan': _budgetToJson(dashboard.budgetPlan),
        'permissions': {
          for (final entry in dashboard.permissions.entries)
            entry.key.name: entry.value.name,
        },
      },
      'balanceAdjustments': [
        for (final adjustment in dashboard.balanceAdjustments)
          _balanceAdjustmentToJson(adjustment),
      ],
      'transactions': [
        for (final transaction in dashboard.transactions)
          _transactionToJson(transaction),
      ],
      'aiMessages': [
        for (final message in dashboard.aiMessages) _aiMessageToJson(message),
      ],
      'vaults': [for (final vault in dashboard.vaults) _vaultToJson(vault)],
      'owings': [for (final owing in dashboard.owings) _owingToJson(owing)],
      'gigs': [for (final gig in dashboard.gigs) _gigToJson(gig)],
      'bills': [for (final bill in dashboard.bills) _billToJson(bill)],
      'watchedApps': [
        for (final app in dashboard.watchedApps) _watchedAppToJson(app),
      ],
      'partnerShares': [
        for (final share in dashboard.partnerShares) _partnerShareToJson(share),
      ],
      'insights': [
        for (final insight in dashboard.insights) _insightToJson(insight),
      ],
    };
  }

  Map<String, Object?> _budgetToJson(BudgetPlan budget) {
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

  Map<String, Object?> _balanceAdjustmentToJson(BalanceAdjustment adjustment) {
    return {
      'id': adjustment.id,
      'previousBalanceKobo': adjustment.previousBalanceKobo,
      'newBalanceKobo': adjustment.newBalanceKobo,
      'note': adjustment.note,
      'createdAt': _date(adjustment.createdAt),
    };
  }

  Map<String, Object?> _transactionToJson(TransactionRecord transaction) {
    return {
      'id': transaction.id,
      'amountKobo': transaction.amountKobo,
      'type': transaction.type.name,
      'category': transaction.category,
      'description': transaction.description,
      'date': _date(transaction.date),
      'source': transaction.source.name,
      'merchantName': transaction.merchantName,
      'aiApproved': transaction.aiApproved,
      'aiNote': transaction.aiNote,
    };
  }

  Map<String, Object?> _aiMessageToJson(AiMessage message) {
    return {
      'id': message.id,
      'role': message.role.name,
      'content': message.content,
      'timestamp': _date(message.timestamp),
      'context': message.context,
    };
  }

  Map<String, Object?> _vaultToJson(SavingsVault vault) {
    return {
      'id': vault.id,
      'name': vault.name,
      'targetKobo': vault.targetKobo,
      'currentKobo': vault.currentKobo,
      'deadline': vault.deadline == null ? null : _date(vault.deadline!),
    };
  }

  Map<String, Object?> _owingToJson(Owing owing) {
    return {
      'id': owing.id,
      'type': owing.type.name,
      'person': owing.person,
      'amountKobo': owing.amountKobo,
      'date': _date(owing.date),
      'settled': owing.settled,
      'note': owing.note,
      'dueDate': owing.dueDate == null ? null : _date(owing.dueDate!),
    };
  }

  Map<String, Object?> _gigToJson(GigRecord gig) {
    return {
      'id': gig.id,
      'client': gig.client,
      'amountKobo': gig.amountKobo,
      'date': _date(gig.date),
      'projectType': gig.projectType,
      'note': gig.note,
    };
  }

  Map<String, Object?> _billToJson(BillReminder bill) {
    return {
      'id': bill.id,
      'name': bill.name,
      'amountKobo': bill.amountKobo,
      'frequency': bill.frequency,
      'nextDue': _date(bill.nextDue),
      'active': bill.active,
    };
  }

  Map<String, Object?> _watchedAppToJson(WatchedApp app) {
    return {
      'id': app.packageName,
      'packageName': app.packageName,
      'displayName': app.displayName,
      'enabled': app.enabled,
    };
  }

  Map<String, Object?> _partnerShareToJson(PartnerShare share) {
    return {
      'id': share.id,
      'partnerEmail': share.partnerEmail,
      'status': share.status.name,
      'permissions': share.permissions.toList()..sort(),
      'createdAt': _date(share.createdAt),
      'revokedAt': share.revokedAt == null ? null : _date(share.revokedAt!),
    };
  }

  Map<String, Object?> _insightToJson(WeeklyInsight insight) {
    return {
      'id': insight.id,
      'title': insight.title,
      'body': insight.body,
      'createdAt': _date(insight.createdAt),
    };
  }

  String _date(DateTime date) => date.toIso8601String();

  Map<String, Object?>? _payload(Object? value) {
    final map = _map(value);
    return map.isEmpty ? null : map;
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return {
        for (final entry in value.entries) entry.key.toString(): entry.value,
      };
    }
    return const {};
  }

  List<Map<String, dynamic>> _listOfMaps(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map) _map(item),
    ];
  }
}
