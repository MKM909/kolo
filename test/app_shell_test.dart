import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/kolo_app.dart';
import 'package:kolo/domain/services/money_formatter.dart';

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

    expect(find.byKey(const Key('kolo_ai_chat_input')), findsOneWidget);
    expect(find.textContaining('Can I afford'), findsOneWidget);
  });

  testWidgets('AI prompt chips send the suggested question', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();

    const prompt = 'Can I afford a new pair of shoes?';
    expect(find.text(prompt), findsOneWidget);

    await tester.tap(find.text(prompt));
    await tester.pumpAndSettle();

    final sentPrompt = tester.widget<Text>(find.text(prompt));
    expect(sentPrompt.style?.color, Colors.white);
    expect(find.textContaining('I would keep'), findsOneWidget);
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

  testWidgets('transaction history opens a detail sheet with AI context', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chicken Republic'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transaction_detail_sheet')), findsOneWidget);
    expect(find.text('Food & Snacks'), findsWidgets);
    expect(
      find.text('Caution: food budget is climbing quickly.'),
      findsOneWidget,
    );
    expect(find.text('sms'), findsOneWidget);
  });

  testWidgets('balance adjustment sheet updates the dashboard balance', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('balance_adjust_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('balance_adjustment_sheet')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('balance_adjustment_amount')),
      '60000',
    );
    await tester.enterText(
      find.byKey(const Key('balance_adjustment_note')),
      'Matched bank app',
    );
    await tester.tap(find.byKey(const Key('save_balance_adjustment')));
    await tester.pumpAndSettle();

    expect(find.text(MoneyFormatter.formatKobo(6000000)), findsOneWidget);
  });

  testWidgets('budget category editing updates an allocation', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.pie_chart_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Food & Snacks'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('budget_category_sheet')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('budget_category_amount')),
      '35000',
    );
    await tester.tap(find.byKey(const Key('save_budget_category')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(MoneyFormatter.formatKobo(3500000)),
      findsOneWidget,
    );
  });

  testWidgets('home vaults quick action creates a savings vault', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vaults'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vaults_sheet')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('new_vault_name')),
      'Trip fund',
    );
    await tester.enterText(find.byKey(const Key('new_vault_target')), '250000');
    await tester.ensureVisible(find.byKey(const Key('save_new_vault')));
    await tester.tap(find.byKey(const Key('save_new_vault')));
    await tester.pumpAndSettle();

    expect(find.text('Trip fund'), findsOneWidget);
    expect(
      find.textContaining(MoneyFormatter.formatKobo(25000000)),
      findsOneWidget,
    );
  });

  testWidgets('vault detail sheet adds funds to an existing vault', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vaults'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Phone'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vault_detail_sheet')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('vault_contribution_amount')),
      '2500',
    );
    await tester.tap(find.byKey(const Key('save_vault_contribution')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(MoneyFormatter.formatKobo(4850000)),
      findsOneWidget,
    );
  });

  testWidgets('home owings quick action creates an owing record', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Owings'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('owings_sheet')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('new_owing_person')), 'Sade');
    await tester.enterText(find.byKey(const Key('new_owing_amount')), '12000');
    await tester.ensureVisible(find.byKey(const Key('save_new_owing')));
    await tester.tap(find.byKey(const Key('save_new_owing')));
    await tester.pumpAndSettle();

    expect(find.text('Sade'), findsOneWidget);
    expect(
      find.textContaining(MoneyFormatter.formatKobo(1200000)),
      findsOneWidget,
    );
  });

  testWidgets('owing detail sheet marks an owing as settled', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Owings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Timi'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('owing_detail_sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settle_owing')));
    await tester.pumpAndSettle();

    expect(find.text('Settled'), findsOneWidget);
  });

  testWidgets('owing detail sheet drafts a reminder message', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Owings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Timi'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('owing_detail_sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('draft_owing_reminder')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('owing_reminder_draft')), findsOneWidget);
    expect(find.textContaining('Hi Timi'), findsOneWidget);
    expect(
      find.textContaining(MoneyFormatter.formatKobo(350000)),
      findsWidgets,
    );
  });

  testWidgets('profile gig tracker logs a new gig', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Gig Tracker'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('open_gig_tracker')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gig_tracker_sheet')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('new_gig_client')),
      'Muna Foods',
    );
    await tester.enterText(find.byKey(const Key('new_gig_amount')), '90000');
    await tester.enterText(
      find.byKey(const Key('new_gig_project_type')),
      'Brand kit',
    );
    await tester.ensureVisible(find.byKey(const Key('save_new_gig')));
    await tester.tap(find.byKey(const Key('save_new_gig')));
    await tester.pumpAndSettle();

    expect(find.text('Muna Foods'), findsWidgets);
    expect(find.text('Brand kit'), findsOneWidget);
    expect(
      find.textContaining(MoneyFormatter.formatKobo(9000000)),
      findsWidgets,
    );
  });

  testWidgets('profile bill reminders logs a new bill', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Bill Reminders'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('open_bill_reminders')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bill_reminders_sheet')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('new_bill_name')), 'Netflix');
    await tester.enterText(find.byKey(const Key('new_bill_amount')), '5000');
    await tester.enterText(
      find.byKey(const Key('new_bill_frequency')),
      'Monthly',
    );
    await tester.enterText(
      find.byKey(const Key('new_bill_next_due')),
      '2026-06-01',
    );
    await tester.ensureVisible(find.byKey(const Key('save_new_bill')));
    await tester.tap(find.byKey(const Key('save_new_bill')));
    await tester.pumpAndSettle();

    expect(find.text('Netflix'), findsWidgets);
    expect(find.text('Monthly'), findsWidgets);
    expect(
      find.textContaining(MoneyFormatter.formatKobo(500000)),
      findsWidgets,
    );
  });

  testWidgets('bill reminder detail pauses an active bill', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Bill Reminders'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('open_bill_reminders')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bill_card_bill-data')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bill_detail_sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('pause_bill_bill-data')));
    await tester.pumpAndSettle();

    expect(find.text('Paused'), findsWidgets);
  });

  testWidgets('bill reminder detail marks a bill as paid', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Bill Reminders'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('open_bill_reminders')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bill_card_bill-data')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bill_detail_sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mark_bill_paid_bill-data')));
    await tester.pumpAndSettle();

    expect(find.textContaining('2026-06-27'), findsWidgets);
    expect(find.textContaining('Balance is now'), findsWidgets);
  });

  testWidgets('profile partner sharing invites and revokes a partner', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Partner Sharing'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('open_partner_sharing')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('partner_sharing_sheet')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('new_partner_email')),
      'ade@example.com',
    );
    await tester.ensureVisible(find.byKey(const Key('save_new_partner')));
    await tester.tap(find.byKey(const Key('save_new_partner')));
    await tester.pumpAndSettle();

    expect(find.text('ade@example.com'), findsWidgets);
    expect(find.text('pending'), findsWidgets);

    await tester.tap(find.byKey(const Key('revoke_partner_share-1')));
    await tester.pumpAndSettle();

    expect(find.text('revoked'), findsWidgets);
  });

  testWidgets('profile watched apps toggles an app', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Watched Apps'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('open_watched_apps')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('watched_apps_sheet')), findsOneWidget);

    final opayToggle = find.byKey(
      const Key('toggle_watched_app_team.opay.pay'),
    );
    expect(tester.widget<SwitchListTile>(opayToggle).value, isFalse);

    await tester.tap(opayToggle);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(opayToggle).value, isTrue);
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
