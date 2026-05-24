import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/kolo_app.dart';

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
}
