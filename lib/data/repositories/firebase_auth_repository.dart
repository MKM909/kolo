import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kolo/domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    firebase_auth.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? firebase_auth.FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final firebase_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  static Future<void>? _googleInit;

  static Map<String, Object?> googleProfileMergeData({
    required String? firebaseDisplayName,
    required String? googleDisplayName,
    required String? firebaseEmail,
    required String? googleEmail,
  }) {
    final displayName = (firebaseDisplayName ?? googleDisplayName ?? '').trim();
    final email = (firebaseEmail ?? googleEmail ?? '').trim();

    return {
      'name': displayName.isEmpty ? 'Kolo User' : displayName,
      if (email.isNotEmpty) 'email': email,
    };
  }

  @override
  Stream<AuthUser?> watchAuthState() {
    return _auth.authStateChanges().map(_fromFirebaseUser);
  }

  @override
  Future<AuthUser> createUserWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase did not return a user for the new account.');
    }

    await user.updateDisplayName(name.trim());
    await _firestore.collection('users').doc(user.uid).set({
      'name': name.trim(),
      'email': email.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'onboardingComplete': false,
      'balanceKobo': 0,
    }, SetOptions(merge: true));

    return AuthUser(
      uid: user.uid,
      email: email.trim(),
      displayName: name.trim(),
    );
  }

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase did not return a user for this sign in.');
    }

    return _fromFirebaseUser(user) ??
        AuthUser(
          uid: user.uid,
          email: email.trim(),
          displayName: user.displayName,
        );
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    _googleInit ??= GoogleSignIn.instance.initialize();
    await _googleInit;

    final googleUser = await GoogleSignIn.instance.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google did not return an ID token.');
    }

    final credential = firebase_auth.GoogleAuthProvider.credential(
      idToken: idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) {
      throw StateError('Firebase did not return a user for Google sign in.');
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(
          googleProfileMergeData(
            firebaseDisplayName: user.displayName,
            googleDisplayName: googleUser.displayName,
            firebaseEmail: user.email,
            googleEmail: googleUser.email,
          ),
          SetOptions(merge: true),
        );

    return _fromFirebaseUser(user) ??
        AuthUser(
          uid: user.uid,
          email: user.email ?? googleUser.email,
          displayName: user.displayName ?? googleUser.displayName,
        );
  }

  @override
  Future<void> signOut() => _auth.signOut();

  AuthUser? _fromFirebaseUser(firebase_auth.User? user) {
    if (user == null) return null;
    return AuthUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
    );
  }
}
