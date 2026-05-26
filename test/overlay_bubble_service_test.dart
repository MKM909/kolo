import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/services/overlay_bubble_service.dart';
import 'package:kolo/domain/models/models.dart';

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
    expect(platform.height, 116);
    expect(platform.width, 278);
    expect(platform.alignment, OverlayAlignment.bottomRight);
    expect(platform.positionGravity, PositionGravity.auto);
    expect(platform.enableDrag, isTrue);
    expect(platform.overlayTitle, 'Kolo bubble active');
  });

  test('resizes overlay between idle and conversation states', () async {
    final platform = _FakeOverlayWindow(permissionGranted: true);
    final service = OverlayBubbleService(platform: platform);

    await service.expandConversation();
    await service.collapseToBubble();

    expect(platform.resizeCalls, [
      (width: -1, height: 540, enableDrag: false),
      (width: 278, height: 116, enableDrag: true),
    ]);
  });

  test('shares prompts with the overlay conversation entrypoint', () async {
    final platform = _FakeOverlayWindow(permissionGranted: true);
    final service = OverlayBubbleService(platform: platform);

    await service.sendPromptToOverlay('Check this spend');

    expect(platform.sharedData, [
      {'type': 'prompt', 'text': 'Check this spend'},
    ]);
  });

  test('shares assistant messages with the overlay conversation', () async {
    final platform = _FakeOverlayWindow(permissionGranted: true);
    final service = OverlayBubbleService(platform: platform);

    await service.sendAssistantMessageToOverlay('Pause before sending money.');

    expect(platform.sharedData, [
      {'type': 'assistantMessage', 'text': 'Pause before sending money.'},
    ]);
  });

  test('shows full-screen block overlays with watched app context', () async {
    final platform = _FakeOverlayWindow(permissionGranted: true);
    final service = OverlayBubbleService(platform: platform);

    final shown = await service.showBlockOverlay(
      appName: 'Kuda',
      packageName: 'com.kuda.android',
      blockLevel: WatchedAppBlockLevel.hardLock,
      prompt: 'Before you go in, what is the plan?',
    );

    expect(shown, isTrue);
    expect(platform.showCalls, 1);
    expect(platform.height, WindowSize.fullCover);
    expect(platform.width, WindowSize.fullCover);
    expect(platform.alignment, OverlayAlignment.center);
    expect(platform.positionGravity, PositionGravity.none);
    expect(platform.enableDrag, isFalse);
    expect(platform.overlayTitle, 'Kolo block overlay active');
    expect(platform.sharedData.single, {
      'type': 'blockOverlay',
      'appName': 'Kuda',
      'packageName': 'com.kuda.android',
      'blockLevel': 'hardLock',
      'prompt': 'Before you go in, what is the plan?',
    });
  });

  test('reopens an active overlay before sharing block context', () async {
    final platform = _FakeOverlayWindow(permissionGranted: true, active: true);
    final service = OverlayBubbleService(platform: platform);

    final shown = await service.showBlockOverlay(
      appName: 'Kuda',
      packageName: 'com.kuda.android',
      blockLevel: WatchedAppBlockLevel.explain,
      prompt: 'Before you go in, what is this for?',
    );

    expect(shown, isTrue);
    expect(platform.closeCalls, 1);
    expect(platform.showCalls, 1);
    expect(platform.resizeCalls, isEmpty);
    expect(platform.sharedData.single, containsPair('blockLevel', 'explain'));
  });

  test('reopens active overlays as focusable block overlays', () async {
    final platform = _FakeOverlayWindow(permissionGranted: true, active: true);
    final service = OverlayBubbleService(platform: platform);

    final shown = await service.showBlockOverlay(
      appName: 'Kuda',
      packageName: 'com.kuda.android',
      blockLevel: WatchedAppBlockLevel.hardLock,
      prompt: 'Before you go in, what is the plan?',
    );

    expect(shown, isTrue);
    expect(platform.showCalls, 1);
    expect(platform.flag, OverlayFlag.focusPointer);
    expect(platform.height, WindowSize.fullCover);
    expect(platform.width, WindowSize.fullCover);
    expect(platform.enableDrag, isFalse);
  });

  test('requests overlay permission through the overlay platform', () async {
    final platform = _FakeOverlayWindow(
      permissionGranted: false,
      requestPermissionResult: true,
    );
    final service = OverlayBubbleService(platform: platform);

    final granted = await service.requestPermission();

    expect(granted, isTrue);
    expect(platform.requestPermissionCalls, 1);
  });

  test('treats a null overlay permission response as not granted', () async {
    final platform = _FakeOverlayWindow(permissionGranted: false);
    final service = OverlayBubbleService(platform: platform);

    final granted = await service.requestPermission();

    expect(granted, isFalse);
    expect(platform.requestPermissionCalls, 1);
  });
}

class _FakeOverlayWindow implements OverlayWindowPlatform {
  _FakeOverlayWindow({
    required this.permissionGranted,
    this.active = false,
    this.requestPermissionResult,
  });

  final bool permissionGranted;
  final bool active;
  final bool? requestPermissionResult;
  int showCalls = 0;
  int closeCalls = 0;
  int requestPermissionCalls = 0;
  int? height;
  int? width;
  OverlayAlignment? alignment;
  PositionGravity? positionGravity;
  bool? enableDrag;
  OverlayFlag? flag;
  String? overlayTitle;
  final resizeCalls = <({int width, int height, bool enableDrag})>[];
  final sharedData = <Object?>[];

  @override
  Future<bool> isPermissionGranted() async => permissionGranted;

  @override
  Future<bool> isActive() async => active;

  @override
  Future<bool?> requestPermission() async {
    requestPermissionCalls += 1;
    return requestPermissionResult;
  }

  @override
  Future<bool?> closeOverlay() async {
    closeCalls += 1;
    return true;
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
  }) async {
    showCalls += 1;
    this.height = height;
    this.width = width;
    this.alignment = alignment;
    this.positionGravity = positionGravity;
    this.enableDrag = enableDrag;
    this.flag = flag;
    this.overlayTitle = overlayTitle;
  }

  @override
  Future<bool?> resizeOverlay({
    required int width,
    required int height,
    required bool enableDrag,
  }) async {
    resizeCalls.add((width: width, height: height, enableDrag: enableDrag));
    return true;
  }

  @override
  Future<Object?> shareData(Object? data) async {
    sharedData.add(data);
    return data;
  }

  @override
  Stream<Object?> get overlayListener => const Stream.empty();
}
