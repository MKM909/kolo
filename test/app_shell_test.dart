import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/kolo_app.dart';
import 'package:kolo/domain/services/money_formatter.dart';

void main() {
  setUpAll(() {
    WidgetController.hitTestWarningShouldBeFatal = true;
  });

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

    await tester.tap(find.byIcon(Icons.auto_awesome).last);
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

  testWidgets('profile AI history can clear chat messages', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();

    const customPrompt = 'How much can I save this week?';
    await tester.enterText(
      find.byKey(const Key('kolo_ai_chat_input')),
      customPrompt,
    );
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text(customPrompt), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('AI Chat History'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('open_ai_history')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai_history_sheet')), findsOneWidget);
    expect(find.text(customPrompt), findsWidgets);

    await tester.tap(find.byKey(const Key('clear_ai_history')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.auto_awesome).last);
    await tester.pumpAndSettle();

    expect(find.text(customPrompt), findsNothing);
  });

  testWidgets('profile menu changes the Kolo AI model', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Kolo AI Model'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Gemini 3.1 Flash Lite'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('open_ai_model_settings')));
    await tester.tap(find.byKey(const Key('open_ai_model_settings')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai_model_settings_sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai_model_option_gemini_3_1_flash')));
    await tester.pumpAndSettle();

    expect(find.text('Gemini 3.1 Flash'), findsWidgets);
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

  testWidgets('manual expense logging accepts a custom transaction date', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log Expense'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transaction_date')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('transaction_amount')), '2500');
    await tester.enterText(
      find.byKey(const Key('transaction_description')),
      'Missed bus fare',
    );
    await tester.enterText(
      find.byKey(const Key('transaction_date')),
      '2026-05-20',
    );
    await tester.ensureVisible(find.byKey(const Key('save_transaction')));
    await tester.tap(find.byKey(const Key('save_transaction')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Missed bus fare'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transaction_detail_sheet')), findsOneWidget);
    expect(find.text('2026-05-20'), findsOneWidget);
  });

  testWidgets('manual over-budget expense stores a Kolo justification note', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log Expense'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('transaction_amount')),
      '20000',
    );
    await tester.enterText(
      find.byKey(const Key('transaction_description')),
      'Birthday food',
    );
    await tester.ensureVisible(find.byKey(const Key('save_transaction')));
    await tester.tap(find.byKey(const Key('save_transaction')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('spending_justification_field')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('spending_justification_field')),
      'Birthday dinner for my sister',
    );
    await tester.tap(find.byKey(const Key('save_spending_justification')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('spending_decision_card')), findsOneWidget);
    expect(
      find.textContaining('Caution - Birthday dinner for my sister'),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const Key('override_spending_decision')),
    );
    await tester.tap(find.byKey(const Key('override_spending_decision')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Birthday food'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transaction_detail_sheet')), findsOneWidget);
    expect(
      find.textContaining('Birthday dinner for my sister'),
      findsOneWidget,
    );
    expect(find.textContaining('over Food & Snacks'), findsOneWidget);
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

  testWidgets('transaction detail sheet corrects category', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chicken Republic'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transaction_detail_sheet')), findsOneWidget);
    expect(
      find.byKey(const Key('transaction_category_dropdown')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('transaction_category_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transport').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save_transaction_category')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transaction_detail_sheet')), findsNothing);
    expect(find.text('Transport'), findsOneWidget);
  });

  testWidgets('transaction history filters income and expense rows', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Landing page gig'), findsOneWidget);
    expect(find.text('Chicken Republic'), findsOneWidget);

    await tester.tap(find.byKey(const Key('transaction_filter_income')));
    await tester.pumpAndSettle();

    expect(find.text('Landing page gig'), findsOneWidget);
    expect(find.text('Chicken Republic'), findsNothing);

    await tester.tap(find.byKey(const Key('transaction_filter_expense')));
    await tester.pumpAndSettle();

    expect(find.text('Landing page gig'), findsNothing);
    expect(find.text('Chicken Republic'), findsOneWidget);
  });

  testWidgets('home section actions navigate to budget and transactions', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home_budget_summary_view')));
    await tester.pumpAndSettle();

    expect(find.text('Categories'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('home_recent_transactions_view_all')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 120));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('home_recent_transactions_view_all')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transaction_filter_all')), findsOneWidget);
  });

  testWidgets('home can refresh weekly Kolo insights', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('generate_weekly_insight')),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Kolo weekly spending check'), findsNothing);

    await tester.tap(find.byKey(const Key('generate_weekly_insight')));
    await tester.pumpAndSettle();

    expect(find.text('Kolo weekly spending check'), findsOneWidget);
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

  testWidgets('budget analytics switches between weekly and monthly periods', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.pie_chart_outline));
    await tester.pumpAndSettle();

    final periodLabel = find.byKey(const Key('budget_period_label'));
    expect(find.byKey(const Key('budget_period_week')), findsOneWidget);
    expect(find.byKey(const Key('budget_period_month')), findsOneWidget);
    expect(tester.widget<Text>(periodLabel).data, 'This Week');

    await tester.tap(find.byKey(const Key('budget_period_month')));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(periodLabel).data, 'This Month');

    await tester.scrollUntilVisible(
      find.byKey(const Key('budget_weekly_bar_chart')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('budget_weekly_bar_chart')), findsOneWidget);
  });

  testWidgets('budget ask Kolo action opens AI with a re-plan prompt', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.pie_chart_outline));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('budget_ask_kolo_replan')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('budget_ask_kolo_replan')));
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(
      find.byKey(const Key('kolo_ai_chat_input')),
    );
    expect(input.controller?.text, contains('Redo my budget'));
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
    expect(find.byKey(const Key('new_vault_deadline')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('new_vault_deadline')),
      '2026-12-20',
    );
    await tester.ensureVisible(find.byKey(const Key('save_new_vault')));
    await tester.tap(find.byKey(const Key('save_new_vault')));
    await tester.pumpAndSettle();

    expect(find.text('Trip fund'), findsOneWidget);
    expect(find.text('Deadline 2026-12-20'), findsOneWidget);
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

    await tester.tap(find.text('New Phone'));
    await tester.pumpAndSettle();

    expect(find.text('Contribution history'), findsOneWidget);
    expect(
      find.textContaining('+${MoneyFormatter.formatKobo(250000)}'),
      findsOneWidget,
    );
  });

  testWidgets('vault detail sheet edits target amount', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vaults'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Phone'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('vault_target_amount')),
      '240000',
    );
    await tester.tap(find.byKey(const Key('save_vault_target')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(MoneyFormatter.formatKobo(24000000)),
      findsOneWidget,
    );
  });

  testWidgets('vault detail sheet deletes an existing vault', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vaults'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Phone'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vault_detail_sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete_vault')));
    await tester.pumpAndSettle();

    expect(find.text('New Phone'), findsNothing);
    expect(find.textContaining('removed from protected funds'), findsWidgets);
  });

  testWidgets('owings sheet filters records by direction', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Owings'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('owings_sheet')), findsOneWidget);
    expect(find.text('Timi'), findsOneWidget);
    expect(find.text('Ada'), findsNothing);

    await tester.tap(find.byKey(const Key('owings_filter_i_owe_them')));
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Timi'), findsNothing);

    await tester.tap(find.byKey(const Key('owings_filter_they_owe_me')));
    await tester.pumpAndSettle();

    expect(find.text('Timi'), findsOneWidget);
    expect(find.text('Ada'), findsNothing);
  });

  testWidgets('owing cards show age and action labels', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Owings'));
    await tester.pumpAndSettle();

    expect(find.textContaining('May 18'), findsOneWidget);
    expect(find.textContaining('days ago'), findsOneWidget);
    expect(find.text('Remind'), findsOneWidget);

    await tester.tap(find.byKey(const Key('owings_filter_i_owe_them')));
    await tester.pumpAndSettle();

    expect(find.textContaining('May 21'), findsOneWidget);
    expect(find.text('Settle'), findsOneWidget);
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
    expect(find.byKey(const Key('new_owing_due_date')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('new_owing_due_date')),
      '2026-05-28',
    );
    await tester.ensureVisible(find.byKey(const Key('save_new_owing')));
    await tester.tap(find.byKey(const Key('save_new_owing')));
    await tester.pumpAndSettle();

    expect(find.text('Sade'), findsOneWidget);
    expect(
      find.textContaining(MoneyFormatter.formatKobo(1200000)),
      findsOneWidget,
    );
    expect(find.text('Due 2026-05-28'), findsOneWidget);

    await tester.ensureVisible(find.text('Sade'));
    await tester.tap(find.text('Sade'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('owing_detail_sheet')), findsOneWidget);
    expect(find.text('2026-05-28'), findsWidgets);
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

  testWidgets('owing detail sheet deletes an owing', (tester) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Owings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Timi'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('delete_owing')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('owing_detail_sheet')), findsNothing);
    expect(find.text('Owing removed'), findsOneWidget);
    expect(find.text('Timi'), findsNothing);
  });

  testWidgets('owing detail sheet edits amount due date and note', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Owings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Timi'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('owing_detail_sheet')), findsOneWidget);

    expect(find.byKey(const Key('edit_owing_person')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('edit_owing_person')));
    await tester.enterText(
      find.byKey(const Key('edit_owing_person')),
      'Timi A.',
    );
    await tester.enterText(find.byKey(const Key('edit_owing_amount')), '5600');
    await tester.enterText(
      find.byKey(const Key('edit_owing_due_date')),
      '2026-06-01',
    );
    await tester.enterText(
      find.byKey(const Key('edit_owing_note')),
      'Updated lunch balance',
    );
    await tester.ensureVisible(find.byKey(const Key('save_owing_edits')));
    await tester.tap(find.byKey(const Key('save_owing_edits')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('owing_detail_sheet')), findsNothing);
    expect(find.text('Timi A.'), findsOneWidget);
    expect(
      find.textContaining(MoneyFormatter.formatKobo(560000)),
      findsOneWidget,
    );
    expect(find.text('Due 2026-06-01'), findsOneWidget);

    await tester.tap(find.text('Timi A.'));
    await tester.pumpAndSettle();

    expect(find.text('Updated lunch balance'), findsWidgets);
    expect(find.text('2026-06-01'), findsWidgets);
  });

  testWidgets('owing reminder draft can be copied', (tester) async {
    final clipboardWrites = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final data = Map<Object?, Object?>.from(call.arguments as Map);
            clipboardWrites.add(data['text']! as String);
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Owings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Timi'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('draft_owing_reminder')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('copy_owing_reminder')));
    await tester.pumpAndSettle();

    expect(clipboardWrites.single, contains('Hi Timi'));
    expect(find.text('Reminder copied'), findsOneWidget);
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
    expect(find.byKey(const Key('new_gig_date')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('new_gig_date')), '2026-04-15');
    await tester.ensureVisible(find.byKey(const Key('save_new_gig')));
    await tester.tap(find.byKey(const Key('save_new_gig')));
    await tester.pumpAndSettle();

    expect(find.text('Muna Foods'), findsWidgets);
    expect(find.text('Brand kit'), findsOneWidget);
    expect(find.text('2026-04-15'), findsOneWidget);
    expect(
      find.textContaining(MoneyFormatter.formatKobo(9000000)),
      findsWidgets,
    );
  });

  testWidgets('profile gig tracker shows earnings summary and cadence nudge', (
    tester,
  ) async {
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

    expect(find.byKey(const Key('gig_summary_this_month')), findsOneWidget);
    expect(find.byKey(const Key('gig_summary_this_year')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('gig_summary_this_month')),
        matching: find.text(MoneyFormatter.formatKobo(4500000)),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('gig_summary_this_year')),
        matching: find.text(MoneyFormatter.formatKobo(4500000)),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('since your last gig'), findsOneWidget);
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

  testWidgets('bill reminders groups due soon and upcoming bills', (
    tester,
  ) async {
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

    expect(find.byKey(const Key('bill_section_due_soon')), findsOneWidget);
    expect(find.byKey(const Key('bill_section_upcoming')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('bill_section_due_soon')),
        matching: find.text('Monthly data'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('bill_section_upcoming')),
        matching: find.text('Hostel dues'),
      ),
      findsOneWidget,
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

  testWidgets('bill reminder detail edits amount frequency and due date', (
    tester,
  ) async {
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

    await tester.ensureVisible(
      find.byKey(const Key('edit_bill_amount_bill-data')),
    );
    await tester.enterText(
      find.byKey(const Key('edit_bill_amount_bill-data')),
      '12500',
    );
    await tester.enterText(
      find.byKey(const Key('edit_bill_frequency_bill-data')),
      'Weekly',
    );
    await tester.enterText(
      find.byKey(const Key('edit_bill_next_due_bill-data')),
      '2026-06-10',
    );
    await tester.ensureVisible(
      find.byKey(const Key('save_bill_edits_bill-data')),
    );
    await tester.tap(find.byKey(const Key('save_bill_edits_bill-data')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bill_detail_sheet')), findsNothing);
    expect(find.text('Weekly - 2026-06-10'), findsOneWidget);
    expect(
      find.textContaining(MoneyFormatter.formatKobo(1250000)),
      findsWidgets,
    );
  });

  testWidgets('bill reminder detail deletes a bill', (tester) async {
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

    await tester.tap(find.byKey(const Key('delete_bill_bill-data')));
    await tester.pumpAndSettle();

    expect(find.text('Monthly data'), findsNothing);
    expect(find.textContaining('reminder removed'), findsWidgets);
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
    expect(find.textContaining('kolo://app/partner/invite'), findsWidgets);

    await tester.tap(find.byKey(const Key('revoke_partner_share-1')));
    await tester.pumpAndSettle();

    expect(find.text('revoked'), findsWidgets);
  });

  testWidgets('partner sharing cards show selected summary areas', (
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

    final shareCard = find.byKey(const Key('partner_share_card_share-1'));

    expect(shareCard, findsOneWidget);
    expect(
      find.descendant(
        of: shareCard,
        matching: find.textContaining('Balance summary'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: shareCard,
        matching: find.textContaining('Budget summary'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: shareCard,
        matching: find.textContaining('Weekly insights'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('partner sharing publishes a partner-safe summary', (
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

    await tester.tap(find.byKey(const Key('publish_partner_share-1')));
    await tester.pumpAndSettle();

    expect(
      find.text('Partner-safe summary published for accountability@friend.ng'),
      findsOneWidget,
    );
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

    final kudaToggle = find.byKey(
      const Key('toggle_watched_app_com.kuda.android'),
    );
    await tester.scrollUntilVisible(
      kudaToggle,
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(tester.widget<SwitchListTile>(kudaToggle).value, isTrue);

    await tester.tap(kudaToggle);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(kudaToggle).value, isFalse);
  });

  testWidgets('watched apps sheet changes a watched app block level', (
    tester,
  ) async {
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

    final explainOption = find.byKey(
      const Key('block_level_com.kuda.android_explain'),
    );
    await tester.scrollUntilVisible(
      explainOption,
      250,
      scrollable: find.byType(Scrollable).last,
    );

    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const Key('block_level_com.kuda.android_soft')),
          )
          .selected,
      isTrue,
    );

    await tester.tap(explainOption);
    await tester.pumpAndSettle();

    expect(tester.widget<ChoiceChip>(explainOption).selected, isTrue);
    expect(find.text('Explain mode'), findsOneWidget);
    expect(find.textContaining('must type a reason'), findsOneWidget);
  });

  testWidgets('hard lock block level shows a serious-mode prompt', (
    tester,
  ) async {
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

    final hardLockOption = find.byKey(
      const Key('block_level_com.kuda.android_hardLock'),
    );
    await tester.scrollUntilVisible(
      hardLockOption,
      250,
      scrollable: find.byType(Scrollable).last,
    );

    await tester.tap(hardLockOption);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hard_lock_onboarding_sheet')), findsOneWidget);
    expect(find.text('Hard Lock is serious'), findsOneWidget);
    expect(
      find.textContaining('Kolo never truly locks you out'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('use_explain_mode_com.kuda.android')),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const Key('block_level_com.kuda.android_explain')),
          )
          .selected,
      isTrue,
    );

    await tester.tap(hardLockOption);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('confirm_hard_lock_com.kuda.android')),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<ChoiceChip>(hardLockOption).selected, isTrue);
  });

  testWidgets('watched apps sheet prompts for accessibility permission', (
    tester,
  ) async {
    const channel = MethodChannel('kolo/android_capabilities');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'openAccessibilitySettings') return true;
          if (call.method == 'isAccessibilityServiceEnabled') return true;
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

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

    expect(
      find.byKey(const Key('watched_apps_accessibility_prompt')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('enable_accessibility_from_watched_apps')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accessibility service ready'), findsOneWidget);
  });

  testWidgets('watched apps sheet searches installed app candidates', (
    tester,
  ) async {
    const channel = MethodChannel('kolo/android_capabilities');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getInstalledAppCandidates') {
            return [
              {
                'packageName': 'com.android.calculator2',
                'displayName': 'Calculator',
                'installed': true,
                'isKnownFinancialApp': false,
              },
              {
                'packageName': 'com.lenddo.mobile.paylater',
                'displayName': 'Carbon',
                'installed': true,
                'isKnownFinancialApp': true,
              },
            ];
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

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

    await tester.tap(find.byKey(const Key('refresh_watched_apps')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('watched_apps_search')),
      'carbon',
    );
    await tester.pumpAndSettle();

    expect(find.text('Carbon'), findsOneWidget);
    expect(find.text('Calculator'), findsNothing);

    await tester.tap(
      find.byKey(const Key('add_watched_app_com.lenddo.mobile.paylater')),
    );
    await tester.pumpAndSettle();

    final carbonToggle = find.byKey(
      const Key('toggle_watched_app_com.lenddo.mobile.paylater'),
    );
    expect(carbonToggle, findsOneWidget);
    expect(tester.widget<SwitchListTile>(carbonToggle).value, isFalse);
  });

  testWidgets(
    'watched apps require accessibility before enabling a new app trigger',
    (tester) async {
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

      final opayToggle = find.byKey(
        const Key('toggle_watched_app_team.opay.pay'),
      );
      expect(tester.widget<SwitchListTile>(opayToggle).value, isFalse);
      expect(tester.widget<SwitchListTile>(opayToggle).onChanged, isNull);
      expect(find.text('Grant Accessibility before enabling'), findsOneWidget);
    },
  );

  testWidgets(
    'profile refresh adds installed watched app candidates disabled',
    (tester) async {
      const channel = MethodChannel('kolo/android_capabilities');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getInstalledAppCandidates') {
              return [
                {
                  'packageName': 'com.palmpay.android',
                  'displayName': 'PalmPay',
                  'installed': true,
                  'isKnownFinancialApp': true,
                },
              ];
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

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

      const palmpayToggleKey = Key('toggle_watched_app_com.palmpay.android');
      const palmpayAddKey = Key('add_watched_app_com.palmpay.android');
      expect(find.byKey(palmpayToggleKey), findsNothing);

      await tester.tap(find.byKey(const Key('refresh_watched_apps')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('watched_apps_search')),
        'palmpay',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(palmpayAddKey), findsOneWidget);
      await tester.tap(find.byKey(palmpayAddKey));
      await tester.pumpAndSettle();

      final palmpayToggle = find.byKey(palmpayToggleKey);
      expect(palmpayToggle, findsOneWidget);
      expect(tester.widget<SwitchListTile>(palmpayToggle).value, isFalse);
    },
  );

  testWidgets('profile can grant a permission from locked state', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    const grantNotificationsKey = Key('grant_notifications');
    await tester.scrollUntilVisible(
      find.byKey(grantNotificationsKey),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(grantNotificationsKey));
    await tester.pumpAndSettle();

    expect(find.text('granted'), findsWidgets);
  });
}
