// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Finances, the pieces around the lists: the space filter, the
// development heading.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/ui/edge_fade_scroll.dart';
import '../../../../l10n/app_localizations.dart';
import 'dev_label.dart';

/// "All spaces" or one of them: the documents of several workspaces arrive
/// here together, and this narrows them to the space being looked at.
class FinancesWorkspaceFilter extends StatelessWidget {
  const FinancesWorkspaceFilter({
    super.key,
    required this.options,
    required this.devIds,
    required this.selected,
    required this.onSelected,
  });
  final List<(String, String)> options;
  final Set<String> devIds;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: EdgeFadeScroll(
        key: const ValueKey('finances-filter'),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            ChoiceChip(
              key: const ValueKey('finances-filter-all'),
              label: Text(l10n?.financesAllSpaces ?? 'All spaces'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
            for (final (id, name) in options) ...[
              const SizedBox(width: AppSpacing.sm),
              ChoiceChip(
                key: ValueKey('finances-filter-$id'),
                label: devIds.contains(id)
                    ? DevLabel(name: name)
                    : Text(name),
                selected: selected == id,
                onSelected: (_) => onSelected(id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The heading of the development documents: test data, never counted.
class FinancesDevSection extends StatelessWidget {
  const FinancesDevSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tone = AppEnvironmentColors.developmentOf(Theme.of(context).brightness);
    return Padding(
      key: const ValueKey('finances-dev-section'),
      padding: const EdgeInsets.fromLTRB(4, AppSpacing.lg, 4, AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 18, color: tone),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n?.financesDevSection ??
                  'Development spaces — test data, not counted above',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: tone),
            ),
          ),
        ],
      ),
    );
  }
}
