import 'package:flutter/services.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/reminder_scheduler.dart';

class AndroidReminderScheduler implements ReminderScheduler {
  const AndroidReminderScheduler({
    MethodChannel channel = const MethodChannel('kolo/reminders'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<void> schedule(ReminderScheduleIntent intent) async {
    try {
      await _channel.invokeMethod<void>('scheduleReminder', {
        'id': intent.id,
        'title': intent.title,
        'body': intent.body,
        'scheduledAt': intent.scheduledAt.millisecondsSinceEpoch,
        'payload': intent.payload,
      });
    } on MissingPluginException {
      return;
    }
  }

  @override
  Future<void> cancel(String id) async {
    try {
      await _channel.invokeMethod<void>('cancelReminder', {'id': id});
    } on MissingPluginException {
      return;
    }
  }
}
