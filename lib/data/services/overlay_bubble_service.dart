import 'package:flutter_overlay_window/flutter_overlay_window.dart';

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
}

class FlutterOverlayWindowPlatform implements OverlayWindowPlatform {
  const FlutterOverlayWindowPlatform();

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
}

class OverlayBubbleService {
  OverlayBubbleService({OverlayWindowPlatform? platform})
    : _platform = platform ?? const FlutterOverlayWindowPlatform();

  final OverlayWindowPlatform _platform;

  Future<bool> showKoloBubble() async {
    final hasPermission = await _platform.isPermissionGranted();
    if (!hasPermission) {
      return false;
    }

    final isActive = await _platform.isActive();
    if (isActive) {
      return true;
    }

    await _platform.showOverlay(
      height: 96,
      width: 260,
      alignment: OverlayAlignment.bottomRight,
      flag: OverlayFlag.defaultFlag,
      overlayTitle: 'Kolo bubble active',
      overlayContent: 'Tap Kolo for a quick money check before spending.',
      enableDrag: true,
      positionGravity: PositionGravity.auto,
    );
    return true;
  }

  Future<bool> requestPermission() async {
    return await _platform.requestPermission() ?? false;
  }
}
