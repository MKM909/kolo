import 'dart:async';

import 'package:kolo/domain/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? initialUser}) : _currentUser = initialUser;

  AuthUser? _currentUser;
  final _controller = StreamController<AuthUser?>.broadcast();

  @override
  Stream<AuthUser?> watchAuthState() async* {
    yield _currentUser;
    yield* _controller.stream;
  }

  @override
  Future<AuthUser> createUserWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final user = AuthUser(uid: 'demo-user', email: email, displayName: name);
    _setUser(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final user = AuthUser(uid: 'demo-user', email: email, displayName: 'Kolo User');
    _setUser(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _setUser(null);
  }

  void dispose() {
    _controller.close();
  }

  void _setUser(AuthUser? user) {
    _currentUser = user;
    if (!_controller.isClosed) _controller.add(user);
  }
}
