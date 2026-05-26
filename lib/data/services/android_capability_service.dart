import 'package:flutter/services.dart';
import 'package:kolo/domain/models/models.dart';

class AndroidCapabilityService {
  AndroidCapabilityService({
    MethodChannel channel = const MethodChannel('kolo/android_capabilities'),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<List<InstalledAppCandidate>> getInstalledAppCandidates() async {
    final result = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'getInstalledAppCandidates',
    );
    if (result == null) return const [];
    final candidates = result
        .map(_installedAppCandidateFromPayload)
        .where((app) => app.packageName.isNotEmpty)
        .toList();
    candidates.sort(_compareInstalledAppCandidates);
    return candidates;
  }

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

  Future<List<NativeAndroidEvent>> peekNativeEvents() async {
    final result = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'peekNativeEvents',
    );
    if (result == null) return const [];
    return result.map(_nativeEventFromPayload).toList();
  }

  Future<void> enqueueNativeEvent(NativeAndroidEvent event) {
    return _channel.invokeMethod<void>('enqueueNativeEvent', {
      'id': event.id,
      'type': event.type,
      'createdAt': event.createdAt.millisecondsSinceEpoch,
      'payload': event.payload,
    });
  }

  Future<bool> startBackgroundWatcher() async {
    final started = await _channel.invokeMethod<bool>('startBackgroundWatcher');
    return started ?? false;
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

  InstalledAppCandidate _installedAppCandidateFromPayload(
    Map<dynamic, dynamic> item,
  ) {
    return InstalledAppCandidate(
      packageName: item['packageName'] as String? ?? '',
      displayName: item['displayName'] as String? ?? 'Installed app',
      installed:
          item['installed'] as bool? ?? item['enabled'] as bool? ?? false,
      isKnownFinancialApp: item['isKnownFinancialApp'] as bool? ?? false,
    );
  }

  int _compareInstalledAppCandidates(
    InstalledAppCandidate first,
    InstalledAppCandidate second,
  ) {
    final rankComparison = first.sortRank.compareTo(second.sortRank);
    if (rankComparison != 0) return rankComparison;
    return first.displayName.toLowerCase().compareTo(
      second.displayName.toLowerCase(),
    );
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
