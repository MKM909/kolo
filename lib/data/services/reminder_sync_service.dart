import 'package:hive/hive.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/reminder_plan_builder.dart';
import 'package:kolo/domain/services/reminder_scheduler.dart';

const koloReminderScheduleBoxName = 'kolo_reminder_schedule';

abstract class ReminderScheduleStore {
  Future<Set<String>> loadIds();

  Future<void> saveIds(Set<String> ids);
}

class MemoryReminderScheduleStore implements ReminderScheduleStore {
  MemoryReminderScheduleStore({Set<String> initialIds = const {}})
    : _ids = {...initialIds};

  Set<String> _ids;

  @override
  Future<Set<String>> loadIds() async {
    return {..._ids};
  }

  @override
  Future<void> saveIds(Set<String> ids) async {
    _ids = {...ids};
  }
}

class HiveReminderScheduleStore implements ReminderScheduleStore {
  HiveReminderScheduleStore(this._box);

  static const _idsKey = 'scheduled_reminder_ids';

  final Box<Object?> _box;

  @override
  Future<Set<String>> loadIds() async {
    final rawIds = _box.get(_idsKey);
    if (rawIds is! Iterable) return const {};
    return rawIds.map((id) => id.toString()).toSet();
  }

  @override
  Future<void> saveIds(Set<String> ids) async {
    await _box.put(_idsKey, ids.toList()..sort());
  }
}

class ReminderSyncService {
  ReminderSyncService({
    required ReminderScheduler scheduler,
    ReminderScheduleStore? scheduleStore,
  }) : _scheduler = scheduler,
       _scheduleStore = scheduleStore ?? MemoryReminderScheduleStore();

  final ReminderScheduler _scheduler;
  final ReminderScheduleStore _scheduleStore;

  Future<int> sync(DashboardState dashboard, {DateTime? now}) async {
    if (dashboard.permissions[KoloPermission.notifications] !=
        PermissionGrantState.granted) {
      await _cancelLockedReminderGroups();
      await _cancelPreviouslyScheduledReminders();
      await _scheduleStore.saveIds(const {});
      return 0;
    }

    final plans = ReminderPlanBuilder.build(dashboard, now: now);
    final nextIds = plans.map((plan) => plan.id).toSet();
    final previousIds = await _scheduleStore.loadIds();
    for (final staleId in previousIds.difference(nextIds)) {
      await _scheduler.cancel(staleId);
    }
    for (final plan in plans) {
      await _scheduler.schedule(plan);
    }
    await _scheduleStore.saveIds(nextIds);
    return plans.length;
  }

  Future<void> _cancelLockedReminderGroups() async {
    for (final id in ['weekly-insight', 'bill-reminders', 'owing-reminders']) {
      await _scheduler.cancel(id);
    }
  }

  Future<void> _cancelPreviouslyScheduledReminders() async {
    final previousIds = await _scheduleStore.loadIds();
    for (final id in previousIds) {
      await _scheduler.cancel(id);
    }
  }
}
