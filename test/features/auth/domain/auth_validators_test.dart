import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/auth/data/firebase_auth_repository.dart';
import 'package:mnote/features/auth/domain/auth_exception.dart';
import 'package:mnote/features/auth/domain/auth_validators.dart';

void main() {
  group('AuthValidators', () {
    test('email', () {
      expect(AuthValidators.email(''), isNotNull);
      expect(AuthValidators.email('abc'), isNotNull);
      expect(AuthValidators.email('a@b'), isNotNull);
      expect(AuthValidators.email(' a@b.co '), isNull);
    });

    test('password requires minimum length', () {
      expect(AuthValidators.password(''), isNotNull);
      expect(AuthValidators.password('12345'), isNotNull);
      expect(AuthValidators.password('123456'), isNull);
    });

    test('displayName and confirmPassword', () {
      expect(AuthValidators.displayName('  '), isNotNull);
      expect(AuthValidators.displayName('Pet'), isNull);
      expect(AuthValidators.confirmPassword('', 'abc123'), isNotNull);
      expect(AuthValidators.confirmPassword('x', 'abc123'), isNotNull);
      expect(AuthValidators.confirmPassword('abc123', 'abc123'), isNull);
    });
  });

  group('FirebaseAuthRepository.mapErrorCode', () {
    test('maps known Firebase codes', () {
      expect(
        FirebaseAuthRepository.mapErrorCode('email-already-in-use'),
        AuthErrorCode.emailAlreadyInUse,
      );
      expect(
        FirebaseAuthRepository.mapErrorCode('invalid-credential'),
        AuthErrorCode.wrongCredentials,
      );
      expect(
        FirebaseAuthRepository.mapErrorCode('weak-password'),
        AuthErrorCode.weakPassword,
      );
      expect(
        FirebaseAuthRepository.mapErrorCode('whatever'),
        AuthErrorCode.unknown,
      );
    });
  });
}
