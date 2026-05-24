import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/repositories/firebase_auth_repository.dart';

void main() {
  test('Google sign-in profile merge does not reset onboarding data', () {
    final payload = FirebaseAuthRepository.googleProfileMergeData(
      firebaseDisplayName: 'Returning User',
      googleDisplayName: 'Google Name',
      firebaseEmail: 'returning@kolo.app',
      googleEmail: 'google@kolo.app',
    );

    expect(payload['name'], 'Returning User');
    expect(payload['email'], 'returning@kolo.app');
    expect(payload, isNot(contains('onboardingComplete')));
    expect(payload, isNot(contains('balanceKobo')));
    expect(payload, isNot(contains('createdAt')));
  });
}
