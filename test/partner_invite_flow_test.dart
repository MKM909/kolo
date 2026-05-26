import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/app/router.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/partner_repository.dart';

void main() {
  testWidgets('partner invite accepts and opens partner-safe dashboard', (
    tester,
  ) async {
    final repository = _FakePartnerRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [partnerRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(
          routerConfig: buildKoloRouter(
            firebaseInitialized: false,
            signedIn: false,
            initialLocation: '/partner/invite?ownerUid=owner-1&shareId=share-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('partner_invite_screen')), findsOneWidget);
    expect(find.text('Review Kolo invite'), findsOneWidget);

    await tester.tap(find.byKey(const Key('accept_partner_invite')));
    await tester.pumpAndSettle();

    expect(
      repository.acceptedInvite,
      const PartnerInviteRef(ownerUid: 'owner-1', shareId: 'share-1'),
    );
    expect(find.byKey(const Key('partner_dashboard_screen')), findsOneWidget);
    expect(find.text('Partner Dashboard'), findsOneWidget);
    expect(find.text('Balance summary'), findsOneWidget);
    expect(find.text('₦50,000.00'), findsOneWidget);
    expect(find.textContaining('Chicken Republic'), findsNothing);
  });
}

class _FakePartnerRepository implements PartnerRepository {
  PartnerInviteRef? acceptedInvite;

  @override
  Future<PartnerShare> acceptPartnerShare(PartnerInviteRef invite) async {
    acceptedInvite = invite;
    return PartnerShare(
      id: invite.shareId,
      partnerEmail: 'partner@example.com',
      status: ShareStatus.active,
      permissions: const {'balance_summary', 'budget_summary'},
      createdAt: DateTime(2026, 5, 26),
    );
  }

  @override
  Stream<PartnerSafeSummary?> watchPartnerSummary(PartnerInviteRef invite) {
    return Stream.value(
      PartnerSafeSummary(
        shareId: invite.shareId,
        partnerEmail: 'partner@example.com',
        generatedAt: DateTime(2026, 5, 26),
        permissions: const {'balance_summary', 'budget_summary'},
        sections: const {
          'balance_summary': {
            'balanceKobo': 5000000,
            'totalIncomeKobo': 7000000,
            'totalExpenseKobo': 2000000,
            'totalSavingsKobo': 1000000,
          },
          'budget_summary': {
            'totalBudgetKobo': 4500000,
            'categories': [
              {
                'name': 'Food & Snacks',
                'allocatedKobo': 1500000,
                'spentKobo': 800000,
              },
            ],
          },
        },
      ),
    );
  }
}
