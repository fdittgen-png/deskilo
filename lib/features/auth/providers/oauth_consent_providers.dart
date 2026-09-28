// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_oauth_consent_repository.dart';
import '../domain/oauth_consent.dart';
import 'auth_providers.dart';

part 'oauth_consent_providers.g.dart';

@Riverpod(keepAlive: true)
OAuthConsentRepository oauthConsentRepository(Ref ref) =>
    SupabaseOAuthConsentRepository(Supabase.instance.client);

@riverpod
Future<OAuthConsentRequest> oauthConsent(Ref ref, String authorizationId) async {
  ref.watch(authStateProvider);
  final repository = ref.watch(oauthConsentRepositoryProvider);
  final context = await repository.context(authorizationId);
  if (context.purpose == OAuthConsentPurpose.mcp) {
    return OAuthConsentRequest(context: context);
  }
  return repository.identityRequest(authorizationId, context);
}
