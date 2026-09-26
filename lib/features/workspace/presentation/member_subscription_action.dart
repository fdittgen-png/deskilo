// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/trace/guarded.dart';
import '../../../l10n/app_localizations.dart';
import '../application/set_member_subscription.dart';
import '../domain/member.dart';
import '../domain/overage_policy.dart';
import '../../money/providers/money_providers.dart';
import '../providers/workspace_providers.dart';

/// Sets a member's subscription (#128): an offered level, a negotiated
/// custom percentage, or — #1279 — no subscription at all. Kept beside the
/// other admin actions (`member_admin_actions.dart` re-exports it).
Future<void> pickMemberSubscription(
  BuildContext context,
  WidgetRef ref,
  Member member,
) async {
  final l10n = AppLocalizations.of(context);
  final offered = (await ref.read(subscriptionLevelsProvider.future))
      .offeredLevels;
  if (!context.mounted) return;

  final custom = TextEditingController();
  final pct = await showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n?.memberSubscriptionLabel ?? 'Subscription'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              // #1279 — "no subscription" is a member STATE, not a preset:
              // a visitor who buys carnets. Never with pay-as-you-go, which
              // would book for free (the server refuses the pair too).
              ChoiceChip(
                key: const ValueKey('member-subscription-none'),
                label: Text(l10n?.memberNoSubscription ?? 'No subscription'),
                selected: member.subscriptionPct == 0,
                onSelected:
                    subscriptionChange(member, 0) ==
                        SubscriptionChange.noneWithPayg
                    ? null
                    : (_) => Navigator.of(context).pop(0),
              ),
              for (final level in offered)
                ChoiceChip(
                  label: Text(l10n?.percentValue(level) ?? '$level%'),
                  selected: member.subscriptionPct == level,
                  onSelected: (_) => Navigator.of(context).pop(level),
                ),
            ],
          ),
          if (member.overagePolicy == OveragePolicy.payg) ...[
            const SizedBox(height: 4),
            Text(
              l10n?.memberNoSubscriptionPaygHint ??
                  'No subscription is not possible with pay-as-you-go: '
                      'choose blocked or a package first.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          // The owner may always negotiate a free value, even when
          // allow_custom hides it from member-facing pickers.
          TextField(
            controller: custom,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n?.memberSubscriptionCustom ?? 'Custom (1–100)',
              suffixIcon: HelpDot(
                l10n?.helpHintMembersTopic ?? 'Members & plans',
                anchor: HelpAnchor.membersSubscription,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = customShare(custom.text);
            if (value == null) return;
            Navigator.of(context).pop(value);
          },
          child: Text(l10n?.commonSave ?? 'Save'),
        ),
      ],
    ),
  );
  if (pct == null || !context.mounted) return;

  // #1449 — application/set_member_subscription.dart holds the rule.
  var change = SubscriptionChange.unchanged;
  if (!await runGuarded(
    context,
    domain: 'workspace',
    message: 'member subscription update failed',
    action: () async =>
        change = await ref.read(memberSubscriptionsProvider).set(member, pct),
  )) {
    return;
  }
  if (change == SubscriptionChange.saved) {
    ref.invalidate(workspaceMembersProvider);
  }
}
