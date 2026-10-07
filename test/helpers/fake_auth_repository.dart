import 'dart:async';

import 'package:mnote/features/auth/domain/auth_exception.dart';
import 'package:mnote/features/auth/domain/auth_repository.dart';
import 'package:mnote/features/auth/domain/auth_user.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.currentUser, this.error});

  @override
  AuthUser? currentUser;
  AuthException? error;
  int signInCalls = 0;
  int registerCalls = 0;
  String? lastEmail;
  String? lastDisplayName;
  String? resetEmail;

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(currentUser);

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCalls += 1;
    lastEmail = email;
    if (error != null) throw error!;
    return currentUser = AuthUser(uid: 'u1', email: email);
  }

  @override
  Future<AuthUser> registerWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    registerCalls += 1;
    lastEmail = email;
    lastDisplayName = displayName;
    if (error != null) throw error!;
    return currentUser = AuthUser(
      uid: 'u2',
      email: email,
      displayName: displayName,
    );
  }

  @override
  Future<void> sendPasswordReset(String email) async => resetEmail = email;

  @override
  Future<void> signOut() async => currentUser = null;
}
