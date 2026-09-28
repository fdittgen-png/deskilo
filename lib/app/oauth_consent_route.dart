// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/domain/oauth_consent.dart';
import '../features/auth/providers/oauth_consent_providers.dart';
import '../features/auth/presentation/oauth_consent_screen.dart';
import '../features/mcp/presentation/mcp_consent_screen.dart';

/// The app composes both features; neither feature depends on the other.
class OAuthConsentRoute extends ConsumerWidget {
  const OAuthConsentRoute({super.key, required this.authorizationId});
  final String authorizationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(oauthConsentProvider(authorizationId));
    if (!consent.isLoading && !consent.hasError &&
        consent.value?.context.purpose == OAuthConsentPurpose.mcp) {
      return McpConsentScreen(authorizationId: authorizationId);
    }
    return OAuthConsentScreen(authorizationId: authorizationId);
  }
}
