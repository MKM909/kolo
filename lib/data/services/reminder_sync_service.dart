import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/reminder_plan_builder.dart';
import 'package:kolo/domain/services/reminder_scheduler.dart';

class ReminderSyncService {
  const ReminderSyncService({required ReminderScheduler scheduler})
    : _scheduler = scheduler;

  final ReminderScheduler _scheduler;

  Future<int> sync(DashboardState dashboard, {DateTime? now}) async {
    if (dashboard.permissions[KoloPermission.notifications] !=
        PermissionGrantState.granted) {
      await _cancelLockedReminderGroups();
      return 0;
    }

    final plans = ReminderPlanBuilder.build(dashboard, now: now);
    for (final plan in plans) {
      await _scheduler.schedule(plan);
    }
    return plans.length;
  }

  Future<void> _cancelLockedReminderGroups() async {
    for (final id in ['weekly-insight', 'bill-reminders', 'owing-reminders']) {
      await _scheduler.cancel(id);
    }
  }
}
