// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The report's persistent filters, always in view above the page: each
// names its grouping, its value and its scope (the whole report, or this
// page), and is removed with its own button. They only narrow what the
// reader's rights already allow; the temporary selection of the page is not
// one of them (it shows as a removable chip on the page itself and is saved
// only when the person keeps it as a page filter).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/bi_modules.dart';
import '../../domain/bi_query.dart';
import '../../domain/bi_report_definition.dart';
import '../../providers/bi_providers.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/bi_toolbar.dart' show biDimensionName;

class BiFilterPane extends ConsumerWidget {
  const BiFilterPane({
    super.key,
    required this.workspaceId,
    required this.report,
    required this.page,
    required this.editable,
    required this.onRemove,
  });

  final String workspaceId;
  final BiReportDefinition report;
  final int page;
  final bool editable;

  /// Removes filter `index` of the report (`page` null) or of page `page`.
  final void Function(int? page, int index) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = report.pages[page];
    final names = {
      for (final d in {...report.filters, ...p.filters}.map((f) => f.dimension))
        d: biGroupNames(ref, workspaceId, report, d),
    };
    String valueOf(BiReportFilter f) =>
        [for (final v in f.values) names[f.dimension]?[v] ?? v].join(', ');
    String text(BiReportFilter f, String scope) {
      final what = '${biDimensionName(l10n, f.dimension)}: ${valueOf(f)}';
      return f.positive
          ? l10n.biEditorFilterOnly(what, scope)
          : l10n.biEditorFilterExcept(what, scope);
    }

    final chips = [
      for (final (i, f) in report.filters.indexed)
        _chip(
          context,
          'bi-filter-report-$i',
          text(f, l10n.biEditorScopeReport),
          () => onRemove(null, i),
        ),
      for (final (i, f) in p.filters.indexed)
        _chip(
          context,
          'bi-filter-page-$i',
          text(f, l10n.biEditorScopePage),
          () => onRemove(page, i),
        ),
    ];
    return Semantics(
      container: true,
      label: l10n.biEditorFilters,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.biEditorFilters,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (chips.isEmpty)
              Text(
                l10n.biEditorNoFilters,
                key: const ValueKey('bi-filter-none'),
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: chips,
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String key,
    String label,
    VoidCallback remove,
  ) => InputChip(
    key: ValueKey(key),
    label: Text(label),
    onDeleted: editable ? remove : null,
    deleteButtonTooltipMessage: context.l10n.biEditorRemoveFilter,
  );
}

/// The names of the groups of [dimension], from the answer of the first
/// figure this reader may see that groups by it — the same read a visual
/// grouped that way makes, so nothing is asked twice. A group it does not
/// name keeps its id.
Map<String, String> biGroupNames(
  WidgetRef ref,
  String workspaceId,
  BiReportDefinition report,
  String dimension,
) {
  final module = visibleBiModules(
    ref.watch(enabledFeaturesSyncProvider),
    ref.watch(myPermissionsProvider),
  ).where((m) => m.groupings.contains(dimension)).firstOrNull;
  if (module == null) return const {};
  final query =
      (BiQueryContext.tryParse(report.period.toQuery()) ??
              BiQueryContext.standard)
          .copyWith(groupBy: dimension);
  final groups = ref
      .watch(biModuleResultProvider(workspaceId, module.id, query))
      // A current answer only: a refusal never names what came before.
      .asData
      ?.value
      .groups;
  return {
    for (final r in [...?groups]) r.key: ?r.label,
  };
}
