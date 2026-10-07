class AuthUser {
  const AuthUser({required this.uid, required this.email, this.displayName});

  final String uid;
  final String email;
  final String? displayName;
}
