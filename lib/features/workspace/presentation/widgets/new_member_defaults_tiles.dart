// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1294 — the "New members" rows of the workspace settings screen,
// written as their own file because that screen is at its length budget
// and because these rows are one setting's presentation and nothing
// else.
//
// Dumb, like `availability_tiles.dart`: a value in, a callback out.
// Every write goes through the screen's save path.
//
// The product default is shown beside the effective value when the
// workspace has configured nothing, because "nobody chose" and "chose
// the same as the default" look identical otherwise — and only one of
// them changes when the product default changes.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/new_member_defaults.dart';
import '../../domain/overage_policy.dart';

class NewMemberDefaultsTiles extends StatelessWidget {
  const NewMemberDefaultsTiles({
    super.key,
    required this.defaults,
    required this.enabled,
    required this.onSubscriptionChanged,
    required this.onOveragePolicyChanged,
    this.failed = false,
    this.onRetry,
  });

  /// #1563 — null while the separate `billing_rules` read is in flight or
  /// has failed. The controls are not offered then, and the screen sends
  /// no `new_member_defaults` key at all: a form that renders before its
  /// value arrives must not save the fallback over what is configured.
  final NewMemberDefaults? defaults;

  /// The read answered with a failure rather than not having answered.
  final bool failed;
  final VoidCallback? onRetry;
  final bool enabled;
  final ValueChanged<int> onSubscriptionChanged;
  final ValueChanged<OveragePolicy> onOveragePolicyChanged;

  String _policyLabel(AppLocalizations? l10n, OveragePolicy policy) =>
      switch (policy) {
        OveragePolicy.blocked =>
          l10n?.newMemberOverageBlocked ?? 'Blocked once used up',
        OveragePolicy.payg =>
          l10n?.newMemberOveragePayg ?? 'Pay as you go',
        OveragePolicy.package =>
          l10n?.newMemberOveragePackage ?? 'Must buy a package',
      };

  /// The section's heading, shown whatever state the read is in — the
  /// rows below it are what appears or does not.
  Widget _heading(ThemeData theme, AppLocalizations? l10n) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          l10n?.newMemberDefaultsTitle ?? 'New members',
          style: theme.textTheme.titleMedium,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final defaults = this.defaults;
    if (defaults == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(theme, l10n),
          if (failed)
            InlineBanner(
              icon: Icons.cloud_off_outlined,
              text: l10n?.newMemberDefaultsUnavailable ??
                  'These could not be read just now. Saving leaves them '
                      'exactly as they are.',
              actionLabel:
                  onRetry == null ? null : (l10n?.commonRetry ?? 'Try again'),
              onAction: onRetry,
            )
          else
            const SizedBox(height: 80, child: LoadingView()),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(theme, l10n),
        Text(
          defaults.configured
              ? (l10n?.newMemberDefaultsConfigured ??
                  'What somebody starts with when they join.')
              : (l10n?.newMemberDefaultsUnset ??
                  'Nothing chosen — new members start at 100% with '
                      'bookings blocked once the entitlement is used.'),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          Flexible(
            child: Text(l10n?.newMemberSubscription ?? 'Subscription'),
          ),
          const Spacer(),
          IconButton(
            key: const ValueKey('new-member-pct-down'),
            tooltip: l10n?.newMemberSubscriptionLess ?? 'A smaller subscription',
            icon: const Icon(Icons.remove),
            onPressed: enabled && defaults.subscriptionPct > 1
                ? () => onSubscriptionChanged(defaults.subscriptionPct - 5 < 1
                    ? 1
                    : defaults.subscriptionPct - 5)
                : null,
          ),
          Text(
            l10n?.newMemberSubscriptionValue(defaults.subscriptionPct) ??
                '${defaults.subscriptionPct}%',
            style: theme.textTheme.titleMedium,
          ),
          IconButton(
            key: const ValueKey('new-member-pct-up'),
            tooltip: l10n?.newMemberSubscriptionMore ?? 'A larger subscription',
            icon: const Icon(Icons.add),
            onPressed: enabled && defaults.subscriptionPct < 100
                ? () => onSubscriptionChanged(
                    defaults.subscriptionPct + 5 > 100
                        ? 100
                        : defaults.subscriptionPct + 5)
                : null,
          ),
        ]),
        const SizedBox(height: AppSpacing.sm),
        RadioGroup<OveragePolicy>(
          key: const ValueKey('new-member-overage'),
          groupValue: defaults.overagePolicy,
          // RadioGroup wants a callback, not a nullable one, so the
          // disabled case is handled inside it rather than by passing
          // null — the tile stays dumb and the screen decides.
          onChanged: (value) {
            if (!enabled || value == null) return;
            onOveragePolicyChanged(value);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final policy in OveragePolicy.values)
                RadioListTile<OveragePolicy>(
                  key: ValueKey('new-member-overage-${policy.name}'),
                  dense: true,
                  value: policy,
                  title: Text(_policyLabel(l10n, policy)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
