import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mnote/features/auth/data/firebase_auth_repository.dart';
import 'package:mnote/features/auth/domain/auth_exception.dart';
import 'package:mnote/features/auth/domain/auth_validators.dart';
import 'package:mnote/l10n/app_localizations_en.dart';
import 'package:mnote/l10n/app_localizations_th.dart';

void main() {
  final th = AppLocalizationsTh();
  final en = AppLocalizationsEn();

  group('AuthValidators', () {
    test('email', () {
      expect(AuthValidators.email(th, ''), isNotNull);
      expect(AuthValidators.email(th, 'abc'), isNotNull);
      expect(AuthValidators.email(th, 'a@b'), isNotNull);
      expect(AuthValidators.email(th, ' a@b.co '), isNull);
    });

    test('password requires minimum length', () {
      expect(AuthValidators.password(th, ''), isNotNull);
      expect(AuthValidators.password(th, '12345'), isNotNull);
      expect(AuthValidators.password(th, '123456'), isNull);
    });

    test('displayName and confirmPassword', () {
      expect(AuthValidators.displayName(th, '  '), isNotNull);
      expect(AuthValidators.displayName(th, 'Pet'), isNull);
      expect(AuthValidators.confirmPassword(th, '', 'abc123'), isNotNull);
      expect(AuthValidators.confirmPassword(th, 'x', 'abc123'), isNotNull);
      expect(AuthValidators.confirmPassword(th, 'abc123', 'abc123'), isNull);
    });
  });

  test('messages follow the language', () {
    expect(AuthValidators.email(th, ''), 'กรุณากรอกอีเมล');
    expect(AuthValidators.email(en, ''), 'Please enter your email');
    expect(
      AuthValidators.password(en, '123'),
      'The password must be at least 6 characters',
    );
    expect(
      AuthValidators.messageFor(en, const AuthException(AuthErrorCode.network)),
      'Cannot connect to the internet',
    );
  });

  test('configuration error has its own message', () {
    const e = AuthException(AuthErrorCode.configuration);
    expect(AuthValidators.messageFor(th, e), contains('Google'));
    expect(
      AuthValidators.messageFor(th, e),
      isNot(
        AuthValidators.messageFor(
          th,
          const AuthException(AuthErrorCode.unknown),
        ),
      ),
    );
  });

  group('FirebaseAuthRepository.mapGoogleErrorCode', () {
    test('maps Google Sign-In exception codes', () {
      expect(
        FirebaseAuthRepository.mapGoogleErrorCode(
          GoogleSignInExceptionCode.canceled,
        ),
        AuthErrorCode.cancelled,
      );
      expect(
        FirebaseAuthRepository.mapGoogleErrorCode(
          GoogleSignInExceptionCode.clientConfigurationError,
        ),
        AuthErrorCode.configuration,
      );
      expect(
        FirebaseAuthRepository.mapGoogleErrorCode(
          GoogleSignInExceptionCode.providerConfigurationError,
        ),
        AuthErrorCode.configuration,
      );
      expect(
        FirebaseAuthRepository.mapGoogleErrorCode(
          GoogleSignInExceptionCode.unknownError,
        ),
        AuthErrorCode.unknown,
      );
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
