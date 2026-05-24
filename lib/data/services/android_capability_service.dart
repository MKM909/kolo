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

  Future<bool> openAccessibilitySettings() async {
    final opened = await _channel.invokeMethod<bool>(
      'openAccessibilitySettings',
    );
    return opened ?? false;
  }

  Future<bool> openNotificationListenerSettings() async {
    final opened = await _channel.invokeMethod<bool>(
      'openNotificationListenerSettings',
    );
    return opened ?? false;
  }
}
