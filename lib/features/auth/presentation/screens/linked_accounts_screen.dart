// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/social_provider.dart';
import '../../domain/auth_outcome.dart';
import '../../application/federation_handoff_controller.dart';
import '../../providers/auth_providers.dart';
import '../widgets/federation_handoff_panel.dart';

/// Linked accounts (0051): the identities attached to my account — the
/// e-mail credential plus any social provider. Linking runs the same
/// browser OAuth flow as sign-in; afterwards either credential opens
/// this account. Unlink is refused server-side for the last identity.
class LinkedAccountsScreen extends ConsumerStatefulWidget {
  const LinkedAccountsScreen({super.key});

  @override
  ConsumerState<LinkedAccountsScreen> createState() =>
      _LinkedAccountsScreenState();
}

class _LinkedAccountsScreenState
    extends ConsumerState<LinkedAccountsScreen> with WidgetsBindingObserver {
  List<LinkedIdentity>? _identities;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  Future<void> _load() async {
    final repository = ref.read(authRepositoryProvider);
    final account = repository.currentUserId;
    try {
      final identities = await repository.linkedIdentities();
      if (mounted && repository.currentUserId == account &&
          identical(ref.read(authRepositoryProvider), repository)) {
        setState(() => _identities = identities);
      }
    } catch (e, st) {
      TraceLogger.instance.error('auth', 'identities load failed',
          error: e, stackTrace: st);
      if (mounted && repository.currentUserId == account &&
          identical(ref.read(authRepositoryProvider), repository)) {
        setState(() => _identities = const []);
      }
    }
  }

  Future<void> _link(SocialProvider provider) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(authRepositoryProvider).linkSocial(provider);
      if (!mounted) return;
      AppSnack.success(
        context,
        l10n?.linkedAccountsLinkStarted ??
            'Continue in the browser to finish linking.',
      );
      await _load();
    } on AuthException catch (e, st) {
      TraceLogger.instance
          .error('auth', 'link failed', error: e, stackTrace: st);
      if (!mounted) return;
      // The server's own error CODE decides what to say: a provider that
      // is off, linking that is off, an identity that belongs elsewhere —
      // or, for anything else, the code itself, so it can be reported.
      final code = e.code;
      final text = switch (code) {
        'provider_disabled' || 'oauth_provider_not_supported' =>
          l10n?.authSocialUnavailable(provider.label) ??
              '${provider.label} sign-in is not available yet — the server '
                  'has not enabled it.',
        'manual_linking_disabled' =>
          l10n?.authLinkManualDisabled ??
              'Linking accounts is switched off on this server. Its '
                  'administrator must turn on “Allow manual linking” in the '
                  'authentication settings.',
        'identity_already_exists' =>
          l10n?.authLinkAlreadyUsed(provider.label) ??
              'This ${provider.label} identity is already linked to another '
                  'account.',
        _ =>
          l10n?.authLinkFailed(provider.label, code ?? e.statusCode ?? 'unknown') ??
              'Linking ${provider.label} did not work '
                  '(${code ?? e.statusCode ?? 'unknown'}). Try again; if it '
                  "keeps failing, tell the server's administrator this code.",
      };
      AppSnack.error(context, text);
    }
  }

  Future<void> _unlink(LinkedIdentity identity) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(authRepositoryProvider).unlinkIdentity(identity);
      await _load();
    } catch (e, st) {
      TraceLogger.instance
          .error('auth', 'unlink failed', error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.listen(authFeedbackProvider, (_, value) {
      final outcome = value.value?.outcome;
      if (outcome == AuthOutcome.authenticated) {
        ref.invalidate(myDatabaseCapabilitiesProvider);
        unawaited(_load());
      }
      // #1648 — a refusal is worded by the handoff section, with its own
      // next action, not by a generic credentials snack.
    });
    final identities = _identities;
    final linkedProviders = {
      for (final i in identities ?? const <LinkedIdentity>[])
        SocialProvider.fromWire(i.provider),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.linkedAccountsTitle ?? 'Linked accounts'),
      ),
      body: identities == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: AppSpacing.gutterAll,
              children: [
                Text(
                  l10n?.linkedAccountsIntro ??
                      'Sign into this account with any linked identity. '
                          'The available providers depend on your server.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                for (final identity in identities)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.verified_user_outlined),
                      title: Text(
                        SocialProvider.fromWire(identity.provider)?.label ??
                            identity.provider,
                      ),
                      subtitle: Text(
                        l10n?.linkedAccountsLinked ?? 'Linked',
                      ),
                      trailing: identities.length > 1
                          ? TextButton(
                              key: ValueKey('unlink-${identity.provider}'),
                              onPressed: () => _unlink(identity),
                              child: Text(
                                l10n?.linkedAccountsUnlink ?? 'Unlink',
                              ),
                            )
                          : null,
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                for (final provider in ref.watch(availableSocialProvidersProvider).value ?? const <SocialProvider>[])
                  if (!linkedProviders.contains(provider))
                    if (provider == SocialProvider.deskilo &&
                        ref.watch(federationHandoffAvailableProvider))
                      const Card(
                        child: Padding(
                          padding: AppSpacing.gutterAll,
                          child: FederationHandoffSection(link: true),
                        ),
                      )
                    else
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_add_alt),
                        title: Text(provider.label),
                        trailing: FilledButton.tonal(
                          key: ValueKey('link-${provider.name}'),
                          onPressed: () => _link(provider),
                          child: Text(
                            l10n?.linkedAccountsLink ?? 'Link',
                          ),
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}
