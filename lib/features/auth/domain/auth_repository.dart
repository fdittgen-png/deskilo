// SPDX-License-Identifier: AGPL-3.0-or-later
import 'auth_outcome.dart';
import 'badge_sign_in.dart';
import 'social_provider.dart';

/// Pure-Dart auth boundary (spec §2). Implemented by Supabase in data/,
/// faked in tests — presentation never sees supabase_flutter types.
abstract class AuthRepository {
  /// Emits the signed-in user id, or null when signed out. Emits the
  /// current state to new listeners immediately.
  Stream<String?> authStateChanges();

  String? get currentUserId;

  /// [AuthOutcome.authenticated], or why not. Never throws for an
  /// answer the server gave — a refusal is a value, not an exception
  /// (#1649).
  Future<AuthResult> signInWithPassword({
    required String email,
    required String password,
  });

  /// [AuthOutcome.authenticated] when the server issued a session on the
  /// spot, [AuthOutcome.verificationRequired] when it sent an e-mail
  /// instead. The response used to be discarded, which left the screen
  /// unable to tell the two apart (#1649).
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  /// Sends the sign-up confirmation e-mail again through the resend
  /// endpoint — never a second sign-up. [AuthOutcome.verificationRequired]
  /// when it went out; [AuthOutcome.rateLimited] with the server's wait
  /// when it was too soon.
  Future<AuthResult> resendSignUpVerification(String email);

  Future<void> signOut();

  /// Emails a one-time recovery code to [email] (Supabase recovery OTP —
  /// the reset email template must render {{ .Token }}). Deliberately
  /// code-based, not link-based: nothing depends on Site URL or deep
  /// links.
  ///
  /// [AuthOutcome.recoveryVerificationRequired] when the code went out.
  Future<AuthResult> requestPasswordReset(String email);

  /// Redeems the emailed [code] as the temporary credential and sets
  /// [newPassword]. [AuthOutcome.completed] only once the update itself
  /// succeeded. A code accepted before an update that failed is
  /// [AuthOutcome.recoverySessionReadyButPasswordNotUpdated]: the code is
  /// spent, the session it opened is held back from [authStateChanges]
  /// until the update lands, and the way forward is
  /// [updateRecoveredPassword], never the code again.
  Future<AuthResult> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  });

  /// Retries the password update on the session a redeemed recovery
  /// code opened. [AuthOutcome.completed] releases the session to
  /// [authStateChanges]; [AuthOutcome.recoveryVerificationRequired] means
  /// that session is gone and a new code is the only way.
  Future<AuthResult> updateRecoveredPassword(String newPassword);

  /// Ends a recovery session whose password was never updated — this
  /// device's session only, never the person's other sessions. A no-op
  /// when no such session exists, so a sheet may always call it on the
  /// way out.
  Future<void> cancelPasswordRecovery();

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
