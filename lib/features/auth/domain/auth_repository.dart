// SPDX-License-Identifier: MIT

/// Pure-Dart auth boundary (spec §2). Implemented by Supabase in data/,
/// faked in tests — presentation never sees supabase_flutter types.
abstract class AuthRepository {
  /// Emits the signed-in user id, or null when signed out. Emits the
  /// current state to new listeners immediately.
  Stream<String?> authStateChanges();

  String? get currentUserId;

  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signOut();
}
