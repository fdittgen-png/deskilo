// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/auth_outcome.dart';
import '../domain/auth_repository.dart';
import '../domain/badge_sign_in.dart';
import '../domain/social_provider.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  /// #1649 — a redeemed recovery code opens a session BEFORE the new
  /// password is set. Until it is, that session is for one purpose, so
  /// it is held back from [authStateChanges] and [currentUserId]: the
  /// router does not leave the sign-in screen on a password that was
  /// never updated. Released when the update lands or the session is
  /// found gone, or ended by [cancelPasswordRecovery].
  bool _recoveryPending = false;
  final _recoveryChanges = StreamController<void>.broadcast();

  String? _visible(String? id) => _recoveryPending ? null : id;

  void _endRecovery() {
    _recoveryPending = false;
    _recoveryChanges.add(null);
  }

  @override
  Stream<String?> authStateChanges() {
    StreamSubscription<void>? events;
    StreamSubscription<void>? gate;
    late final StreamController<String?> out;
    out = StreamController<String?>(
      onListen: () {
        out.add(_visible(_client.auth.currentUser?.id));
        events = _client.auth.onAuthStateChange
            .listen((e) => out.add(_visible(e.session?.user.id)));
        gate = _recoveryChanges.stream
            .listen((_) => out.add(_visible(_client.auth.currentUser?.id)));
      },
      onCancel: () async {
        await events?.cancel();
        await gate?.cancel();
      },
    );
    return out.stream;
  }

  @override
  String? get currentUserId => _visible(_client.auth.currentUser?.id);

  @override
  Future<AuthResult> signInWithPassword({
    required String email,
    required String password,
  }) =>
      _outcome('sign-in', () async {
        final response = await _client.auth
            .signInWithPassword(email: email, password: password);
        return response.session == null
            // Not a shape gotrue produces for a password sign-in; if it
            // ever does, nothing was granted, and saying so is safer than
            // reading a missing session as a refusal of the credentials.
            ? const AuthResult.unavailable(trace: 'no_session')
            : const AuthResult.authenticated();
      });

  @override
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) =>
      _outcome('sign-up', () async {
        final response = await _client.auth.signUp(
          email: email,
          password: password,
          data: {'display_name': displayName},
          // Without this the confirmation link carries the project's Site
          // URL, which on an instance predating the wizard is still
          // `http://localhost:3000` — nobody's server. #1050.
          emailRedirectTo: _redirect,
        );
        // A session means the server auto-confirmed. No session means an
        // e-mail went out — to a new account, or to an existing one the
        // server is protecting by answering exactly the same way (an
        // obfuscated user with no identities). Both are the same next
        // step for the person, so both are the same outcome here.
        return response.session == null
            ? const AuthResult.verificationRequired()
            : const AuthResult.authenticated();
      });

  @override
  Future<AuthResult> resendSignUpVerification(String email) =>
      _outcome('resend', () async {
        await _client.auth.resend(
          type: OtpType.signup,
          email: email,
          emailRedirectTo: _redirect,
        );
        return const AuthResult.verificationRequired();
      });

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<AuthResult> requestPasswordReset(String email) =>
      _outcome('recovery request', () async {
        await _client.auth.resetPasswordForEmail(email);
        return const AuthResult.recoveryVerificationRequired();
      });

  @override
  Future<AuthResult> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    // The code substitutes the password exactly once (recovery OTP);
    // redeeming it yields a session, which then sets the new one. The
    // session stays out of sight until it has.
    _recoveryPending = true;
    final verified = await _outcome(
      'recovery verify',
      () async {
        await _client.auth.verifyOTP(
          type: OtpType.recovery,
          email: email,
          token: code.trim(),
        );
        return const AuthResult.completed();
      },
      unnamedRefusal: AuthRefusal.codeInvalid,
    );
    if (verified.outcome != AuthOutcome.completed) {
      _endRecovery();
      return verified;
    }
    return updateRecoveredPassword(newPassword);
  }

  @override
  Future<AuthResult> updateRecoveredPassword(String newPassword) async {
    final result = await _outcome(
      'recovery update',
      () async {
        await _client.auth.updateUser(UserAttributes(password: newPassword));
        return const AuthResult.completed();
      },
      afterSpentCode: true,
    );
    // Landed: the session may be seen. Gone: nothing left to hide. Not
    // updated, or deferred: still held back, for the retry.
    if (result.outcome == AuthOutcome.completed ||
        result.outcome == AuthOutcome.recoveryVerificationRequired) {
      _endRecovery();
    }
    return result;
  }

  @override
  Future<void> cancelPasswordRecovery() async {
    if (!_recoveryPending) return;
    _recoveryPending = false;
    try {
      // Local scope: this device's recovery session and nothing else —
      // the person's other sessions were never part of this.
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (e, st) {
      // The local session is already dropped before the server is told;
      // a server that could not be told is a trace line, not a state.
      TraceLogger.instance.warn(
        'auth',
        'recovery session cleanup did not reach the server',
        error: e,
        stackTrace: st,
      );
    }
    _recoveryChanges.add(null);
  }

  /// Runs one auth call and turns whatever it threw into an [AuthResult].
  ///
  /// [unnamedRefusal] is what a refusal the server left uncoded means in
  /// this operation: wrong credentials on a sign-in, a bad code on a
  /// verify. [afterSpentCode] marks the password update that follows a
  /// redeemed recovery code: a failure there is NOT a bad code — the
  /// code is gone and the session is live — so it answers
  /// [AuthOutcome.recoverySessionReadyButPasswordNotUpdated] for anything
  /// but a lost session or a rate limit.
  Future<AuthResult> _outcome(
    String what,
    Future<AuthResult> Function() call, {
    AuthRefusal unnamedRefusal = AuthRefusal.credentials,
    bool afterSpentCode = false,
  }) async {
    try {
      return await call();
    } catch (e, st) {
      var result = _resultOf(e, unnamedRefusal);
      if (afterSpentCode &&
          e is! AuthSessionMissingException &&
          result.outcome != AuthOutcome.rateLimited) {
        result = AuthResult.recoverySessionReadyButPasswordNotUpdated(
          trace: result.trace,
        );
      }
      // The code, never the message: gotrue's wording can quote the
      // address or the token that was typed.
      TraceLogger.instance.warn(
        'auth',
        '$what → ${result.outcome.name} (${result.trace ?? '-'})',
        stackTrace: st,
      );
      return result;
    }
  }

  /// gotrue's coded refusals → ours, pinned to the SDK's own [ErrorCode]
  /// constants. A code absent here reads as the operation's unnamed
  /// refusal: it must never pass for success, and must not invent a
  /// distinction the server did not make.
  static final Map<String, AuthRefusal> _refusalByCode = {
    ErrorCode.emailNotConfirmed.code: AuthRefusal.emailNotConfirmed,
    ErrorCode.signupDisabled.code: AuthRefusal.providerDisabled,
    ErrorCode.emailProviderDisabled.code: AuthRefusal.providerDisabled,
    ErrorCode.providerDisabled.code: AuthRefusal.providerDisabled,
    ErrorCode.otpDisabled.code: AuthRefusal.providerDisabled,
    ErrorCode.userAlreadyExists.code: AuthRefusal.alreadyRegistered,
    ErrorCode.emailExists.code: AuthRefusal.alreadyRegistered,
    ErrorCode.otpExpired.code: AuthRefusal.codeInvalid,
    ErrorCode.badCodeVerifier.code: AuthRefusal.codeInvalid,
    ErrorCode.flowStateNotFound.code: AuthRefusal.codeInvalid,
    ErrorCode.flowStateExpired.code: AuthRefusal.codeInvalid,
    ErrorCode.weakPassword.code: AuthRefusal.weakPassword,
  };

  /// The outcome an SDK exception stands for.
  static AuthResult _resultOf(Object e, AuthRefusal unnamed) {
    if (e is AuthWeakPasswordException) {
      return AuthResult.refused(
        AuthRefusal.weakPassword,
        trace: ErrorCode.weakPassword.code,
      );
    }
    if (e is AuthRetryableFetchException) {
      return AuthResult.unavailable(trace: e.statusCode ?? 'network');
    }
    if (e is AuthSessionMissingException) {
      // The recovery session is gone; only a new code opens another.
      return const AuthResult.recoveryVerificationRequired();
    }
    if (e is AuthApiException) {
      final code = e.code;
      if (e.statusCode == '429' ||
          code == ErrorCode.overEmailSendRateLimit.code ||
          code == ErrorCode.overRequestRateLimit.code) {
        return AuthResult.rateLimited(
          retryAfter: _retryAfterIn(e.message),
          trace: code ?? '429',
        );
      }
      return AuthResult.refused(
        _refusalByCode[code] ?? unnamed,
        trace: code ?? e.statusCode,
      );
    }
    if (e is AuthException) {
      return AuthResult.refused(unnamed, trace: e.statusCode ?? 'auth');
    }
    return AuthResult.unavailable(trace: e.runtimeType.toString());
  }

  /// gotrue names its e-mail cooldown only in prose — "For security
  /// purposes, you can only request this after 47 seconds." A number
  /// found there is the server's own wait; none found is no claim.
  static Duration? _retryAfterIn(String message) {
    final seconds = RegExp(r'after (\d+) seconds').firstMatch(message);
    return seconds == null ? null : Duration(seconds: int.parse(seconds[1]!));
  }

  /// Brand → Supabase provider.
  static OAuthProvider _oauth(SocialProvider provider) => switch (provider) {
        SocialProvider.google => OAuthProvider.google,
      };

  /// Where a sign-in sends the person back to: the provider's callback,
  /// and the link in the confirmation e-mail.
  ///
  /// Every NATIVE platform returns over the deskilo:// scheme, registered
  /// in the Android manifest, the iOS and macOS Info.plists and (via the
  /// MSI) the Windows registry. On the WEB the app is the page, so the
  /// callback goes to the page's own address.
  ///
  /// It used to be null off mobile, which let Supabase fall back to the
  /// project's Site URL — `http://localhost:3000`, a server that exists on
  /// nobody's machine. The sign-in ended on "Safari cannot connect".
  /// #1050 was the same wound in the signup e-mail: asking for nothing
  /// gets you the Site URL, and the new member's confirmation link went
  /// to a localhost that was never theirs.
  ///
  /// Every value here must also be listed under Authentication → URL
  /// Configuration → Redirect URLs in the Supabase project, or the
  /// provider refuses the redirect and Supabase quietly substitutes the
  /// Site URL — the very address we are trying to escape. The instance
  /// wizard writes both (InstanceAuthConfig, #977).
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
    } catch (e, st) {
      // A refusal comes back as 200 with ok:false, so ANY failure here is
      // infrastructure, not judgement — #1086. This used to rethrow
      // everything but a 404, which contradicted the contract above and
      // reached two call sites with no catch: the sheet's spinner stayed
      // up forever on a 500 or a dropped connection.
      TraceLogger.instance.warn(
        'auth',
        'badge-signin unreachable — answering unavailable',
        error: e,
        stackTrace: st,
      );
      return null;
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
    try {
      await _client.auth
          .verifyOTP(type: OtpType.magiclink, tokenHash: tokenHash);
    } catch (e, st) {
      // #1086 — the badge was judged and accepted; only the exchange
      // failed. That is infrastructure too, and must not read as a bad
      // PIN.
      TraceLogger.instance.warn(
        'auth',
        'badge token exchange failed after an accepted badge',
        error: e,
        stackTrace: st,
      );
      return const BadgeStepResult.failed(BadgeSignInFailure.unavailable);
    }
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
