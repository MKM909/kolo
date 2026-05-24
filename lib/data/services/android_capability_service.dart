import 'package:flutter/services.dart';
import 'package:kolo/domain/models/models.dart';

class AndroidCapabilityService {
  AndroidCapabilityService({
    MethodChannel channel = const MethodChannel('kolo/android_capabilities'),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<List<WatchedApp>> getSuggestedBankingApps() async {
    final result = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'getSuggestedBankingApps',
    );
    if (result == null) return const [];
    return result
        .map(
          (item) => WatchedApp(
            packageName: item['packageName'] as String? ?? '',
            displayName: item['displayName'] as String? ?? 'Banking app',
            enabled: item['enabled'] as bool? ?? false,
          ),
        )
        .where((app) => app.packageName.isNotEmpty)
        .toList();
  }

  Future<List<NativeAndroidEvent>> drainNativeEvents() async {
    final result = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'drainNativeEvents',
    );
    if (result == null) return const [];
    return result.map(_nativeEventFromPayload).toList();
  }

  Future<bool> openAccessibilitySettings() async {
    final opened = await _channel.invokeMethod<bool>(
      'openAccessibilitySettings',
    );
    return opened ?? false;
  }

  Future<bool> isAccessibilityServiceEnabled() async {
    final enabled = await _channel.invokeMethod<bool>(
      'isAccessibilityServiceEnabled',
    );
    return enabled ?? false;
  }

  Future<bool> openNotificationListenerSettings() async {
    final opened = await _channel.invokeMethod<bool>(
      'openNotificationListenerSettings',
    );
    return opened ?? false;
  }

  Future<bool> isNotificationListenerEnabled() async {
    final enabled = await _channel.invokeMethod<bool>(
      'isNotificationListenerEnabled',
    );
    return enabled ?? false;
  }

  NativeAndroidEvent _nativeEventFromPayload(Map<dynamic, dynamic> item) {
    final rawPayload = item['payload'];
    final payload = rawPayload is Map
        ? {
            for (final entry in rawPayload.entries)
              entry.key.toString(): entry.value as Object?,
          }
        : <String, Object?>{};
    final createdAtMillis = switch (item['createdAt']) {
      final int value => value,
      final num value => value.toInt(),
      _ => 0,
    };

    return NativeAndroidEvent(
      id: item['id'] as String? ?? '',
      type: item['type'] as String? ?? 'unknown',
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMillis),
      payload: payload,
    );
  }
}
