import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/user_repository.dart';

class SupabaseAuthRepository implements UserRepository {
  final SupabaseClient _supabase;

  SupabaseAuthRepository(this._supabase);

  @override
  Future<void> signIn(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signUp(String email, String password, {String? name}) async {
    await _supabase.auth.signUp(
      email: email,
      password: password,
      data: name != null && name.isNotEmpty ? {'full_name': name} : null,
    );
  }

  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  @override
  Stream<String?> get authStateChanges {
    return _supabase.auth.onAuthStateChange.map((event) {
      return event.session?.user.id;
    });
  }

  @override
  String? get currentUserEmail => _supabase.auth.currentUser?.email;
}
