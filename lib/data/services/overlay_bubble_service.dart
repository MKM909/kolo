import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:kolo/domain/models/models.dart';

abstract class OverlayWindowPlatform {
  Future<bool> isPermissionGranted();

  Future<bool> isActive();

  Future<bool?> requestPermission();

  Future<void> showOverlay({
    required int height,
    required int width,
    required OverlayAlignment alignment,
    required OverlayFlag flag,
    required String overlayTitle,
    required String overlayContent,
    required bool enableDrag,
    required PositionGravity positionGravity,
  });

  Future<bool?> resizeOverlay({
    required int width,
    required int height,
    required bool enableDrag,
  });

  Future<Object?> shareData(Object? data);

  Stream<Object?> get overlayListener;
}

class FlutterOverlayWindowPlatform implements OverlayWindowPlatform {
  const FlutterOverlayWindowPlatform();

  static final Stream<Object?> _overlayMessages = FlutterOverlayWindow
      .overlayListener
      .asBroadcastStream();

  @override
  Future<bool> isPermissionGranted() {
    return FlutterOverlayWindow.isPermissionGranted();
  }

  @override
  Future<bool> isActive() {
    return FlutterOverlayWindow.isActive();
  }

  @override
  Future<bool?> requestPermission() {
    return FlutterOverlayWindow.requestPermission();
  }

  @override
  Future<void> showOverlay({
    required int height,
    required int width,
    required OverlayAlignment alignment,
    required OverlayFlag flag,
    required String overlayTitle,
    required String overlayContent,
    required bool enableDrag,
    required PositionGravity positionGravity,
  }) {
    return FlutterOverlayWindow.showOverlay(
      height: height,
      width: width,
      alignment: alignment,
      flag: flag,
      overlayTitle: overlayTitle,
      overlayContent: overlayContent,
      enableDrag: enableDrag,
      positionGravity: positionGravity,
    );
  }

  @override
  Future<bool?> resizeOverlay({
    required int width,
    required int height,
    required bool enableDrag,
  }) {
    return FlutterOverlayWindow.resizeOverlay(width, height, enableDrag);
  }

  @override
  Future<Object?> shareData(Object? data) {
    return FlutterOverlayWindow.shareData(data);
  }

  @override
  Stream<Object?> get overlayListener => _overlayMessages;
}

class OverlayBubbleService {
  OverlayBubbleService({OverlayWindowPlatform? platform})
    : _platform = platform ?? const FlutterOverlayWindowPlatform();

  final OverlayWindowPlatform _platform;

  Future<bool> isPermissionGranted() {
    return _platform.isPermissionGranted();
  }

  Future<bool> showKoloBubble() async {
    final hasPermission = await isPermissionGranted();
    if (!hasPermission) {
      return false;
    }

    final isActive = await _platform.isActive();
    if (isActive) {
      return true;
    }

    await _platform.showOverlay(
      height: 116,
      width: 278,
      alignment: OverlayAlignment.bottomRight,
      flag: OverlayFlag.defaultFlag,
      overlayTitle: 'Kolo bubble active',
      overlayContent: 'Tap Kolo for a quick money check before spending.',
      enableDrag: true,
      positionGravity: PositionGravity.auto,
    );
    return true;
  }

  Future<bool> showBlockOverlay({
    required String appName,
    required String packageName,
    required WatchedAppBlockLevel blockLevel,
    required String prompt,
  }) async {
    final hasPermission = await isPermissionGranted();
    if (!hasPermission) {
      return false;
    }

    final isActive = await _platform.isActive();
    if (isActive) {
      await _platform.resizeOverlay(
        width: WindowSize.fullCover,
        height: WindowSize.fullCover,
        enableDrag: false,
      );
    } else {
      await _platform.showOverlay(
        height: WindowSize.fullCover,
        width: WindowSize.fullCover,
        alignment: OverlayAlignment.center,
        flag: OverlayFlag.focusPointer,
        overlayTitle: 'Kolo block overlay active',
        overlayContent: 'Kolo is checking this app launch with you.',
        enableDrag: false,
        positionGravity: PositionGravity.none,
      );
    }

    await _platform.shareData({
      'type': 'blockOverlay',
      'appName': appName,
      'packageName': packageName,
      'blockLevel': blockLevel.name,
      'prompt': prompt,
    });
    return true;
  }

  Future<bool> requestPermission() async {
    return await _platform.requestPermission() ?? false;
  }

  Future<bool?> expandConversation() {
    return _platform.resizeOverlay(
      width: WindowSize.matchParent,
      height: 540,
      enableDrag: false,
    );
  }

  Future<bool?> collapseToBubble() {
    return _platform.resizeOverlay(width: 278, height: 116, enableDrag: true);
  }

  Future<Object?> sendPromptToOverlay(String prompt) {
    return _platform.shareData({'type': 'prompt', 'text': prompt});
  }

  Future<Object?> sendAssistantMessageToOverlay(String message) {
    return _platform.shareData({'type': 'assistantMessage', 'text': message});
  }

  Future<Object?> sendBlockDecisionToOverlay({
    required String status,
    required String message,
    required String appName,
    required String packageName,
    required String blockLevel,
  }) {
    return _platform.shareData({
      'type': 'blockDecision',
      'status': status,
      'message': message,
      'appName': appName,
      'packageName': packageName,
      'blockLevel': blockLevel,
    });
  }

  Stream<Object?> get overlayMessages => _platform.overlayListener;
}
