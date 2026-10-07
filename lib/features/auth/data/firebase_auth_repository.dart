import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mnote/features/auth/domain/auth_exception.dart';
import 'package:mnote/features/auth/domain/auth_repository.dart';
import 'package:mnote/features/auth/domain/auth_user.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({fb.FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? fb.FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  static const _webClientId =
      '544925751012-6evn9vorijcoem83vjma04g7t8udfa0i.apps.googleusercontent.com';
  static bool _googleInitialized = false;

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
  Future<AuthUser> signInWithGoogle() async {
    try {
      final credential = kIsWeb
          ? await _auth.signInWithPopup(fb.GoogleAuthProvider())
          : await _auth.signInWithCredential(await _nativeGoogleCredential());
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthException(AuthErrorCode.unknown);
      }

      if (credential.additionalUserInfo?.isNewUser ?? false) {
        try {
          await _users.doc(firebaseUser.uid).set({
            'displayName': firebaseUser.displayName,
            'email': firebaseUser.email,
            'photoUrl': firebaseUser.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } on FirebaseException catch (e) {
          // The user is already signed in; a failed profile write must not
          // surface as a sign-in failure.
          debugPrint('Profile write failed: ${e.code} ${e.message}');
        }
      }
      return _map(firebaseUser)!;
    } on fb.FirebaseAuthException catch (e) {
      debugPrint('Google sign-in failed: ${e.code} ${e.message}');
      throw AuthException(mapErrorCode(e.code), e.message);
    } on GoogleSignInException catch (e) {
      debugPrint('Google sign-in failed: ${e.code} ${e.description}');
      throw AuthException(
        e.code == GoogleSignInExceptionCode.canceled
            ? AuthErrorCode.cancelled
            : AuthErrorCode.unknown,
        e.description,
      );
    } on FirebaseException catch (e) {
      debugPrint('Google sign-in failed: ${e.code} ${e.message}');
      throw AuthException(AuthErrorCode.unknown, e.message);
    }
  }

  Future<fb.OAuthCredential> _nativeGoogleCredential() async {
    final signIn = GoogleSignIn.instance;
    if (!_googleInitialized) {
      // iOS/macOS read the client ID from Info.plist; Android needs the
      // web (type 3) client ID to obtain an ID token.
      await signIn.initialize(serverClientId: _webClientId);
      _googleInitialized = true;
    }
    final account = await signIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) throw const AuthException(AuthErrorCode.unknown);
    return fb.GoogleAuthProvider.credential(idToken: idToken);
  }

  @override
  Future<AuthUser> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException(AuthErrorCode.unknown);
    final name = displayName.trim();
    try {
      await user.updateDisplayName(name);
      await user.reload();
      await _users.doc(user.uid).set({
        'displayName': name,
      }, SetOptions(merge: true));
      return _map(_auth.currentUser)!;
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
      photoUrl: user.photoURL,
      providerIds: [for (final info in user.providerData) info.providerId],
      createdAt: user.metadata.creationTime,
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
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
      case 'canceled':
      case 'web-context-canceled':
        return AuthErrorCode.cancelled;
      case 'network-request-failed':
        return AuthErrorCode.network;
      default:
        return AuthErrorCode.unknown;
    }
  }
}
