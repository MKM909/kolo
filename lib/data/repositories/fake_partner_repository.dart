import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/partner_repository.dart';

class FakePartnerRepository implements PartnerRepository {
  PartnerInviteRef? _acceptedInvite;

  @override
  Future<PartnerShare> acceptPartnerShare(PartnerInviteRef invite) async {
    _acceptedInvite = invite;
    return PartnerShare(
      id: invite.shareId,
      partnerEmail: 'partner@example.com',
      status: ShareStatus.active,
      permissions: const {'balance_summary', 'budget_summary'},
      createdAt: DateTime.now(),
    );
  }

  @override
  Stream<PartnerSafeSummary?> watchPartnerSummary(PartnerInviteRef invite) {
    final accepted = _acceptedInvite == invite;
    if (!accepted) {
      return Stream<PartnerSafeSummary?>.value(null);
    }
    return Stream<PartnerSafeSummary?>.value(
      PartnerSafeSummary(
        shareId: invite.shareId,
        partnerEmail: 'partner@example.com',
        generatedAt: DateTime.now(),
        permissions: const {'balance_summary', 'budget_summary'},
        sections: const {
          'balance_summary': {
            'balanceKobo': 5080000,
            'totalIncomeKobo': 7000000,
            'totalExpenseKobo': 1920000,
            'totalSavingsKobo': 850000,
          },
          'budget_summary': {
            'totalBudgetKobo': 5000000,
            'categories': [
              {
                'name': 'Food & Snacks',
                'allocatedKobo': 1500000,
                'spentKobo': 820000,
              },
            ],
          },
        },
      ),
    );
  }
}
