// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The editor's right side: the properties of what is selected. Nothing
// selected: the report's name and the page's title. A visual: its visible
// title and description, the figure it is bound to (with the figure's unit,
// date basis and coverage), how it is shown (kind, grouping, sort, number
// format), what a click on it does (filter the page, or nothing), its
// presentation (legend, value labels, palette, a line's axis, the source
// note) and its place on the grid — earlier, later, narrower, wider, lower,
// higher, duplicate, delete — all buttons, no drag needed.
//
// Every choice goes through the binding rules: one the figure cannot keep
// is refused with its reason and the visual keeps its previous valid
// binding. Nothing here changes a figure's formula or source amount.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/settings/active_settings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/report_editor/bi_report_commands.dart';
import '../../application/report_editor/bi_report_editor.dart';
import '../../domain/bi_report_definition.dart';
import '../../domain/bi_report_limits.dart';
import '../../domain/bi_report_rules.dart';
import '../../domain/bi_saved_view.dart';
import '../widgets/bi_toolbar.dart' show biDimensionName;
import 'bi_report_canvas.dart' show biVisualTitle;
import 'bi_report_fields.dart';
import 'bi_report_labels.dart';
import 'bi_report_metric_picker.dart';

class BiPropertiesPanel extends ConsumerWidget {
  const BiPropertiesPanel({
    super.key,
    required this.provider,
    required this.onCommand,
  });

  final BiReportEditorProvider provider;
  final VoidCallback onCommand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(provider);
    final visual = s.selectedVisual;
    return visual == null
        ? _ReportProperties(provider: provider, onCommand: onCommand)
        : _VisualProperties(
            key: ValueKey('bi-props-${visual.id}'),
            provider: provider,
            visual: visual,
            onCommand: onCommand,
          );
  }
}

class _ReportProperties extends ConsumerWidget {
  const _ReportProperties({required this.provider, required this.onCommand});

  final BiReportEditorProvider provider;
  final VoidCallback onCommand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(provider);
    final editor = ref.read(provider.notifier);
    final page = s.currentPage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.biEditorReportProperties,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        BiSyncedField(
          key: const ValueKey('bi-prop-report-name'),
          value: s.name,
          label: l10n.biViewName,
          maxLength: BiSavedView.maxName,
          onChanged: editor.rename,
        ),
        BiSyncedField(
          key: ValueKey('bi-prop-page-title-${page.id}'),
          value: page.title,
          label: l10n.biEditorPageTitle,
          maxLength: BiReportPage.maxTitle,
          onChanged: (t) {
            editor.run(
              (r, p) => biRenamePage(r, p, t),
              coalesce: 'page-title-${page.id}',
            );
            onCommand();
          },
        ),
        Text(
          l10n.biEditorSelectHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _VisualProperties extends ConsumerWidget {
  const _VisualProperties({
    super.key,
    required this.provider,
    required this.visual,
    required this.onCommand,
  });

  final BiReportEditorProvider provider;
  final BiReportVisual visual;
  final VoidCallback onCommand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final editor = ref.read(provider.notifier);
    final id = visual.id;
    void bind(BiBinding Function(BiReportVisual v) change, {String? merge}) {
      editor.run((r, p) => biChangeVisual(r, p, id, change), coalesce: merge);
      onCommand();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          biVisualTitle(l10n, visual),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(biVisualKindLabel(l10n, visual.type)),
        const SizedBox(height: AppSpacing.sm),
        BiSyncedField(
          key: ValueKey('bi-prop-title-$id'),
          value: visual.style.title ?? '',
          label: l10n.biEditorVisualTitle,
          maxLength: BiVisualStyle.maxTitle,
          onChanged: (t) =>
              bind((v) => biSetStyle(v, 'title', t.trim()), merge: 'title-$id'),
        ),
        BiSyncedField(
          key: ValueKey('bi-prop-description-$id'),
          value: visual.style.description ?? '',
          label: l10n.biEditorVisualDescription,
          maxLength: BiVisualStyle.maxDescription,
          onChanged: (t) => bind(
            (v) => biSetStyle(v, 'description', t.trim()),
            merge: 'description-$id',
          ),
        ),
        if (visual.type == BiVisualType.text)
          BiSyncedField(
            key: ValueKey('bi-prop-text-$id'),
            value: visual.text ?? '',
            label: l10n.biEditorText,
            maxLength: BiReportVisual.maxText,
            maxLines: 4,
            onChanged: (t) {
              editor.run(
                (r, p) => biSetText(r, p, id, t),
                coalesce: 'text-$id',
              );
              onCommand();
            },
          )
        else
          _Binding(visual: visual, bind: bind),
        _Presentation(visual: visual, bind: bind),
        _Layout(provider: provider, visual: visual, onCommand: onCommand),
      ],
    );
  }
}

