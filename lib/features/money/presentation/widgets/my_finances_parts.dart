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
import '../../domain/finance_filter.dart';
import '../../domain/finance_hosts.dart';
import '../../domain/finance_overview.dart';
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

/// #2557 C4 — the coverage above the results: each host that answered,
/// with each of its workspaces and how many documents it returned, then one
/// banner per host that did not answer. Each workspace states its own
/// reading; one host down never reads as "everything". C5: each connected
/// host my account names keeps its own state — reading, answered, or a
/// banner with its own Try again.
class FinancesCoverage extends ConsumerWidget {
  const FinancesCoverage({super.key, required this.overview});

  /// Everything read, before any filter.
  final FinanceOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final names = {for (final (id, name) in overview.workspaces) id: name};
    final counts = <String, int>{};
    for (final i in overview.invoices) {
      counts[i.workspaceId] = (counts[i.workspaceId] ?? 0) + 1;
    }
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    String answered(String host, Set<String> workspaceIds) => [
          l10n.financesCoverageAnswered(host),
          if (workspaceIds.isEmpty)
            l10n.financesCoverageNoDocuments
          else
            for (final id in workspaceIds)
              l10n.financesCoverageWorkspace(names[id] ?? id, counts[id] ?? 0),
        ].join(' · ');
    Widget line(String key, IconData icon, String text) => Padding(
          key: ValueKey<String>(key),
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(text, style: muted)),
            ],
          ),
        );
    return Padding(
      key: const ValueKey('finances-coverage'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final source in overview.answered)
            line(
              'finances-coverage-${_hostOf(source.origin) ?? 'home'}',
              Icons.cloud_done_outlined,
              answered(
                _hostOf(source.origin) ?? l10n.financesCoverageHome,
                source.workspaceIds,
              ),
            ),
          for (final read in overview.hosts)
            switch (read.status) {
              FinanceHostStatus.answered => line(
                  'finances-coverage-host-${read.host.installationId}',
                  Icons.cloud_done_outlined,
                  answered(read.host.name, read.workspaceIds),
                ),
              FinanceHostStatus.reading => line(
                  'finances-coverage-reading-${read.host.installationId}',
                  Icons.cloud_sync_outlined,
                  l10n.financesCoverageReading(read.host.name),
                ),
              FinanceHostStatus.failed => InlineBanner(
                  key: ValueKey<String>(
                    'finances-source-unavailable-${read.host.installationId}',
                  ),
                  icon: Icons.cloud_off_outlined,
                  text: l10n.financesSourceUnavailable(read.host.name),
                  actionLabel: l10n.commonRetry,
                  onAction: () => ref
                      .read<FinanceOverviewComposer>(
                        financeOverviewProvider.notifier,
                      )
                      .retry(read.host.installationId),
                ),
            },
          FinancesSourceBanners(sources: overview.unavailableSources),
        ],
      ),
    );
  }
}

/// The host of an origin, or null for the personal home.
String? _hostOf(String? origin) {
  if (origin == null) return null;
  final host = Uri.tryParse(origin)?.host ?? '';
  return host.isEmpty ? origin : host;
}

/// #2557 C4 — the period (issue year) and the document type: the two
/// filters the documents' own facts support, beside the space filter.
class FinancesPeriodTypeFilter extends StatelessWidget {
  const FinancesPeriodTypeFilter({
    super.key,
    required this.years,
    required this.filter,
    required this.onChanged,
  });

  /// The issue years present, newest first.
  final List<int> years;
  final FinanceFilter filter;
  final ValueChanged<FinanceFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.lg,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButton<int?>(
            key: const ValueKey('finances-period'),
            value: filter.year,
            hint: Text(l10n.financesPeriodAll),
            onChanged: (year) => onChanged(filter.copyWith(year: () => year)),
            items: [
              DropdownMenuItem<int?>(
                key: const ValueKey('finances-period-all'),
                child: Text(l10n.financesPeriodAll),
              ),
              for (final year in years)
                DropdownMenuItem<int?>(
                  key: ValueKey('finances-period-$year'),
                  value: year,
                  child: Text('$year'),
                ),
            ],
          ),
          DropdownButton<FinanceDocType>(
            key: const ValueKey('finances-type'),
            value: filter.type,
            onChanged: (type) => onChanged(filter.copyWith(type: type)),
            items: [
              for (final type in FinanceDocType.values)
                DropdownMenuItem(
                  key: ValueKey('finances-type-${type.name}'),
                  value: type,
                  child: Text(switch (type) {
                    FinanceDocType.all => l10n.financesTypeAll,
                    FinanceDocType.invoice => l10n.financesTypeInvoice,
                    FinanceDocType.creditNote => l10n.financesTypeCreditNote,
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
