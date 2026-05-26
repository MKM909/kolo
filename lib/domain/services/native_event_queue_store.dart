import 'package:kolo/domain/models/models.dart';

abstract class NativeEventQueueStore {
  Future<void> append(NativeAndroidEvent event);

  Future<List<NativeAndroidEvent>> peek();

  Future<List<NativeAndroidEvent>> drain();
}
