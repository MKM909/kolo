class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.emailVerified = true,
  });

  final String uid;
  final String email;
  final String? displayName;
  final bool emailVerified;

  AuthUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    bool? emailVerified,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }
}

abstract class AuthRepository {
  Stream<AuthUser?> watchAuthState();

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthUser> createUserWithEmail({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthUser> signInWithGoogle();

  Future<void> sendEmailVerification();

  Future<AuthUser?> reloadCurrentUser();

  Future<void> signOut();
}
