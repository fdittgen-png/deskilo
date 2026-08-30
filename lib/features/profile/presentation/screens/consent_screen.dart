// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/links/link_launcher.dart';
import '../../../../core/privacy/privacy_policy.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/profile_providers.dart';

/// #751 — the GDPR consent. Shown by the router before anything else
/// while the account has not accepted [kPrivacyPolicyVersion]; shown
/// again on demand (review mode) from Settings → Privacy & data, where
/// it only reads. The whole text is on the screen — no "see the policy"
/// link standing in for it — and the button waits for the checkbox.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key, this.review = false});

  final bool review;

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final profile = ref.watch(myProfileProvider).value;
    final acceptedAt = profile?.privacyAcceptedAt;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.consentTitle ?? 'Your data, your rights'),
        automaticallyImplyLeading: widget.review,
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              key: const ValueKey('consent-text'),
              padding: AppSpacing.lgAll,
              children: [
                Text(
                  l10n?.consentIntro ??
                      'Before you use DesKilo, here is what the app does '
                          'with your data, who can see it and what you can '
                          'do about it. Two minutes; it is all there is.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                for (final s in privacySections(l10n)) ...[
                  Text(s.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(s.body, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.md),
                ],
                Text(
                  '${l10n?.consentVersion ?? 'Version'} $kPrivacyPolicyVersion',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (widget.review && acceptedAt != null)
                  Text(
                    l10n?.consentAcceptedOn(
                            MaterialLocalizations.of(context)
                                .formatMediumDate(acceptedAt.toLocal()),
                            profile?.privacyAcceptedVersion ?? '') ??
                        'Accepted on ${acceptedAt.toLocal()} '
                            '(${profile?.privacyAcceptedVersion})',
                    key: const ValueKey('consent-accepted-on'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(spacing: AppSpacing.sm, children: [
                  TextButton.icon(
                    key: const ValueKey('consent-help'),
                    onPressed: () => context.push('/help?topic=Privacy'),
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: Text(l10n?.consentReadInHelp ?? 'Read in the help'),
                  ),
                  TextButton.icon(
                    key: const ValueKey('consent-wiki'),
                    onPressed: () =>
                        ref.read(linkLauncherProvider)(Uri.parse(kPrivacyWikiUrl)),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(l10n?.consentReadOnWiki ?? 'Read on the wiki'),
                  ),
                ]),
              ],
            ),
          ),
          if (!widget.review)
            Material(
              elevation: 4,
              color: theme.colorScheme.surface,
              child: Padding(
                padding: AppSpacing.lgAll,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CheckboxListTile(
                      key: const ValueKey('consent-checkbox'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(l10n?.consentCheckbox ??
                          'I have read this and I accept how DesKilo '
                              'handles my data.'),
                      value: _accepted,
                      onChanged: (v) => setState(() => _accepted = v ?? false),
                    ),
                    FilledButton(
                      key: const ValueKey('consent-accept'),
                      onPressed: _accepted ? _accept : null,
                      child: Text(l10n?.consentAccept ?? 'Accept and continue'),
                    ),
                  ],
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Future<void> _accept() async {
    final l10n = AppLocalizations.of(context);
    final ok = await runGuarded(
      context,
      domain: 'privacy',
      message: 'accept privacy policy failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref
          .read(profileRepositoryProvider)
          .acceptPrivacyPolicy(kPrivacyPolicyVersion),
    );
    if (!ok) return;
    ref.invalidate(myProfileProvider);
    // The router's redirect reads the refreshed profile and lets the
    // app through; the explicit go covers a refresh that lands late.
    await ref.read(myProfileProvider.future);
    if (mounted) context.go('/reserve');
  }
}
