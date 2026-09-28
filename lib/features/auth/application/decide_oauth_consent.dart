// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/oauth_consent.dart';

/// Only identity consent can use this action; business consent belongs to its
/// own workflow. A return is accepted only for the reviewed destination.
class DecideOAuthConsent {
  const DecideOAuthConsent(this._repository);
  final OAuthConsentRepository _repository;

  Future<Uri> answer(String authorizationId, OAuthConsentContext context,
      {required bool approve}) async {
    if (context.purpose != OAuthConsentPurpose.identityFederation) {
      throw const OAuthConsentUnavailable();
    }
    final uri = await (approve
        ? _repository.approve(authorizationId, context)
        : _repository.deny(authorizationId, context));
    if (!context.permitsIdentityReturn(uri)) {
      throw const OAuthConsentUnavailable();
    }
    return uri;
  }
}
