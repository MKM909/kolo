import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/services/android_reminder_scheduler.dart';
import 'package:kolo/domain/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/kolo_reminders');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('schedules and cancels reminders through the Android channel', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

    final scheduler = AndroidReminderScheduler(channel: channel);
    final intent = ReminderScheduleIntent(
      id: 'bill-data-1d',
      title: 'Data renewal tomorrow',
      body: 'Keep ₦2,500.00 ready.',
      scheduledAt: DateTime(2026, 5, 29, 9),
      payload: const {'kind': 'bill', 'billId': 'bill-data'},
    );

    await scheduler.schedule(intent);
    await scheduler.cancel(intent.id);

    expect(calls.first.method, 'scheduleReminder');
    expect(calls.first.arguments, {
      'id': 'bill-data-1d',
      'title': 'Data renewal tomorrow',
      'body': 'Keep ₦2,500.00 ready.',
      'scheduledAt': DateTime(2026, 5, 29, 9).millisecondsSinceEpoch,
      'payload': {'kind': 'bill', 'billId': 'bill-data'},
    });
    expect(calls.last.method, 'cancelReminder');
    expect(calls.last.arguments, {'id': 'bill-data-1d'});
  });
}