typedef _Bind = void Function(
  BiBinding Function(BiReportVisual v) change, {
  String? merge,
});

/// The figure and how it is shown.
class _Binding extends ConsumerWidget {
  const _Binding({required this.visual, required this.bind});

  final BiReportVisual visual;
  final _Bind bind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final module = biModuleOf(visual.metricId);
    final id = visual.id;
    const kinds = [
      BiVisualType.kpi,
      BiVisualType.line,
      BiVisualType.bar,
      BiVisualType.stackedBar,
      BiVisualType.table,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.biEditorFigure,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        ListTile(
          key: ValueKey('bi-prop-metric-$id'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            module == null
                ? l10n.overviewUnavailable
                : biVisualTitle(
                    l10n,
                    visual.copyWith(style: const BiVisualStyle()),
                  ),
          ),
          subtitle: module == null ? null : Text(biFigureFacts(l10n, module)),
          trailing: TextButton(
            key: ValueKey('bi-prop-metric-change-$id'),
            onPressed: () async {
              final metric = await pickBiMetric(context, biBindableModules(ref));
              if (metric != null) bind((v) => biBindMetric(v, metric));
            },
            child: Text(l10n.biEditorChangeFigure),
          ),
        ),
        BiChoiceField<BiVisualType>(
          key: ValueKey('bi-prop-type-$id'),
          label: l10n.biEditorKind,
          value: visual.type,
          choices: kinds,
          name: (t) => biVisualKindLabel(l10n, t),
          onChanged: (t) => bind((v) => biSetType(v, t)),
        ),
        if (module != null) ...[
          BiChoiceField<String?>(
            key: ValueKey('bi-prop-dimension-$id'),
            label: l10n.biEditorGrouping,
            value: visual.dimension,
            choices: [null, ...biDimensionsOf(module)],
            name: (d) =>
                d == null ? l10n.biEditorNoGrouping : biDimensionName(l10n, d),
            onChanged: (d) => bind((v) => biSetDimension(v, d)),
          ),
          BiChoiceField<String>(
            key: ValueKey('bi-prop-sort-$id'),
            label: l10n.biEditorSort,
            value: visual.sort ?? 'natural',
            choices: BiReportVisual.sorts.toList(),
            name: (o) => _sortName(l10n, o),
            onChanged: (o) => bind((v) => biSetSort(v, o)),
          ),
          BiChoiceField<String>(
            key: ValueKey('bi-prop-format-$id'),
            label: l10n.biEditorFormat,
            value: visual.format ?? 'auto',
            choices: biFormatsOf(module).toList(),
            name: (f) => _formatName(l10n, f),
            onChanged: (f) => bind((v) => biSetFormat(v, f)),
          ),
          BiChoiceField<String>(
            key: ValueKey('bi-prop-interaction-$id'),
            label: l10n.biEditorInteraction,
            value: visual.interaction,
            choices: const ['filter', 'none'],
            name: (i) => i == 'filter'
                ? l10n.biEditorInteractionFilter
                : l10n.biEditorInteractionNone,
            onChanged: (i) =>
                bind((v) => BiBinding.ok(v.copyWith(interaction: i))),
          ),
        ],
      ],
    );
  }

  static String _sortName(AppLocalizations l10n, String sort) => switch (sort) {
    'value_desc' => l10n.biEditorSortHighFirst,
    'value_asc' => l10n.biEditorSortLowFirst,
    _ => l10n.biEditorSortNatural,
  };

  static String _formatName(AppLocalizations l10n, String format) =>
      switch (format) {
        'percent' => l10n.biEditorUnitPercent,
        'currency' => l10n.biEditorUnitAmount,
        'number' => l10n.biEditorUnitCount,
        _ => l10n.biEditorFormatAuto,
      };
}

/// Legend, value labels, palette, a line's axis, the source note.
class _Presentation extends StatelessWidget {
  const _Presentation({required this.visual, required this.bind});

