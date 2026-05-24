import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/domain/services/money_formatter.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/core/widgets/domain_widgets.dart';

void main() {
  testWidgets('balance card renders negative balances as urgent red', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KoloTheme.light,
        home: const Scaffold(
          body: BalanceCard(balanceKobo: -125000, name: 'Micah'),
        ),
      ),
    );

    final amount = tester.widget<Text>(
      find.text(MoneyFormatter.formatKobo(-125000)),
    );

    expect(amount.style?.color, KoloColors.expense);
    expect(find.byKey(const Key('balance_negative_warning')), findsOneWidget);
  });
}
