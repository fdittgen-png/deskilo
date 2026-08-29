// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

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
  final void Function(String id, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(l10n?.validationScopeLabel ?? 'Who validates',
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
                label: Text(l10n?.validationScopeAdmins ?? 'Admins'),
              ),
              ButtonSegment(
                value: 'listed',
                label: Text(l10n?.validationScopeListed ?? 'Listed persons'),
              ),
              ButtonSegment(
                value: 'members',
                label: Text(l10n?.validationScopeMembers ?? 'All members'),
              ),
            ],
            selected: {scope},
            onSelectionChanged: (v) => onScope(v.first),
          ),
        ),
        Text(
          l10n?.validationScopeHint ??
              'The owner always may. Admins: every admin, or the ones you '
                  'list. Listed: exactly these people, whatever their role. '
                  'All members: anyone active.',
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
                    onSelected: (v) => onToggle(person.id, v),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
