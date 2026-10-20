class AccountIdentity {
  const AccountIdentity({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
}

abstract interface class AuthRepository {
  AccountIdentity? get currentUser;
  Stream<AccountIdentity?> authStateChanges();
  Future<AccountIdentity> signInWithGoogle();
  Future<void> signOut();
}
