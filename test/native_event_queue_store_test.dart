import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/services/android_capability_service.dart';
import 'package:kolo/data/services/android_native_event_queue_store.dart';
import 'package:kolo/domain/models/models.dart';

void main() {
  test(
    'AndroidNativeEventQueueStore exposes Dart-readable native events',
    () async {
      final event = NativeAndroidEvent(
        id: 'native-queue-1',
        type: 'sms_received',
        createdAt: DateTime(2026, 5, 26, 9),
        payload: const {'body': 'Kuda debit NGN 1,000'},
      );
      final capabilities = _FakeAndroidCapabilityService([event]);
      final store = AndroidNativeEventQueueStore(capabilities: capabilities);

      await store.append(event);
      final preview = await store.peek();
      final events = await store.drain();

      expect(preview, [event]);
      expect(events, [event]);
      expect(capabilities.appendedEvents, [event]);
      expect(capabilities.peekCalls, 1);
      expect(capabilities.drainCalls, 1);
    },
  );
}

class _FakeAndroidCapabilityService extends AndroidCapabilityService {
  _FakeAndroidCapabilityService(this.events);

  final List<NativeAndroidEvent> events;
  final appendedEvents = <NativeAndroidEvent>[];
  int peekCalls = 0;
  int drainCalls = 0;

  @override
  Future<void> enqueueNativeEvent(NativeAndroidEvent event) async {
    appendedEvents.add(event);
  }

  @override
  Future<List<NativeAndroidEvent>> peekNativeEvents() async {
    peekCalls += 1;
    return events;
  }

  @override
  Future<List<NativeAndroidEvent>> drainNativeEvents() async {
    drainCalls += 1;
    return events;
  }
}
