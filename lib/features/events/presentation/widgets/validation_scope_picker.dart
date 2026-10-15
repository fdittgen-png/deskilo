// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';

/// #732 — who validates a rule: the SCOPE, then — for a listed rule —
/// the persons. The owner always may; that is said in the hint, not
/// offered as a choice.
class ValidationScopePicker extends StatelessWidget {
  const ValidationScopePicker({
    super.key,
    required this.scope,
    required this.people,
    required this.selected,
    required this.onScope,
    required this.onToggle,
  });

  /// 'admins' | 'listed' | 'members'.
  final String scope;
  final List<({String id, String name})> people;
  final Set<String> selected;
  final ValueChanged<String> onScope;
  final void Function(String id, {required bool selected}) onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(l10n.validationScopeLabel,
              style: theme.textTheme.titleSmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: SegmentedButton<String>(
            key: const ValueKey('validation-scope'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: 'admins',
                label: Text(l10n.validationScopeAdmins),
              ),
              ButtonSegment(
                value: 'listed',
                label: Text(l10n.validationScopeListed),
              ),
              ButtonSegment(
                value: 'members',
                label: Text(l10n.validationScopeMembers),
              ),
            ],
            selected: {scope},
            onSelectionChanged: (v) => onScope(v.first),
          ),
        ),
        Text(
          l10n.validationScopeHint,
          style: theme.textTheme.bodySmall,
        ),
        if (scope == 'listed')
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final person in people)
                  FilterChip(
                    key: ValueKey('validation-person-${person.id}'),
                    label: Text(person.name),
                    selected: selected.contains(person.id),
                    onSelected: (v) => onToggle(person.id, selected: v),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
