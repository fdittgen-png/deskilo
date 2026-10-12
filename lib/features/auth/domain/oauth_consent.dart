// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../../core/data/json_reader.dart';

/// The server-owned purpose of an Auth authorization, never a query parameter.
enum OAuthConsentPurpose { identityFederation, mcp }

class OAuthConsentContext {
  const OAuthConsentContext({
    required this.purpose,
    required this.clientId,
    required this.localUserId,
    this.targetAuthUrl,
    this.targetInstallationId,
  });

  final OAuthConsentPurpose purpose;
  final String clientId;
  final String localUserId;
  final Uri? targetAuthUrl;
  final String? targetInstallationId;

  factory OAuthConsentContext.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('invalid_oauth_consent_context');
    }
    // Fail-closed (#2387): a malformed field reads as absent, and an
    // absent client or user refuses the whole context.
    final r = JsonReader.of(value, context: 'oauth_consent_context');
    final clientId = r.textOrAbsent('client_id') ?? '';
    final localUserId = r.textOrAbsent('local_user_id') ?? '';
    if (clientId.isEmpty || localUserId.isEmpty) {
      throw const FormatException('invalid_oauth_consent_context');
    }
    final purpose = switch (r.textOrAbsent('purpose')) {
      'identity_federation' => OAuthConsentPurpose.identityFederation,
      'mcp' => OAuthConsentPurpose.mcp,
      _ => throw const FormatException('unknown_oauth_consent_purpose'),
    };
    Uri? target;
    String? installation;
    if (purpose == OAuthConsentPurpose.identityFederation) {
      final raw = r.textOrAbsent('target_auth_url');
      installation = r.textOrAbsent('target_installation_id');
      target = raw == null ? null : Uri.tryParse(raw);
      if (target == null || target.scheme != 'https' ||
          target.host.isEmpty || target.userInfo.isNotEmpty ||
          target.hasQuery || target.hasFragment ||
          target.path.endsWith('/') ||
          installation == null || installation.isEmpty) {
        throw const FormatException('invalid_identity_consent_target');
      }
    }
    return OAuthConsentContext(
      purpose: purpose,
      clientId: clientId,
      localUserId: localUserId,
      targetAuthUrl: target,
      targetInstallationId: installation,
    );
  }

  /// Auth alone produces the query; its destination must still be the exact
  /// operator-registered provider callback. Credentials never enter toString.
  bool permitsIdentityReturn(Uri uri) {
    final target = targetAuthUrl;
    return purpose == OAuthConsentPurpose.identityFederation &&
        target != null && uri.scheme == target.scheme &&
        uri.authority == target.authority && uri.userInfo.isEmpty &&
        uri.path == '${target.path}/callback' && !uri.hasFragment;
  }
}

class OAuthConsentRequest {
  const OAuthConsentRequest({required this.context, this.returnUri});

  final OAuthConsentContext context;
  final Uri? returnUri;
}

abstract interface class OAuthConsentRepository {
  Future<OAuthConsentContext> context(String authorizationId);
  Future<OAuthConsentRequest> identityRequest(
      String authorizationId, OAuthConsentContext context);
  Future<Uri> approve(String authorizationId, OAuthConsentContext context);
  Future<Uri> deny(String authorizationId, OAuthConsentContext context);
}

/// Fixed, nonsecret boundary failure; provider responses never become UI text.
class OAuthConsentUnavailable implements Exception {
  const OAuthConsentUnavailable();
  @override
  String toString() => 'oauth_consent_unavailable';
}
