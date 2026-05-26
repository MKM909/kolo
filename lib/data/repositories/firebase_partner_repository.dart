import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/partner_repository.dart';

class FirebasePartnerRepository implements PartnerRepository {
  FirebasePartnerRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Future<PartnerShare> acceptPartnerShare(PartnerInviteRef invite) async {
    final callable = _functions.httpsCallable('acceptPartnerShare');
    final response = await callable.call<Map<String, dynamic>>({
      'ownerUid': invite.ownerUid,
      'shareId': invite.shareId,
    });
    final data = Map<String, dynamic>.from(response.data);
    return PartnerShare(
      id: data['shareId'] as String? ?? invite.shareId,
      partnerEmail: data['partnerEmail'] as String? ?? '',
      status: ShareStatus.active,
      permissions: _stringSet(data['permissions']),
      createdAt: DateTime.now(),
    );
  }

  @override
  Stream<PartnerSafeSummary?> watchPartnerSummary(PartnerInviteRef invite) {
    return _firestore
        .collection('users')
        .doc(invite.ownerUid)
        .collection('partnerSummaries')
        .doc(invite.shareId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (data == null || data['status'] != 'active') return null;
          return PartnerSafeSummary(
            shareId: data['shareId'] as String? ?? invite.shareId,
            partnerEmail: data['partnerEmail'] as String? ?? '',
            generatedAt: _date(data['generatedAt']),
            permissions: _stringSet(data['permissions']),
            sections: _objectMap(data['sections']),
          );
        });
  }

  Set<String> _stringSet(Object? value) {
    if (value is Iterable) {
      return value.map((item) => item.toString()).toSet();
    }
    return const {};
  }

  Map<String, Object?> _objectMap(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): entry.value as Object?,
      };
    }
    return const {};
  }

  DateTime _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
