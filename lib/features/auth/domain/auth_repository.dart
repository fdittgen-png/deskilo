// SPDX-License-Identifier: 0BSD
import 'badge_sign_in.dart';
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

  // ── badge sign-in (#662) ────────────────────────────────────────────
  // Two calls, not one, because the user asked for that sequencing: the
  // scan says who, the PIN says it is really them. Both go through the
  // badge-signin Edge Function; neither ever sees a PIN hash, and the
  // second returns a one-time token the client exchanges itself, so no
  // long-lived secret crosses to a shared tablet.

  /// Step 1 — whose badge is this? Consumes no attempt: a tap is not a
  /// login attempt, and counting it as one would let anyone lock a
  /// member out by waving a card at the kiosk.
  Future<BadgeStepResult<BadgeIdentity>> identifyBadge(String uid);

  /// Step 2 — the PIN. On success the session is already live through
  /// [authStateChanges]; there is nothing for the caller to store.
  Future<BadgeStepResult<void>> signInWithBadge({
    required String uid,
    required String pin,
  });

  /// Whether the signed-in member has a PIN. Answers the settings row
  /// without the hash ever leaving the database.
  Future<bool> hasBadgePin();

  /// Sets (or replaces) the signed-in member's own PIN. Never anyone
  /// else's — the RPC refuses on the server too.
  Future<void> setBadgePin(String pin);

  /// Removes it, which also stops every badge of theirs from signing in.
  Future<void> clearBadgePin();

  /// Arms or disarms ONE badge for sign-in. Off by default: the card
  /// that checks you in does not become the card that logs you in until
  /// someone says so.
  Future<void> setBadgeAuthEnabled({
    required String badgeId,
    required bool enabled,
  });
}
