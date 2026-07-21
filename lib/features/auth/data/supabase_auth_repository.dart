// SPDX-License-Identifier: 0BSD
import 'dart:io' show Platform;

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

  /// Brand → Supabase provider; Microsoft is 'azure' on the server side.
  static OAuthProvider _oauth(SocialProvider provider) => switch (provider) {
        SocialProvider.google => OAuthProvider.google,
        SocialProvider.microsoft => OAuthProvider.azure,
        SocialProvider.apple => OAuthProvider.apple,
        SocialProvider.facebook => OAuthProvider.facebook,
      };

  /// Mobile returns into the app over the deskilo:// scheme (registered
  /// in both native manifests); elsewhere Supabase falls back to the
  /// project's Site URL.
  static String? get _redirect => !kIsWeb && (Platform.isAndroid || Platform.isIOS)
      ? 'deskilo://auth-callback'
      : null;

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
