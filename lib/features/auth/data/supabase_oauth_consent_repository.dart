// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/oauth_consent.dart';

/// Auth owns consent and codes. The protected registry decides which kind of
/// consent may be shown before Auth can return an already-approved redirect.
class SupabaseOAuthConsentRepository implements OAuthConsentRepository {
  const SupabaseOAuthConsentRepository(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (e, st) {
      // Auth errors may quote redirect codes. Keep the type and call stack,
      // never the response, request URI or exception message.
      TraceLogger.instance.error('auth', 'OAuth consent request failed',
          error: e.runtimeType, stackTrace: st);
      throw const OAuthConsentUnavailable();
    }
  }

  @override
  Future<OAuthConsentContext> context(String authorizationId) => _guard(() async {
    final value = await _client.rpc<Object?>('oauth_authorization_context',
        params: {'p_authorization_id': authorizationId});
    final context = OAuthConsentContext.fromJson(value);
    _sameAccount(context);
    return context;
  });

  void _sameAccount(OAuthConsentContext context) {
    if (_client.auth.currentUser?.id != context.localUserId) {
      throw StateError('oauth_consent_account_changed');
    }
  }

  Future<void> _recheck(String id, OAuthConsentContext previous) async {
    _sameAccount(previous);
    final current = await context(id);
    if (current.purpose != OAuthConsentPurpose.identityFederation ||
        current.purpose != previous.purpose ||
        current.clientId != previous.clientId ||
        current.localUserId != previous.localUserId ||
        current.targetInstallationId != previous.targetInstallationId ||
        current.targetAuthUrl != previous.targetAuthUrl) {
      throw StateError('identity_consent_changed');
    }
  }

  Uri _return(String? raw, OAuthConsentContext context) {
    _sameAccount(context);
    final uri = raw == null ? null : Uri.tryParse(raw);
    if (uri == null || !context.permitsIdentityReturn(uri)) {
      throw StateError('identity_consent_return_refused');
    }
    return uri;
  }

  @override
  Future<OAuthConsentRequest> identityRequest(
      String authorizationId, OAuthConsentContext context) => _guard(() async {
    await _recheck(authorizationId, context);
    final answer = await _client.auth.oauth.getAuthorizationDetails(
        authorizationId);
    _sameAccount(context);
    switch (answer) {
      case OAuthAuthorizationRedirectResponse(:final redirectUrl):
        return OAuthConsentRequest(
            context: context, returnUri: _return(redirectUrl, context));
      case OAuthAuthorizationDetailsResponse(:final client):
        final redirect = Uri.tryParse(answer.redirectUri);
        final scopes = (answer.scope ?? '').trim().split(RegExp(r'\s+')).toSet();
        if (client.clientId != context.clientId ||
            answer.authorizationId != authorizationId ||
            answer.user.id != context.localUserId ||
            redirect == null || redirect.hasQuery ||
            !context.permitsIdentityReturn(redirect) ||
            !scopes.contains('openid') ||
            scopes.any((scope) => scope != 'openid' && scope != 'profile')) {
          throw StateError('identity_consent_client_changed');
        }
        return OAuthConsentRequest(context: context);
    }
  });

  @override
  Future<Uri> approve(String id, OAuthConsentContext context) => _guard(() async {
    await _recheck(id, context);
    final answer = await _client.auth.oauth.approveAuthorization(id);
    return _return(answer.redirectUrl, context);
  });

  @override
  Future<Uri> deny(String id, OAuthConsentContext context) => _guard(() async {
    await _recheck(id, context);
    final answer = await _client.auth.oauth.denyAuthorization(id);
    return _return(answer.redirectUrl, context);
  });
}
