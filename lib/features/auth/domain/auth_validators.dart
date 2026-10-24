import 'package:mnote/features/auth/domain/auth_exception.dart';
import 'package:mnote/l10n/app_localizations.dart';

class AuthValidators {
  const AuthValidators._();

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const minPasswordLength = 6;

  static String? email(AppLocalizations l, String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return l.enterEmail;
    if (!_emailPattern.hasMatch(v)) return l.invalidEmail;
    return null;
  }

  static String? password(AppLocalizations l, String? value) {
    final v = value ?? '';
    if (v.isEmpty) return l.enterPassword;
    if (v.length < minPasswordLength) {
      return l.passwordTooShort(minPasswordLength);
    }
    return null;
  }

  static String? displayName(AppLocalizations l, String? value) {
    if ((value?.trim() ?? '').isEmpty) return l.enterName;
    return null;
  }

  static String? confirmPassword(
    AppLocalizations l,
    String? value,
    String password,
  ) {
    if ((value ?? '').isEmpty) return l.enterConfirmPassword;
    if (value != password) return l.passwordMismatch;
    return null;
  }

  static String messageFor(AppLocalizations l, AuthException e) {
    switch (e.code) {
      case AuthErrorCode.invalidEmail:
        return l.invalidEmail;
      case AuthErrorCode.wrongCredentials:
      case AuthErrorCode.userNotFound:
        return l.errWrongCredentials;
      case AuthErrorCode.userDisabled:
        return l.errUserDisabled;
      case AuthErrorCode.emailAlreadyInUse:
        return l.errEmailInUse;
      case AuthErrorCode.weakPassword:
        return l.errWeakPassword;
      case AuthErrorCode.tooManyRequests:
        return l.errTooManyRequests;
      case AuthErrorCode.network:
        return l.errNetwork;
      case AuthErrorCode.cancelled:
        return l.errCancelled;
      case AuthErrorCode.configuration:
        return l.errGoogleConfig;
      case AuthErrorCode.unknown:
        return l.errUnknown;
    }
  }
}
