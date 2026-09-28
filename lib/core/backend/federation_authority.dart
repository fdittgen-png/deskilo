// SPDX-License-Identifier: AGPL-3.0-or-later
/// Public routing metadata from this installation's protected operator config.
/// It contains no credentials and does not grant membership or administrator rights.
class FederationAuthority {
  const FederationAuthority(this.installationId, this.issuer);
  final String installationId;
  final String issuer;

  static FederationAuthority? parse(Object? value) {
    if (value is! Map ||
        value['kind'] != 'oidc' ||
        value['provider'] != 'custom:deskilo') {
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
