import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'FirebasePartnerRepository uses callable acceptance and safe summaries',
    () {
      final source = File(
        'lib/data/repositories/firebase_partner_repository.dart',
      ).readAsStringSync();

      expect(source, contains("httpsCallable('acceptPartnerShare')"));
      expect(source, contains("collection('partnerSummaries')"));
      expect(source, contains('PartnerSafeSummary'));
      expect(source, isNot(contains('transactions')));
    },
  );
}
