import 'package:firebase_core/firebase_core.dart';
import 'package:kolo/firebase_options.dart';

class FirebaseBootstrapResult {
  const FirebaseBootstrapResult({required this.initialized, this.error});

  final bool initialized;
  final Object? error;
}

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<FirebaseBootstrapResult> tryInitialize() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        return const FirebaseBootstrapResult(initialized: true);
      }
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return const FirebaseBootstrapResult(initialized: true);
    } on Object catch (error) {
      return FirebaseBootstrapResult(initialized: false, error: error);
    }
  }
}
