import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:mnote/features/auth/domain/auth_exception.dart';
import 'package:mnote/features/auth/domain/auth_repository.dart';
import 'package:mnote/features/auth/domain/auth_user.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({fb.FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? fb.FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AuthUser?> authStateChanges() => _auth.authStateChanges().map(_map);

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = _map(credential.user);
      if (user == null) throw const AuthException(AuthErrorCode.unknown);
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(mapErrorCode(e.code), e.message);
    }
  }

  @override
  Future<AuthUser> registerWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthException(AuthErrorCode.unknown);
      }

      final name = displayName.trim();
      await firebaseUser.updateDisplayName(name);
      await _users.doc(firebaseUser.uid).set({
        'displayName': name,
        'email': firebaseUser.email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return AuthUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? email.trim(),
        displayName: name,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(mapErrorCode(e.code), e.message);
    } on FirebaseException catch (e) {
      throw AuthException(AuthErrorCode.unknown, e.message);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(mapErrorCode(e.code), e.message);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  static AuthUser? _map(fb.User? user) {
    if (user == null) return null;
    return AuthUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
    );
  }

  static AuthErrorCode mapErrorCode(String code) {
    switch (code) {
      case 'invalid-email':
        return AuthErrorCode.invalidEmail;
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return AuthErrorCode.wrongCredentials;
      case 'user-not-found':
        return AuthErrorCode.userNotFound;
      case 'user-disabled':
        return AuthErrorCode.userDisabled;
      case 'email-already-in-use':
        return AuthErrorCode.emailAlreadyInUse;
      case 'weak-password':
        return AuthErrorCode.weakPassword;
      case 'too-many-requests':
        return AuthErrorCode.tooManyRequests;
      case 'network-request-failed':
        return AuthErrorCode.network;
      default:
        return AuthErrorCode.unknown;
    }
  }
}
