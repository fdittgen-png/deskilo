// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import '../trace/trace_logger.dart';
import 'auth_callback_guard.dart';
import 'auth_secret_store.dart';
import 'federation_authority.dart';
import 'federation_handoff.dart';
import 'installation_auth_storage.dart';

/// Target-native OAuth runs in an isolated SDK client. Only after the target
/// proves its installation, issuer and binding is its session installed in the
/// app. No canonical bearer is ever forwarded to a target database.
class NativeFederationFlow {
  NativeFederationFlow(
    this.active,
    this.guard,
    this.secrets, {
    this.launch = _launch,
    this.httpClient,
  });
  final SupabaseClient active;
  final AuthCallbackGuard guard;
  final AuthSecretStore secrets;
  final Future<bool> Function(Uri) launch;
  final http.Client? httpClient;
  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
  static const provider = OAuthProvider('custom:deskilo');

  InstallationPkceStorage _pkce(String flow) => InstallationPkceStorage(
    secrets,
    guard.origin,
    purpose: 'federation.$flow',
  );

  SupabaseClient _client(String flow) {
    if (Uri.parse(active.rest.url).origin != guard.origin.origin) {
      throw StateError('federation target changed');
    }
    final key = active.auth.headers['apikey'];
    if (key == null || key.isEmpty) throw StateError('target key unavailable');
    return SupabaseClient(
      guard.origin.origin,
      key,
      httpClient: httpClient,
      authOptions: AuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: false,
        pkceAsyncStorage: _pkce(flow),
      ),
    );
  }

  /// Opens the target's own sign-in in the system browser ONCE and answers
  /// the flow id. A launched browser is not a signed-in person: the answer
  /// arrives later through [AuthCallbackGuard.events].
  Future<String> begin(
    FederationAuthority authority, {
    bool link = false,
  }) async {
    final previous = active.auth.currentSession;
    if ((previous != null) != link) {
      throw const FederationStartFailure(FederationFailure.wrongAccount);
    }
    final redirect = await guard.begin(
      link ? 'federation-link' : 'federation',
      account: previous?.user.id,
      issuer: authority.issuer,
      installationId: authority.installationId,
    );
    final flow = guard.flow!;
    final client = _client(flow);
    try {
      if (previous != null) {
        await client.auth.setInitialSession(jsonEncode(previous.toJson()));
      }
      final url = link
          ? await client.auth.getLinkIdentityUrl(
              provider,
              redirectTo: redirect,
              scopes: 'openid profile',
            )
          : await client.auth.getOAuthSignInUrl(
              provider: provider,
              redirectTo: redirect,
              scopes: 'openid profile',
            );
      if (guard.flow != flow ||
          active.auth.currentUser?.id != previous?.user.id) {
        throw const FederationStartFailure(FederationFailure.wrongAccount);
      }
      if (!await launch(Uri.parse(url.url))) {
        throw const FederationStartFailure(
          FederationFailure.browserUnavailable,
        );
      }
      return flow;
    } catch (error, stack) {
      // trace-exempt: OAuth exceptions may include browser URLs or codes.
      await _clear(flow);
      Error.throwWithStackTrace(
        FederationStartFailure(switch (error) {
          FederationStartFailure(:final failure) => failure,
          AuthRetryableFetchException() => FederationFailure.network,
          AuthException(:final code) => federationFailureFromCode(code),
          _ => FederationFailure.network,
        }),
        stack,
      );
    } finally {
      await client.dispose();
    }
  }

  /// Called only by the sole SDK listener after [AuthCallbackGuard.claim].
  Future<void> complete(Uri callback) async {
    final flow = guard.flow;
    if (flow == null || !guard.consumed) return;
    final expected = guard.expectedAccount;
    final issuer = guard.issuer;
    final installation = guard.installationId;
    final client = _client(flow);
    var accepted = false;
    try {
      if (callback.queryParameters.containsKey('error')) {
        // The provider's own refusal: its CODE picks the next action; its
        // prose (which may quote the account) is never shown or logged.
        guard.report(
          AuthCallbackStatus.refused,
          failure: federationFailureFromCode(
            callback.queryParameters['error_code'],
          ),
        );
        return;
      }
      final code = callback.queryParameters['code'];
      if (code == null || code.isEmpty) throw const _ProofRefused();
      final response = await client.auth.exchangeCodeForSession(code);
      final session = response.session;
      final user = (await client.auth.getUser()).user;
      if (user == null || user.id != session.user.id) {
        throw const _ProofRefused();
      }
      if (expected != null && user.id != expected) {
        throw const _ProofRefused(FederationFailure.wrongAccount);
      }
      final authority = FederationAuthority.parse(
        await client.rpc<Object?>('public_identity_authority'),
      );
      if (authority?.issuer != issuer ||
          authority?.installationId != installation) {
        throw const _ProofRefused(FederationFailure.incompatibleServer);
      }
      final binding = await client.rpc<Object?>('finalize_identity_binding');
      final refusal = federationFailureFromBinding(binding);
      if (refusal != null) throw _ProofRefused(refusal);
      if (binding is! Map ||
          binding['issuer'] != issuer ||
          binding['installation_id'] != installation) {
        throw const _ProofRefused(FederationFailure.incompatibleServer);
      }
      if (guard.flow != flow || active.auth.currentUser?.id != expected) {
        throw const _ProofRefused();
      }
      // A fresh, server-checked target-native session; no second registration,
      // membership mutation, account UUID copying, or permission assignment.
      final native = session.toJson()
        ..remove('provider_token')
        ..remove('provider_refresh_token');
      await active.auth.recoverSession(jsonEncode(native));
      accepted = true;
      guard.report(AuthCallbackStatus.authenticated);
    } on _ProofRefused catch (refusal, stack) {
      // Only the typed reason is recorded, never a token or a callback.
      TraceLogger.instance.warn(
        'auth',
        'federation proof refused: ${refusal.failure.name}',
        stackTrace: stack,
      );
      guard.report(AuthCallbackStatus.refused, failure: refusal.failure);
    } on AuthRetryableFetchException {
      guard.report(AuthCallbackStatus.unavailable);
    } on AuthException catch (error, stack) {
      // The error CODE only: its prose may quote the account or callback.
      TraceLogger.instance.warn(
        'auth',
        'federation exchange refused: ${error.code ?? error.statusCode}',
        stackTrace: stack,
      );
      guard.report(
        AuthCallbackStatus.refused,
        failure: federationFailureFromCode(error.code),
      );
    } catch (error, stack) {
      // trace-exempt: network/provider payloads may contain credentials.
      TraceLogger.instance.warn(
        'auth',
        'federation callback unavailable',
        stackTrace: stack,
      );
      guard.report(AuthCallbackStatus.unavailable);
    } finally {
      // A failed fresh sign-in must not leave an unused native session alive.
      // A linking refusal retains the person's previous working account.
      if (!accepted && expected == null && client.auth.currentSession != null) {
        try {
          await client.auth.signOut(scope: SignOutScope.local);
        } catch (error, stack) {
          // trace-exempt: report only that revocation could not be confirmed.
          TraceLogger.instance.warn(
            'auth',
            'unused federation session cleanup unavailable',
            stackTrace: stack,
          );
        }
      }
      try {
        await _clear(flow);
      } catch (error, stack) {
        // trace-exempt: no persisted callback secrets in diagnostic payloads.
        TraceLogger.instance.warn(
          'auth',
          'federation verifier cleanup unavailable',
          stackTrace: stack,
        );
      } finally {
        await client.dispose();
      }
    }
  }

  /// Abandons an unclaimed flow: its verifier and callback metadata go, so
  /// a late browser return is refused rather than exchanged.
  /// The guard lets go first, so no return can be claimed in between.
  Future<void> cancel(String flow) async {
    if (guard.flow != flow || guard.consumed) return;
    await guard.finish(flow);
    await _pkce(flow).removeItem(key: 'supabase.auth.token-code-verifier');
  }

  Future<void> _clear(String flow) async {
    // The pinned SDK's documented storage uses this single verifier key.
    await _pkce(flow).removeItem(key: 'supabase.auth.token-code-verifier');
    await guard.finish(flow);
  }
}

class _ProofRefused implements Exception {
  const _ProofRefused([this.failure = FederationFailure.refused]);
  final FederationFailure failure;
}
