import 'package:kolo/domain/repositories/kolo_repository.dart';

typedef FakeRepositoryBuilder = KoloRepository Function();
typedef FirebaseRepositoryBuilder = KoloRepository Function(String uid);

class KoloRepositorySelector {
  const KoloRepositorySelector._();

  static KoloRepository select({
    required bool firebaseInitialized,
    required String? firebaseUid,
    required FakeRepositoryBuilder fakeBuilder,
    required FirebaseRepositoryBuilder firebaseBuilder,
  }) {
    if (firebaseInitialized && firebaseUid != null && firebaseUid.isNotEmpty) {
      return firebaseBuilder(firebaseUid);
    }
    return fakeBuilder();
  }
}