  final BiReportVisual visual;
  final _Bind bind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final id = visual.id;
    final style = visual.style;
    if (visual.type == BiVisualType.text) return const SizedBox.shrink();
    Widget toggle(String key, String label, {required bool value}) =>
        SwitchListTile(
          key: ValueKey('bi-prop-$key-$id'),
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: value,
          onChanged: (on) => bind((v) => biSetStyle(v, key, on ? null : false)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        toggle('legend', l10n.biEditorLegend, value: style.legend),
        toggle('labels', l10n.biEditorValueLabels, value: style.labels),
        toggle('note', l10n.biEditorSourceNoteToggle, value: style.note),
        BiChoiceField<String>(
          key: ValueKey('bi-prop-palette-$id'),
          label: l10n.biEditorPalette,
          value: style.palette,
          choices: BiVisualStyle.palettes.toList(),
          name: (p) => switch (p) {
            'contrast' => l10n.biEditorPaletteContrast,
            'mono' => l10n.biEditorPaletteMono,
            _ => l10n.biEditorPaletteStandard,
          },
          onChanged: (p) =>
              bind((v) => biSetStyle(v, 'palette', p == 'standard' ? null : p)),
        ),
        if (visual.type == BiVisualType.line)
          BiChoiceField<String>(
            key: ValueKey('bi-prop-axis-$id'),
            label: l10n.biEditorAxis,
            value: style.axis,
            choices: BiVisualStyle.axes.toList(),
            name: (a) =>
                a == 'fit' ? l10n.biEditorAxisFit : l10n.biEditorAxisZero,
            onChanged: (a) =>
                bind((v) => biSetStyle(v, 'axis', a == 'zero' ? null : a)),
          ),
      ],
    );
  }
}

/// The visual's place: earlier, later, narrower, wider, lower, higher,
/// duplicate, delete.
class _Layout extends ConsumerWidget {
  const _Layout({
    required this.provider,
    required this.visual,
    required this.onCommand,
  });

  final BiReportEditorProvider provider;
  final BiReportVisual visual;
  final VoidCallback onCommand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(provider);
    final editor = ref.read(provider.notifier);
    final limits = BiReportLimits.fromSettings(
      ref.watch(activeSettingsProvider),
    );
    final id = visual.id;
    final layout = visual.layout;
    final count = s.currentPage.visuals.length;
    void run(BiEdit Function(BiReportDefinition r, int p) command) {
      editor.run(command);
      onCommand();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text(
          l10n.biEditorPlace('${layout.order + 1}', '$count'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            TextButton.icon(
              key: ValueKey('bi-prop-earlier-$id'),
              icon: const Icon(Icons.arrow_back),
              label: Text(l10n.biEditorEarlier),
              onPressed: layout.order == 0
                  ? null
                  : () => run((r, p) => biMoveVisualBy(r, p, id, -1)),
            ),
            TextButton.icon(
              key: ValueKey('bi-prop-later-$id'),
              icon: const Icon(Icons.arrow_forward),
              label: Text(l10n.biEditorLater),
              onPressed: layout.order >= count - 1
                  ? null
                  : () => run((r, p) => biMoveVisualBy(r, p, id, 1)),
            ),
          ],
        ),
        BiStepper(
          keyPrefix: 'bi-prop-width-$id',
          label: l10n.biEditorWidth,
          value: l10n.biEditorColumns('${layout.span}'),
          less: l10n.biEditorNarrower,
          more: l10n.biEditorWider,
          onLess: layout.span > 1
              ? () => run((r, p) => biResizeVisual(r, p, id, span: -1))
              : null,
          onMore: layout.span < BiVisualLayout.maxSpan
              ? () => run((r, p) => biResizeVisual(r, p, id, span: 1))
              : null,
        ),
        BiStepper(
          keyPrefix: 'bi-prop-height-$id',
          label: l10n.biEditorHeight,
          value: l10n.biEditorRows('${layout.height}'),
          less: l10n.biEditorLower,
          more: l10n.biEditorHigher,
          onLess: layout.height > 1
              ? () => run((r, p) => biResizeVisual(r, p, id, height: -1))
              : null,
          onMore: layout.height < BiVisualLayout.maxHeight
              ? () => run((r, p) => biResizeVisual(r, p, id, height: 1))
              : null,
        ),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            TextButton.icon(
              key: ValueKey('bi-prop-duplicate-$id'),
              icon: const Icon(Icons.copy_outlined),
              label: Text(l10n.biEditorDuplicate),
              onPressed: limits.canAddVisual(s.report)
                  ? () => run(
                      (r, p) => biDuplicateVisual(r, p, id: id, limits: limits),
                    )
                  : null,
            ),
            TextButton.icon(
              key: ValueKey('bi-prop-delete-$id'),
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.biEditorDelete),
              onPressed: () => run((r, p) => biDeleteVisual(r, p, id)),
            ),
          ],
        ),
      ],
    );
  }
}
