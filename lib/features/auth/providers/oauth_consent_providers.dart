// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_oauth_consent_repository.dart';
import '../application/decide_oauth_consent.dart';
import '../domain/oauth_consent.dart';
import 'auth_providers.dart';

part 'oauth_consent_providers.g.dart';

@Riverpod(keepAlive: true)
OAuthConsentRepository oauthConsentRepository(Ref ref) =>
    SupabaseOAuthConsentRepository(Supabase.instance.client);

@riverpod
Future<OAuthConsentRequest> oauthConsent(Ref ref, String authorizationId) async {
  ref.watch(authStateProvider.select((state) => state.value));
  final repository = ref.watch(oauthConsentRepositoryProvider);
  final context = await repository.context(authorizationId);
  if (!ref.mounted) throw const OAuthConsentUnavailable();
  if (context.purpose == OAuthConsentPurpose.mcp) {
    return OAuthConsentRequest(context: context);
  }
  return repository.identityRequest(authorizationId, context);
}

@riverpod
DecideOAuthConsent decideOAuthConsent(Ref ref) =>
    DecideOAuthConsent(ref.watch(oauthConsentRepositoryProvider));
