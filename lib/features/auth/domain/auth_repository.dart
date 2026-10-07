import 'package:mnote/features/auth/domain/auth_user.dart';

abstract class AuthRepository {
  /// The signed-in user restored from a previous session, if any.
  AuthUser? get currentUser;

  Stream<AuthUser?> authStateChanges();

  /// Throws [AuthException] on failure.
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  });

  /// Creates the account and its profile document. Throws [AuthException].
  Future<AuthUser> registerWithEmail({
    required String displayName,
    required String email,
    required String password,
  });

  /// Signs in (or signs up) with a Google account. Throws [AuthException]
  /// with [AuthErrorCode.cancelled] if the user dismisses the Google flow.
  Future<AuthUser> signInWithGoogle();

  /// Updates the signed-in user's display name and returns the new user.
  Future<AuthUser> updateDisplayName(String displayName);

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}
