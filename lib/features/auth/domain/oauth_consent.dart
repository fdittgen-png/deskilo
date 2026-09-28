// SPDX-License-Identifier: AGPL-3.0-or-later

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
    if (value is! Map || value['client_id'] is! String ||
        value['local_user_id'] is! String ||
        (value['client_id'] as String).isEmpty ||
        (value['local_user_id'] as String).isEmpty) {
      throw const FormatException('invalid_oauth_consent_context');
    }
    final purpose = switch (value['purpose']) {
      'identity_federation' => OAuthConsentPurpose.identityFederation,
      'mcp' => OAuthConsentPurpose.mcp,
      _ => throw const FormatException('unknown_oauth_consent_purpose'),
    };
    Uri? target;
    String? installation;
    if (purpose == OAuthConsentPurpose.identityFederation) {
      final raw = value['target_auth_url'];
      final rawInstallation = value['target_installation_id'];
      installation = rawInstallation is String ? rawInstallation : null;
      target = raw is String ? Uri.tryParse(raw) : null;
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
      clientId: value['client_id'] as String,
      localUserId: value['local_user_id'] as String,
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
