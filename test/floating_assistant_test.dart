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
}
