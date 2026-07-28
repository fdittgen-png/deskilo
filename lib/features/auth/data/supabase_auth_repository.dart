// SPDX-License-Identifier: 0BSD

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_repository.dart';
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
}
