import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/kolo_app.dart';

void main() {
  testWidgets('Kolo app shell renders all primary tabs', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    expect(find.text('Kolo'), findsWidgets);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Transactions'), findsWidgets);
    expect(find.text('AI'), findsWidgets);
    expect(find.text('Budget'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
    expect(find.textContaining('₦'), findsWidgets);
  });

  testWidgets('bottom navigation switches to Kolo AI chat', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();

    expect(find.text('Ask Kolo'), findsOneWidget);
    expect(find.textContaining('Can I afford'), findsOneWidget);
  });

  testWidgets('manual expense logging updates the dashboard', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log Expense'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('transaction_amount')), '2500');
    await tester.enterText(
      find.byKey(const Key('transaction_description')),
      'Suya stop',
    );
    await tester.ensureVisible(find.byKey(const Key('save_transaction')));
    await tester.tap(find.byKey(const Key('save_transaction')));
    await tester.pumpAndSettle();

    expect(find.text('₦48,300.00'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Suya stop'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Suya stop'), findsOneWidget);
    expect(find.text('-₦2,500.00'), findsOneWidget);
  });

  testWidgets('profile can grant a permission from locked state', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('notifications'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('grant_notifications')));
    await tester.pumpAndSettle();

    expect(find.text('granted'), findsWidgets);
  });
}
