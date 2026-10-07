class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.providerIds = const [],
    this.createdAt,
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;

  /// Firebase sign-in provider ids, e.g. `google.com` or `password`.
  final List<String> providerIds;
  final DateTime? createdAt;

  bool get usesGoogle => providerIds.contains('google.com');
  bool get usesPassword => providerIds.contains('password');
}
