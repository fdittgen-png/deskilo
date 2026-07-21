// SPDX-License-Identifier: 0BSD
import 'social_provider.dart';

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

  /// Emails a one-time recovery code to [email] (Supabase recovery OTP —
  /// the reset email template must render {{ .Token }}). Deliberately
  /// code-based, not link-based: nothing depends on Site URL or deep
  /// links.
  Future<void> requestPasswordReset(String email);

  /// Redeems the emailed [code] as the temporary credential and sets
  /// [newPassword]; on success the user is signed in with it.
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  });

  /// Starts the browser-based OAuth sign-in (or sign-up) with [provider].
  /// The result arrives asynchronously through [authStateChanges] once the
  /// deskilo:// callback returns to the app. Throws when the provider is
  /// not enabled on the server.
  Future<void> signInWithSocial(SocialProvider provider);

  /// The identities attached to the signed-in account (email + socials).
  Future<List<LinkedIdentity>> linkedIdentities();

  /// Attaches [provider] to the SIGNED-IN account through the same
  /// browser flow — afterwards either credential signs into this account.
  Future<void> linkSocial(SocialProvider provider);

  /// Detaches an identity. The server refuses removing the last one.
  Future<void> unlinkIdentity(LinkedIdentity identity);
}
