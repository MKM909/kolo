import 'package:kolo/domain/models/models.dart';

abstract class ReminderScheduler {
  Future<void> schedule(ReminderScheduleIntent intent);

  Future<void> cancel(String id);
}
