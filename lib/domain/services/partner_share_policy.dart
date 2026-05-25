import 'package:kolo/domain/models/models.dart';

class PartnerSharePolicy {
  PartnerSharePolicy._();

  static bool isVisible(PartnerShare share) =>
      share.status == ShareStatus.pending || share.status == ShareStatus.active;

  static List<PartnerShare> enforceSingleVisibleShare({
    required PartnerShare incoming,
    required Iterable<PartnerShare> existingShares,
    required DateTime now,
  }) {
    final shouldReplaceExisting = isVisible(incoming);
    final otherShares = existingShares
        .where((existing) => existing.id != incoming.id)
        .map(
          (existing) => shouldReplaceExisting && isVisible(existing)
              ? revoke(existing, now: now)
              : existing,
        )
        .toList(growable: false);

    return [incoming, ...otherShares];
  }

  static PartnerShare revoke(PartnerShare share, {required DateTime now}) {
    return PartnerShare(
      id: share.id,
      partnerEmail: share.partnerEmail,
      status: ShareStatus.revoked,
      permissions: share.permissions,
      createdAt: share.createdAt,
      revokedAt: now,
    );
  }
}
