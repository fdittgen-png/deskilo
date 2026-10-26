// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What narrows one visual beyond its page, and where it leads: its own
// filters (each removable; the page's selection can be kept on this visual
// alone) and whether it offers its figure's registered source. A visual's
// filter only narrows the report's and the page's — a wider one is refused
// with its reason — and the source is the figure's own registered target,
// never an address typed here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/report_editor/bi_report_commands.dart';
import '../../application/report_editor/bi_report_editor.dart';
import '../../domain/bi_report_definition.dart';
import '../../domain/bi_report_rules.dart';
import '../widgets/bi_toolbar.dart' show biDimensionName;
import 'bi_report_filter_pane.dart' show biGroupNames;

class BiVisualScope extends ConsumerWidget {
  const BiVisualScope({
    super.key,
    required this.workspaceId,
    required this.provider,
    required this.visual,
    required this.onCommand,
  });

  final String workspaceId;
  final BiReportEditorProvider provider;
  final BiReportVisual visual;
  final VoidCallback onCommand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(provider);
    final editor = ref.read(provider.notifier);
    final id = visual.id;
    final picked = s.selection;
    final source = biModuleOf(visual.metricId)?.drill;
    String valueOf(BiReportFilter f) {
      final names = biGroupNames(ref, workspaceId, s.report, f.dimension);
      return [for (final v in f.values) names[v] ?? v].join(', ');
    }

    String what(BiReportFilter f) =>
        '${biDimensionName(l10n, f.dimension)}: ${valueOf(f)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text(
          l10n.biEditorVisualFilters,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        if (visual.filters.isEmpty)
          Text(
            l10n.biEditorNoFilters,
            key: ValueKey('bi-prop-filters-none-$id'),
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final (i, f) in visual.filters.indexed)
                InputChip(
                  key: ValueKey('bi-prop-filter-$id-$i'),
                  label: Text(
                    f.positive
                        ? l10n.biEditorFilterOnly(what(f), l10n.biEditorScopeVisual)
                        : l10n.biEditorFilterExcept(
                            what(f),
                            l10n.biEditorScopeVisual,
                          ),
                  ),
                  deleteButtonTooltipMessage: l10n.biEditorRemoveFilter,
                  onDeleted: () {
                    editor.run((r, p) => biRemoveVisualFilter(r, p, id, i));
                    onCommand();
                  },
                ),
            ],
          ),
        if (picked != null && picked.visualId != id)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: ValueKey('bi-prop-keep-selection-$id'),
              onPressed: () {
                editor.keepSelectionOn(id);
                onCommand();
              },
              child: Text(
                l10n.biEditorKeepSelectionVisual(picked.label ?? picked.key),
              ),
            ),
          ),
        if (source != null)
          SwitchListTile(
            key: ValueKey('bi-prop-drill-$id'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.biEditorDrill),
            subtitle: Text(l10n.biEditorDrillHint),
            value: visual.drills,
            onChanged: (on) {
              editor.run((r, p) => biSetDrill(r, p, id, on: on));
              onCommand();
            },
          ),
      ],
    );
  }
}
