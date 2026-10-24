// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Finances, the pieces around the lists: the space filter, the
// development heading, the hosts that did not answer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/ui/edge_fade_scroll.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../providers/finance_overview_provider.dart';
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
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: EdgeFadeScroll(
        key: const ValueKey('finances-filter'),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            ChoiceChip(
              key: const ValueKey('finances-filter-all'),
              label: Text(l10n.financesAllSpaces),
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
    final l10n = context.l10n;
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
              l10n.financesDevSection,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: tone),
            ),
          ),
        ],
      ),
    );
  }
}

/// One banner per host whose documents could not be read: a host that did
/// not answer is named, never folded into an empty list, and what is shown
/// below is complete for the others. Its action reads every host again.
class FinancesSourceBanners extends ConsumerWidget {
  const FinancesSourceBanners({super.key, required this.sources});

  /// The hosts that did not answer, by origin.
  final List<String> sources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final source in sources)
          InlineBanner(
            key: ValueKey<String>(
              'finances-source-unavailable-${Uri.tryParse(source)?.host ?? source}',
            ),
            icon: Icons.cloud_off_outlined,
            text: l10n.financesSourceUnavailable(
              Uri.tryParse(source)?.host ?? source,
            ),
            actionLabel: l10n.commonRetry,
            onAction: () => ref.invalidate(financeOverviewProvider),
          ),
      ],
    );
  }
}
