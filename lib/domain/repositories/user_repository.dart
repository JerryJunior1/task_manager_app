abstract class UserRepository {
  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password, {String? name});
  Future<void> signOut();
  Stream<String?> get authStateChanges;
  String? get currentUserEmail;
}
