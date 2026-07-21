// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/social_provider.dart';
import '../../providers/auth_providers.dart';

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
    extends ConsumerState<LinkedAccountsScreen> {
  List<LinkedIdentity>? _identities;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final identities =
          await ref.read(authRepositoryProvider).linkedIdentities();
      if (mounted) setState(() => _identities = identities);
    } catch (e, st) {
      TraceLogger.instance.error('auth', 'identities load failed',
          error: e, stackTrace: st);
      if (mounted) setState(() => _identities = const []);
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
      AppSnack.error(
        context,
        l10n?.authSocialUnavailable(provider.label) ??
            '${provider.label} sign-in is not available yet — the server '
                'has not enabled it.',
      );
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
                      'Sign into this account with any of these. Add '
                          'Google, Microsoft, Apple, or Facebook to sign '
                          'in without a password.',
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
                for (final provider in SocialProvider.values)
                  if (!linkedProviders.contains(provider))
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
