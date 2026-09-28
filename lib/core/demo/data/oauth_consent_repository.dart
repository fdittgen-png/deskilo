// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/auth/domain/oauth_consent.dart';

/// Demo has no Auth authorization. Tests may supply an explicit fixture.
class FakeOAuthConsentRepository implements OAuthConsentRepository {
  FakeOAuthConsentRepository({this.request, this.approved, this.denied});

  OAuthConsentRequest? request;
  Uri? approved;
  Uri? denied;
  final calls = <String>[];

  @override
  Future<OAuthConsentContext> context(String authorizationId) async {
    calls.add('context');
    return request?.context ?? (throw const OAuthConsentUnavailable());
  }

  @override
  Future<OAuthConsentRequest> identityRequest(
      String authorizationId, OAuthConsentContext context) async {
    calls.add('identityRequest');
    return request ?? (throw const OAuthConsentUnavailable());
  }

  @override
  Future<Uri> approve(String id, OAuthConsentContext context) async {
    calls.add('approve');
    return approved ?? (throw const OAuthConsentUnavailable());
  }

  @override
  Future<Uri> deny(String id, OAuthConsentContext context) async {
    calls.add('deny');
    return denied ?? (throw const OAuthConsentUnavailable());
  }
}
