// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The editor's left side: the report's pages (open, move, delete, add), the
// visuals of the page on screen in reading order (each selects its visual,
// the order a keyboard and a screen reader follow) and the catalogue of
// visuals to add — a figure, a line, a bar, a stacked bar or a table of a
// registered figure, or a plain explanatory text. The space's report limits
// stop an addition before the server would refuse it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/settings/active_settings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/report_editor/bi_report_commands.dart';
import '../../application/report_editor/bi_report_editor.dart';
import '../../domain/bi_report_definition.dart';
import '../../domain/bi_report_edit.dart';
import '../../domain/bi_report_limits.dart';
import 'bi_report_canvas.dart' show biVisualTitle;
import 'bi_report_labels.dart';
import 'bi_report_metric_picker.dart';

/// The page tabs above the grid.
class BiPageTabs extends StatelessWidget {
  const BiPageTabs({
    super.key,
    required this.report,
    required this.page,
    required this.onPage,
  });

  final BiReportDefinition report;
  final int page;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final (i, p) in report.pages.indexed)
          ChoiceChip(
            key: ValueKey('bi-editor-page-${p.id}'),
            label: Text(p.title),
            selected: i == page,
            onSelected: (_) => onPage(i),
          ),
      ],
    ),
  );
}

class BiPagesPanel extends ConsumerWidget {
  const BiPagesPanel({
    super.key,
    required this.provider,
    required this.onCommand,
  });

  final BiReportEditorProvider provider;

  /// Called after every command, to focus and announce its outcome.
  final VoidCallback onCommand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(provider);
    final editor = ref.read(provider.notifier);
    final limits = BiReportLimits.fromSettings(
      ref.watch(activeSettingsProvider),
    );
    void run(BiEdit Function(BiReportDefinition r, int p) command) {
      editor.run(command);
      onCommand();
    }

    final heading = Theme.of(context).textTheme.titleSmall;
    final last = s.report.pages.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.biEditorPages, style: heading),
        for (final (i, p) in s.report.pages.indexed)
          _PageRow(
            title: p.title,
            id: p.id,
            selected: i == s.page,
            onOpen: () => editor.show(page: i),
            onUp: i == 0 ? null : () => run((r, _) => biMovePage(r, i, -1)),
            onDown: i == last ? null : () => run((r, _) => biMovePage(r, i, 1)),
            onDelete: last == 0
                ? null
                : () => run((r, _) => biDeletePage(r, i)),
          ),
        TextButton.icon(
          key: const ValueKey('bi-page-add'),
          icon: const Icon(Icons.note_add_outlined),
          label: Text(l10n.biEditorAddPage),
          onPressed: limits.canAddPage(s.report)
              ? () => run(
                  (r, _) => biAddPage(
                    r,
                    l10n.biReportPageNumbered('${r.pages.length + 1}'),
                    limits: limits,
                  ),
                )
              : null,
        ),
        const Divider(),
        Text(l10n.biEditorVisuals, style: heading),
        if (s.currentPage.visuals.isEmpty)
          Text(l10n.biEditorEmptyPage)
        else
          for (final v in biVisualsInOrder(s.currentPage.visuals))
            ListTile(
              key: ValueKey('bi-outline-${v.id}'),
              dense: true,
              selected: v.id == s.selected,
              title: Text(biVisualTitle(l10n, v)),
              subtitle: Text(biVisualKindLabel(l10n, v.type)),
              onTap: () {
                editor.show(selected: v.id);
                onCommand();
              },
            ),
        const Divider(),
        Text(l10n.biEditorAddVisual, style: heading),
        _Catalogue(
          enabled: limits.canAddVisual(s.report),
          onAdd: (type) async {
            if (type == BiVisualType.text) {
              run(
                (r, p) => biAddVisual(
                  r,
                  p,
                  type,
                  text: l10n.biEditorNewText,
                  limits: limits,
                ),
              );
              return;
            }
            final metric = await pickBiMetric(context, ref);
            if (metric == null) return;
            run(
              (r, p) =>
                  biAddVisual(r, p, type, metricId: metric, limits: limits),
            );
          },
        ),
      ],
    );
  }
}

class _PageRow extends StatelessWidget {
  const _PageRow({
    required this.title,
    required this.id,
    required this.selected,
    required this.onOpen,
    required this.onUp,
    required this.onDown,
    required this.onDelete,
  });

  final String title;
  final String id;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: ListTile(
            key: ValueKey('bi-page-$id'),
            dense: true,
            selected: selected,
            title: Text(title),
            onTap: onOpen,
          ),
        ),
        IconButton(
          key: ValueKey('bi-page-up-$id'),
          tooltip: l10n.biEditorPageEarlier(title),
          icon: const Icon(Icons.arrow_upward),
          onPressed: onUp,
        ),
        IconButton(
          key: ValueKey('bi-page-down-$id'),
          tooltip: l10n.biEditorPageLater(title),
          icon: const Icon(Icons.arrow_downward),
          onPressed: onDown,
        ),
        IconButton(
          key: ValueKey('bi-page-delete-$id'),
          tooltip: l10n.biEditorPageDelete(title),
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class _Catalogue extends StatelessWidget {
  const _Catalogue({required this.enabled, required this.onAdd});

  final bool enabled;
  final ValueChanged<BiVisualType> onAdd;

  static const _icons = {
    BiVisualType.kpi: Icons.pin_outlined,
    BiVisualType.line: Icons.show_chart,
    BiVisualType.bar: Icons.bar_chart,
    BiVisualType.stackedBar: Icons.stacked_bar_chart,
    BiVisualType.table: Icons.table_rows_outlined,
    BiVisualType.text: Icons.notes,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final MapEntry(key: type, value: icon) in _icons.entries)
          OutlinedButton.icon(
            key: ValueKey('bi-add-${type.name}'),
            icon: Icon(icon),
            label: Text(biVisualKindLabel(l10n, type)),
            onPressed: enabled ? () => onAdd(type) : null,
          ),
      ],
    );
  }
}
