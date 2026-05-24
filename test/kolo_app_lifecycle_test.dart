import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/kolo_app.dart';
import 'package:kolo/app/providers.dart';

void main() {
  testWidgets('app lifecycle notifies the biometric session lock', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    final lock = container.read(biometricSessionLockProvider);
    lock.enable();

    var notifications = 0;
    lock.addListener(() => notifications += 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(notifications, 2);
  });
}
