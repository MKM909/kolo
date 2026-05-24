import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/services/overlay_bubble_service.dart';

void main() {
  test('does not show overlay when permission is missing', () async {
    final platform = _FakeOverlayWindow(permissionGranted: false);
    final service = OverlayBubbleService(platform: platform);

    final shown = await service.showKoloBubble();

    expect(shown, isFalse);
    expect(platform.showCalls, 0);
  });

  test('does not open a duplicate overlay when already active', () async {
    final platform = _FakeOverlayWindow(permissionGranted: true, active: true);
    final service = OverlayBubbleService(platform: platform);

    final shown = await service.showKoloBubble();

    expect(shown, isTrue);
    expect(platform.showCalls, 0);
  });

  test('shows draggable Kolo overlay with bottom-right gravity', () async {
    final platform = _FakeOverlayWindow(permissionGranted: true);
    final service = OverlayBubbleService(platform: platform);

    final shown = await service.showKoloBubble();

    expect(shown, isTrue);
    expect(platform.showCalls, 1);
    expect(platform.height, 96);
    expect(platform.width, 260);
    expect(platform.alignment, OverlayAlignment.bottomRight);
    expect(platform.positionGravity, PositionGravity.auto);
    expect(platform.enableDrag, isTrue);
    expect(platform.overlayTitle, 'Kolo bubble active');
  });
}

class _FakeOverlayWindow implements OverlayWindowPlatform {
  _FakeOverlayWindow({required this.permissionGranted, this.active = false});

  final bool permissionGranted;
  final bool active;
  int showCalls = 0;
  int? height;
  int? width;
  OverlayAlignment? alignment;
  PositionGravity? positionGravity;
  bool? enableDrag;
  String? overlayTitle;

  @override
  Future<bool> isPermissionGranted() async => permissionGranted;

  @override
  Future<bool> isActive() async => active;

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
  }) async {
    showCalls += 1;
    this.height = height;
    this.width = width;
    this.alignment = alignment;
    this.positionGravity = positionGravity;
    this.enableDrag = enableDrag;
    this.overlayTitle = overlayTitle;
  }
}
