// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart' show User, UserIdentity;

/// The Auth provider id of "Continue with Deskilo" on every installation.
const _deskiloProviderId = 'custom:deskilo';

/// The subject [user] holds at the Deskilo identity provider, if any: the
/// canonical identity is the authority's issuer and THIS subject, never an
/// e-mail or a display name.
String? deskiloSubjectOf(User user) {
  for (final identity in user.identities ?? const <UserIdentity>[]) {
    if (identity.provider != _deskiloProviderId) continue;
    final sub = identity.identityData?['sub'];
    if (sub is String && sub.isNotEmpty) return sub;
  }
  return null;
}

/// Public routing metadata from this installation's protected operator config.
/// It contains no credentials and does not grant membership or administrator rights.
class FederationAuthority {
  const FederationAuthority(this.installationId, this.issuer);
  final String installationId;
  final String issuer;

  static FederationAuthority? parse(Object? value) {
    if (value is! Map ||
        value['kind'] != 'oidc' ||
        value['provider'] != _deskiloProviderId) {
      return null;
    }
    final id = value['installation_id'];
    final issuer = value['issuer'];
    if (id is! String ||
        issuer is! String ||
        !RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
            .hasMatch(id)) {
      return null;
    }
    final uri = Uri.tryParse(issuer);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    return FederationAuthority(id, issuer);
  }
}
