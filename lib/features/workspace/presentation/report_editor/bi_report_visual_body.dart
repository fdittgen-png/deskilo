// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What one report visual shows, from the registered figure's own answer:
//   * a figure: the value in its unit, or "Not available" — never 0 for an
//     unknown;
//   * a table: the groups and the total, exact values;
//   * a bar ranks groups from a zero baseline, every bar labelled with its
//     value, the scale stated (a percentage on 0–100 %, never a normalised
//     bar that could pass for one);
//   * a stacked bar is a whole and its labelled parts;
//   * a line is a qualified trend: no history says so in a line, one known
//     period is a point, never a trend; an axis that does not start at zero
//     says so;
//   * every chart has its table, so colour is never the only signal and a
//     screen reader reads the same values.
// Picking a group of a visual that filters reports it to the page. Its
// source opens on the figure's months and, when the visual is narrowed to
// one level, on that level's bookings only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_modules.dart';
import '../../domain/bi_query.dart';
import '../../domain/bi_report_definition.dart';
import '../../domain/bi_report_rules.dart';
import '../../domain/bi_report_selection.dart';
import '../../domain/bi_result.dart';
import '../../providers/bi_providers.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/bi_module_section.dart' show BiModuleView, biModuleViews;
import 'bi_report_charts.dart';
import 'bi_report_labels.dart';

class BiVisualBody extends ConsumerWidget {
  const BiVisualBody({
    super.key,
    required this.workspaceId,
    required this.report,
    required this.page,
    required this.visual,
    required this.filters,
    required this.selection,
    required this.onPick,
  });

  final String workspaceId;
  final BiReportDefinition report;
  final BiReportPage page;
  final BiReportVisual visual;

  /// Every filter that reaches this visual: the report's, the page's, its
  /// own and the page's selection.
  final List<BiReportFilter> filters;

  /// The page's selection when it reaches this visual.
  final BiReportSelection? selection;
  final ValueChanged<BiRow> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (visual.type == BiVisualType.text) {
      return Text(
        visual.text ?? '',
        key: ValueKey('bi-visual-text-${visual.id}'),
      );
    }
    final module = biModuleOf(visual.metricId);
    final view = module == null ? null : biModuleViews[module.id];
    if (module == null || view == null) return _unavailable(l10n);
    final base =
        BiQueryContext.tryParse(report.period.toQuery()) ??
        BiQueryContext.standard;
    final plan = biReadPlanOf(visual, filters);
    final query = plan.groupBy == null
        ? base
        : base.copyWith(groupBy: plan.groupBy);
    // The workspace's own calendar decides which month "now" is.
    final now = ref.watch(clockProvider).now();
    final today =
        ref.watch(readyWorkspaceContextProvider)?.calendar.dateOf(now) ??
        DateTime(now.year, now.month, now.day);
    final period = query.current(today);
    final body = visual.type == BiVisualType.line
        ? BiLineBody(
            workspaceId: workspaceId,
            module: module,
            view: view,
            visual: visual,
            query: base,
            end: period,
          )
        : switch (ref.watch(
            biModuleResultProvider(workspaceId, module.id, query),
          )) {
            AsyncData(:final value) => _ResultBody(
              module: module,
              view: view,
              visual: visual,
              result: value,
              plan: plan,
              selection: selection,
              onPick: onPick,
            ),
            AsyncError() => _unavailable(l10n),
            _ => const LinearProgressIndicator(),
          };
    final drill = module.drill;
    final mayDrill =
        visual.drills &&
        drill != null &&
        ref.watch(myPermissionsProvider).contains(drill.permission);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        body,
        if (plan.unapplied.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              l10n.biEditorNotFiltered,
              key: ValueKey('bi-visual-unfiltered-${visual.id}'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (visual.style.note)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              l10n.biEditorSourceNote(
                biUnitLabel(l10n, module.metric.unit),
                biDateBasisLabel(l10n, module.metric.dateBasis),
                biCoverageLabel(l10n, module.metric.coverage),
              ),
              key: ValueKey('bi-visual-note-${visual.id}'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (mayDrill)
          TextButton.icon(
            key: ValueKey('bi-visual-drill-${visual.id}'),
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.biOpenSource),
            // push: Back returns to this report, its page and selection.
            onPressed: () => context.push(
              drill.target(period, levelId: _levelOf(filters)),
            ),
          ),
      ],
    );
  }

  Widget _unavailable(AppLocalizations l10n) => Text(
    l10n.overviewUnavailable,
    key: ValueKey('bi-visual-unavailable-${visual.id}'),
  );
}

