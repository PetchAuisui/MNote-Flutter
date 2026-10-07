enum AuthErrorCode {
  invalidEmail,
  wrongCredentials,
  userNotFound,
  userDisabled,
  emailAlreadyInUse,
  weakPassword,
  tooManyRequests,
  network,
  cancelled,
  unknown,
}

class AuthException implements Exception {
  const AuthException(this.code, [this.message]);

  final AuthErrorCode code;
  final String? message;

  @override
  String toString() => 'AuthException($code, $message)';
}
