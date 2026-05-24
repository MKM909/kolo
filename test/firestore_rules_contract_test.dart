import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('partner shares can be read by the invited partner email', () {
    final rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('partnerEmail'));
    expect(rules, contains('request.auth.token.email'));
    expect(
      rules,
      contains('resource.data.partnerEmail == request.auth.token.email'),
    );
  });
}