/// The one level [filters] narrow a figure to, or null when they name
/// none or several.
String? _levelOf(List<BiReportFilter> filters) {
  final levels = {
    for (final f in filters)
      if (f.dimension == 'level' && f.operator == 'eq') f.value,
  };
  return levels.length == 1 ? levels.single : null;
}

/// The display name of [row].
String _rowLabel(AppLocalizations l10n, BiRow row) =>
    row.label ??
    (row.isTotal
        ? l10n.biTotal
        : row.isRemainder
        ? l10n.biRemainder
        : row.key);

class _ResultBody extends StatelessWidget {
  const _ResultBody({
    required this.module,
    required this.view,
    required this.visual,
    required this.result,
    required this.plan,
    required this.selection,
    required this.onPick,
  });

  final BiModule module;
  final BiModuleView view;
  final BiReportVisual visual;
  final BiResult result;
  final BiReadPlan plan;
  final BiReportSelection? selection;
  final ValueChanged<BiRow> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    num? valueOf(BiRow r) => r.current.value(module.aggregation);
    String text(BiRow r) => r.current.unknown || valueOf(r) == null
        ? l10n.overviewUnavailable
        : view.value(valueOf(r), locale, result.currency);
    final filtered = plan.applied.isNotEmpty;
    final groups = filtered
        ? biRowsIn(result, plan.applied)
        : [...result.groups];
    final total = filtered ? biTotalOf(groups) : result.total;
    final picked = selection;
    final selectedNote =
        picked != null &&
            plan.applied.any(
              (f) => f.dimension == picked.dimension && f.value == picked.key,
            )
        ? Text(
            l10n.biEditorFilteredBy(picked.label ?? picked.key),
            key: ValueKey('bi-visual-filtered-${visual.id}'),
            style: theme.textTheme.bodySmall,
          )
        : null;
    switch (visual.sort) {
      case 'value_desc':
        groups.sort((a, b) => (valueOf(b) ?? 0).compareTo(valueOf(a) ?? 0));
      case 'value_asc':
        groups.sort((a, b) => (valueOf(a) ?? 0).compareTo(valueOf(b) ?? 0));
    }
    final pickable = visual.interaction == 'filter' && visual.dimension != null;
    final rows = _Rows(
      visualId: visual.id,
      rows: [if (visual.dimension != null) ...groups, total],
      label: (r) => _rowLabel(l10n, r),
      value: text,
      onPick: pickable ? onPick : null,
    );
    final shown = switch (visual.type) {
      BiVisualType.kpi => Text(
        text(total),
        key: ValueKey('bi-visual-value-${visual.id}'),
        style: theme.textTheme.headlineSmall,
      ),
      BiVisualType.table => rows,
      BiVisualType.bar || BiVisualType.stackedBar => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BiBars(
            visual: visual,
            rows: groups,
            percent: module.metric.unit == 'percent',
            label: (r) => _rowLabel(l10n, r),
            valueOf: valueOf,
            text: text,
            onPick: pickable ? onPick : null,
          ),
          BiAsTable(visualId: visual.id, child: rows),
        ],
      ),
      _ => rows,
    };
    return selectedNote == null
        ? shown
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [shown, selectedNote],
          );
  }
}

/// Rows of label and value; with [onPick], each row picks its group.
class _Rows extends StatelessWidget {
  const _Rows({
    required this.visualId,
    required this.rows,
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String visualId;
  final List<BiRow> rows;
  final String Function(BiRow) label;
  final String Function(BiRow) value;
  final ValueChanged<BiRow>? onPick;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final r in rows)
        InkWell(
          key: ValueKey('bi-row-$visualId-${r.key}'),
          onTap: onPick == null || r.isTotal || r.isRemainder
              ? null
              : () => onPick!(r),
          child: Container(
            // A pickable row is a full touch target.
            constraints: const BoxConstraints(
              minHeight: kMinInteractiveDimension,
            ),
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label(r),
                    style: r.isTotal
                        ? Theme.of(context).textTheme.titleSmall
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(value(r)),
              ],
            ),
          ),
        ),
    ],
  );
}
