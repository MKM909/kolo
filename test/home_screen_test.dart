import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/features/home/home_screen.dart';

void main() {
  testWidgets('home shows a friendly offline state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(
            (ref) => Stream<DashboardState>.error(StateError('offline')),
          ),
        ],
        child: MaterialApp(theme: KoloTheme.light, home: const HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_offline_state')), findsOneWidget);
    expect(find.text('Kolo is offline'), findsOneWidget);
    expect(find.textContaining('local cache'), findsOneWidget);
    expect(find.textContaining('StateError'), findsNothing);
  });
}
