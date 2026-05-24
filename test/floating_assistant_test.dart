import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/kolo_app.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/ui/features/assistant/kolo_floating_assistant.dart';

void main() {
  testWidgets('shell shows liquid aether Kolo assistant bubble', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kolo_floating_assistant')), findsOneWidget);
    expect(find.byKey(const Key('kolo_liquid_aether_orb')), findsOneWidget);
    expect(find.text('Need a quick money check?'), findsOneWidget);
  });

  testWidgets(
    'floating assistant opens a conversation panel and sends a reply',
    (tester) async {
      await tester.pumpWidget(const KoloApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('kolo_liquid_aether_orb')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('kolo_floating_conversation')),
        findsOneWidget,
      );
      expect(find.text('Ask Kolo from anywhere'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('kolo_floating_input')),
        'Can I afford data?',
      );
      await tester.tap(find.byKey(const Key('kolo_floating_send')));
      await tester.pumpAndSettle();

      expect(find.text('Can I afford data?'), findsOneWidget);
    },
  );

  testWidgets('floating assistant can close while offline', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(
            (ref) => Stream<DashboardState>.error(StateError('offline')),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Stack(children: [KoloFloatingAssistant()])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('kolo_liquid_aether_orb')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kolo_floating_conversation')), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);

    await tester.tap(find.byTooltip('Close Kolo'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kolo_floating_conversation')), findsNothing);
    expect(find.byKey(const Key('kolo_liquid_aether_orb')), findsOneWidget);
  });
}
