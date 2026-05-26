import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/partner_summary_builder.dart';

export 'package:kolo/domain/services/partner_summary_builder.dart'
    show PartnerSafeSummary;

abstract class PartnerRepository {
  Future<PartnerShare> acceptPartnerShare(PartnerInviteRef invite);

  Stream<PartnerSafeSummary?> watchPartnerSummary(PartnerInviteRef invite);
}
