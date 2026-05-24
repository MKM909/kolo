import 'package:kolo/data/services/android_capability_service.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/permission_requester.dart';
import 'package:permission_handler/permission_handler.dart';

class AndroidPermissionRequester implements PermissionRequester {
  AndroidPermissionRequester({AndroidCapabilityService? capabilities})
    : _capabilities = capabilities ?? AndroidCapabilityService();

  final AndroidCapabilityService _capabilities;

  @override
  Future<PermissionGrantState> request(KoloPermission permission) async {
    switch (permission) {
      case KoloPermission.sms:
        return _fromStatus(await Permission.sms.request());
      case KoloPermission.notifications:
        await _capabilities.openNotificationListenerSettings();
        return await _capabilities.isNotificationListenerEnabled()
            ? PermissionGrantState.granted
            : PermissionGrantState.notRequested;
      case KoloPermission.overlay:
        return _fromStatus(await Permission.systemAlertWindow.request());
      case KoloPermission.accessibility:
        await _capabilities.openAccessibilitySettings();
        return await _capabilities.isAccessibilityServiceEnabled()
            ? PermissionGrantState.granted
            : PermissionGrantState.notRequested;
      case KoloPermission.backgroundService:
        return PermissionGrantState.granted;
    }
  }

  PermissionGrantState _fromStatus(PermissionStatus status) {
    if (status.isGranted) return PermissionGrantState.granted;
    if (status.isDenied || status.isPermanentlyDenied) {
      return PermissionGrantState.denied;
    }
    return PermissionGrantState.notRequested;
  }
}
