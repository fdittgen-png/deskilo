// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The approval rules a request type has of its own, on the approvals step
// of the setup guide: each one with how many approvals it waits for and
// how many people can give them, counted as the server counts them. A
// rule that asks for more is called out, because its requests are never
// decided and the server keeps the step open until it is changed in the
// rule editor, which the step opens. Nothing here edits a rule.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../domain/rule_reach.dart';
import '../../domain/validation_policy.dart';
import '../../domain/workspace_event.dart';
import '../event_labels.dart';

class SetupApprovalsOwnRules extends StatelessWidget {
  const SetupApprovalsOwnRules({
    super.key,
    required this.rules,
    required this.members,
  });

  /// The stored rules with a request type.
  final List<ValidationPolicy> rules;

  /// The active members.
  final List<Decider> members;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final short = rules.where((r) => ruleIsShort(r, members)).length;
    return Column(
      key: const ValueKey('setup-approvals-own-rules'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.setupApprovalsOwnRulesTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (rules.isEmpty)
          Text(
            l10n.setupApprovalsOwnRulesNone,
            key: const ValueKey('setup-approvals-own-rules-none'),
          )
        else ...[
          if (short > 0) ...[
            InlineBanner(
              key: const ValueKey('setup-approvals-own-rules-short'),
              icon: Icons.group_off_outlined,
              text: l10n.setupApprovalsOwnRulesShort(short),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          for (final rule in rules) _RuleLine(rule: rule, members: members),
        ],
      ],
    );
  }
}

class _RuleLine extends StatelessWidget {
  const _RuleLine({required this.rule, required this.members});

  final ValidationPolicy rule;
  final List<Decider> members;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = rule.eventType!;
    final short = ruleIsShort(rule, members);
    return ListTile(
      key: ValueKey('setup-approvals-rule-$type'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        short ? Icons.warning_amber_outlined : Icons.check_circle_outline,
      ),
      title: Text(eventTypeLabel(l10n, EventType.fromDb(type))),
      subtitle: Text(
        short
            ? l10n.setupApprovalsRuleShort(
                rule.requiredCount,
                decidersUnder(rule, members),
              )
            : l10n.setupApprovalsRuleReach(
                rule.requiredCount,
                decidersUnder(rule, members),
              ),
      ),
    );
  }
}
