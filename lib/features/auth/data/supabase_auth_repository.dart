// SPDX-License-Identifier: 0BSD

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_repository.dart';
import '../domain/badge_sign_in.dart';
import '../domain/social_provider.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<String?> authStateChanges() async* {
    yield _client.auth.currentUser?.id;
    yield* _client.auth.onAuthStateChange
        .map((event) => event.session?.user.id);
  }

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> requestPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(email);

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    // The code substitutes the password exactly once (recovery OTP);
    // redeeming it yields a session, which immediately sets the new one.
    await _client.auth.verifyOTP(
      type: OtpType.recovery,
      email: email,
      token: code.trim(),
    );
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Brand → Supabase provider.
  static OAuthProvider _oauth(SocialProvider provider) => switch (provider) {
        SocialProvider.google => OAuthProvider.google,
      };

  /// Where the provider sends the browser back to.
  ///
  /// Every NATIVE platform returns over the deskilo:// scheme, registered
  /// in the Android manifest, the iOS and macOS Info.plists and (via the
  /// MSI) the Windows registry. On the WEB the app is the page, so the
  /// callback goes to the page's own address.
  ///
  /// It used to be null off mobile, which let Supabase fall back to the
  /// project's Site URL — `http://localhost:3000`, a server that exists on
  /// nobody's machine. The sign-in ended on "Safari cannot connect".
  ///
  /// Every value here must also be listed under Authentication → URL
  /// Configuration → Redirect URLs in the Supabase project, or the
  /// provider refuses the redirect.
  static String get _redirect => kIsWeb
      // Origin + path, so a deploy under /deskilo/ returns to /deskilo/
      // rather than to the domain root.
      ? '${Uri.base.origin}${Uri.base.path}'
      : 'deskilo://auth-callback';

  @override
  Future<void> signInWithSocial(SocialProvider provider) async {
    await _client.auth.signInWithOAuth(
      _oauth(provider),
      redirectTo: _redirect,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  @override
  Future<List<LinkedIdentity>> linkedIdentities() async {
    final identities = await _client.auth.getUserIdentities();
    return [
      for (final i in identities)
        (id: i.identityId, provider: i.provider),
    ];
  }

  @override
  Future<void> linkSocial(SocialProvider provider) async {
    await _client.auth.linkIdentity(
      _oauth(provider),
      redirectTo: _redirect,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  @override
  Future<void> unlinkIdentity(LinkedIdentity identity) async {
    final identities = await _client.auth.getUserIdentities();
    final match = identities
        .where((i) => i.identityId == identity.id)
        .firstOrNull;
    if (match == null) return;
    await _client.auth.unlinkIdentity(match);
  }

  // ── badge sign-in (#662) ────────────────────────────────────────────

  /// Both steps hit the same function; only the body differs. A missing
  /// deployment (404) and a dead network are the SAME answer to the
  /// caller — `unavailable` — because in both cases nothing about the
  /// badge was judged, and showing "wrong PIN" would send someone
  /// hunting for a mistake they did not make.
  Future<Map<String, dynamic>?> _invokeBadge(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke(
        'badge-signin',
        body: body,
      );
      final data = response.data;
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } on FunctionException catch (e, st) {
      // A refusal comes back as 200 with ok:false, so ANY exception here
      // is infrastructure, not judgement.
      // trace-exempt: the status is the whole diagnosis and it is
      // reported to the caller as `unavailable`.
      if (e.status == 404) return null;
      Error.throwWithStackTrace(e, st);
    }
  }

  /// The failure the function named, defaulting to the safe one. An
  /// unrecognised reason must read as `refused`, never as success.
  BadgeSignInFailure _failureOf(Map<String, dynamic> data) =>
      data['reason'] == 'locked'
          ? BadgeSignInFailure.locked
          : BadgeSignInFailure.refused;

  @override
  Future<BadgeStepResult<BadgeIdentity>> identifyBadge(String uid) async {
    final data = await _invokeBadge({'uid': uid});
    if (data == null) {
      return const BadgeStepResult.failed(BadgeSignInFailure.unavailable);
    }
    if (data['ok'] != true) return BadgeStepResult.failed(_failureOf(data));
    return BadgeStepResult.ok(BadgeIdentity(
      userId: data['user_id']?.toString() ?? '',
      displayName: data['display_name']?.toString() ?? '',
      hasAvatar: data['has_avatar'] == true,
    ));
  }

  @override
  Future<BadgeStepResult<void>> signInWithBadge({
    required String uid,
    required String pin,
  }) async {
    final data = await _invokeBadge({'uid': uid, 'pin': pin});
    if (data == null) {
      return const BadgeStepResult.failed(BadgeSignInFailure.unavailable);
    }
    if (data['ok'] != true) return BadgeStepResult.failed(_failureOf(data));
    final tokenHash = data['token_hash']?.toString();
    if (tokenHash == null || tokenHash.isEmpty) {
      return const BadgeStepResult.failed(BadgeSignInFailure.unavailable);
    }
    // The session is minted by GoTrue from a one-time hash, so the
    // tablet never holds a reusable credential. authStateChanges fires
    // on its own; the caller has nothing to store.
    await _client.auth
        .verifyOTP(type: OtpType.magiclink, tokenHash: tokenHash);
    return const BadgeStepResult.ok(null);
  }

  @override
  Future<bool> hasBadgePin() async =>
      await _client.rpc<dynamic>('has_badge_pin') == true;

  @override
  Future<void> setBadgePin(String pin) =>
      _client.rpc<void>('set_badge_pin', params: {'p_pin': pin});

  @override
  Future<void> clearBadgePin() => _client.rpc<void>('clear_badge_pin');

  @override
  Future<void> setBadgeAuthEnabled({
    required String badgeId,
    required bool enabled,
  }) =>
      _client.rpc<void>('set_badge_auth_enabled', params: {
        'p_badge_id': badgeId,
        'p_enabled': enabled,
      });
}
