import 'package:kolo/data/services/android_capability_service.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/native_event_queue_store.dart';

class AndroidNativeEventQueueStore implements NativeEventQueueStore {
  const AndroidNativeEventQueueStore({
    required AndroidCapabilityService capabilities,
  }) : _capabilities = capabilities;

  final AndroidCapabilityService _capabilities;

  @override
  Future<void> append(NativeAndroidEvent event) async {
    return _capabilities.enqueueNativeEvent(event);
  }

  @override
  Future<List<NativeAndroidEvent>> peek() {
    return _capabilities.peekNativeEvents();
  }

  @override
  Future<List<NativeAndroidEvent>> drain() {
    return _capabilities.drainNativeEvents();
  }
}
