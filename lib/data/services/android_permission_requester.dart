import 'package:kolo/data/services/android_capability_service.dart';
import 'package:kolo/data/services/kolo_background_service.dart';
import 'package:kolo/data/services/overlay_bubble_service.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/permission_requester.dart';
import 'package:permission_handler/permission_handler.dart';

class AndroidPermissionRequester implements PermissionRequester {
  AndroidPermissionRequester({
    AndroidCapabilityService? capabilities,
    OverlayBubbleService? overlayBubble,
    KoloBackgroundServiceController? backgroundService,
  }) : _capabilities = capabilities ?? AndroidCapabilityService(),
       _overlayBubble = overlayBubble ?? OverlayBubbleService(),
       _backgroundService =
           backgroundService ?? KoloBackgroundServiceController();

  final AndroidCapabilityService _capabilities;
  final OverlayBubbleService _overlayBubble;
  final KoloBackgroundServiceController _backgroundService;

  @override
  Future<PermissionGrantState> status(KoloPermission permission) async {
    switch (permission) {
      case KoloPermission.sms:
        return _fromStatus(await Permission.sms.status);
      case KoloPermission.notifications:
        return await _capabilities.isNotificationListenerEnabled()
            ? PermissionGrantState.granted
            : PermissionGrantState.denied;
      case KoloPermission.overlay:
        return await _overlayBubble.isPermissionGranted()
            ? PermissionGrantState.granted
            : PermissionGrantState.denied;
      case KoloPermission.accessibility:
        return await _capabilities.isAccessibilityServiceEnabled()
            ? PermissionGrantState.granted
            : PermissionGrantState.denied;
      case KoloPermission.backgroundService:
        return PermissionGrantState.notRequested;
    }
  }

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
        return await _overlayBubble.requestPermission()
            ? PermissionGrantState.granted
            : PermissionGrantState.notRequested;
      case KoloPermission.accessibility:
        await _capabilities.openAccessibilitySettings();
        return await _capabilities.isAccessibilityServiceEnabled()
            ? PermissionGrantState.granted
            : PermissionGrantState.notRequested;
      case KoloPermission.backgroundService:
        final configured = await _backgroundService.configure();
        final flutterStarted = await _backgroundService.start();
        final nativeStarted = await _capabilities.startBackgroundWatcher();
        return configured && flutterStarted && nativeStarted
            ? PermissionGrantState.granted
            : PermissionGrantState.notRequested;
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
