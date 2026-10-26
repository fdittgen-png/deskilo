// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A report page as its readers see it: the visuals in reading order on a
// discrete responsive grid (12 columns wide, 4 medium, 1 compact), each a
// card that answers its own registered figure. The editor draws the same
// canvas, with a selection frame and keyboard moves on the cards.
//   * only the page on screen is read; two visuals of the same figure and
//     grouping are one provider, so one answer;
//   * style and layout are not part of any read: changing them asks
//     nothing of the server;
//   * a figure the reader may not read answers nothing here — the server
//     refuses it and the card says "Not available", with no value, tooltip
//     or label that could leak it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_report_definition.dart';
import '../../domain/bi_report_rules.dart';
import '../../domain/bi_report_selection.dart';
import '../widgets/bi_module_section.dart' show biModuleViews;
import 'bi_report_labels.dart';
import 'bi_report_visual_body.dart';

/// The grid's column counts and the width each needs.
const _wideColumns = 12, _mediumColumns = 4;
const _wideWidth = 960.0, _mediumWidth = 560.0;

/// The height of one grid row; a card grows past it when its text does.
const _rowHeight = 72.0;

/// What the editor adds to the canvas: the visual selected for editing,
/// how to select one and the keyboard moves on the focused card.
class BiCanvasEditing {
  const BiCanvasEditing({
    required this.selected,
    required this.onSelect,
    required this.onKey,
    required this.focusNode,
  });

  final String? selected;
  final ValueChanged<String> onSelect;

  /// A key pressed on the card of a visual; true when it was a move.
  final bool Function(String visualId, KeyEvent event) onKey;
  final FocusNode Function(String visualId) focusNode;
}

class BiReportCanvas extends StatelessWidget {
  const BiReportCanvas({
    super.key,
    required this.workspaceId,
    required this.report,
    required this.page,
    required this.selection,
    required this.onSelection,
    this.onKeepSelection,
    this.editing,
  });

  final String workspaceId;
  final BiReportDefinition report;
  final int page;
  final BiReportSelection? selection;
  final ValueChanged<BiReportSelection?> onSelection;

  /// Saves the selection as a filter of the page; null in read mode, where
  /// a selection is never written anywhere.
  final ValueChanged<BiReportSelection>? onKeepSelection;

  /// Null in read mode.
  final BiCanvasEditing? editing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = report.pages[page];
    final visuals = [...p.visuals]
      ..sort((a, b) => a.layout.order.compareTo(b.layout.order));
    final shown = selection?.pageId == p.id ? selection : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= _wideWidth
            ? _wideColumns
            : width >= _mediumWidth
            ? _mediumColumns
            : 1;
        double widthOf(BiReportVisual v) {
          final cells = switch (columns) {
            _wideColumns => v.layout.span,
            _mediumColumns => (v.layout.span / 3).ceil().clamp(1, columns),
            _ => 1,
          };
          return (width + AppSpacing.sm) * cells / columns - AppSpacing.sm;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (shown != null)
              _SelectionBar(
                selection: shown,
                onReset: () => onSelection(null),
                onKeep: onKeepSelection == null
                    ? null
                    : () => onKeepSelection!(shown),
              ),
            if (visuals.isEmpty)
              Padding(
                padding: AppSpacing.lgAll,
                child: Text(
                  l10n.biEditorEmptyPage,
                  key: const ValueKey('bi-canvas-empty'),
                ),
              )
            else
              FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: Wrap(
                  key: ValueKey('bi-canvas-${p.id}'),
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final (i, v) in visuals.indexed)
                      FocusTraversalOrder(
                        order: NumericFocusOrder(i.toDouble()),
                        child: SizedBox(
                          width: widthOf(v),
                          child: _VisualCard(
                            workspaceId: workspaceId,
                            report: report,
                            page: p,
                            visual: v,
                            position: i + 1,
                            count: visuals.length,
                            selection: shown,
                            onSelection: onSelection,
                            editing: editing,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The selection on the page, removable, and the way back to the whole.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.selection,
    required this.onReset,
    required this.onKeep,
  });

  final BiReportSelection selection;
  final VoidCallback onReset;
  final VoidCallback? onKeep;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = selection.label ?? selection.key;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InputChip(
            key: const ValueKey('bi-selection-chip'),
            label: Text(l10n.biEditorSelectionChip(label)),
            onDeleted: onReset,
            deleteButtonTooltipMessage: l10n.biEditorResetSelection,
          ),
          TextButton(
            key: const ValueKey('bi-selection-reset'),
            onPressed: onReset,
            child: Text(l10n.biEditorResetSelection),
          ),
          if (onKeep case final keep?)
            TextButton(
              key: const ValueKey('bi-selection-keep'),
              onPressed: keep,
              child: Text(l10n.biEditorKeepSelection),
            ),
        ],
      ),
    );
  }
}

class _VisualCard extends ConsumerWidget {
  const _VisualCard({
    required this.workspaceId,
    required this.report,
    required this.page,
    required this.visual,
    required this.position,
    required this.count,
    required this.selection,
    required this.onSelection,
    required this.editing,
  });

  final String workspaceId;
  final BiReportDefinition report;
  final BiReportPage page;
  final BiReportVisual visual;
  final int position;
  final int count;
  final BiReportSelection? selection;
  final ValueChanged<BiReportSelection?> onSelection;
  final BiCanvasEditing? editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final title = biVisualTitle(l10n, visual);
    final kind = biVisualKindLabel(l10n, visual.type);
    final edit = editing;
    final selected = edit != null && edit.selected == visual.id;
    final effect = selection == null
        ? null
        : biCrossFilterOf(report, page, visual, selection!);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall,
          key: ValueKey('bi-visual-title-${visual.id}'),
        ),
        if (visual.style.description case final d?)
          Text(d, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        BiVisualBody(
          workspaceId: workspaceId,
          report: report,
          page: page,
          visual: visual,
          // A selection the figure cannot answer still reaches it, so the
          // card says it shows the whole instead of looking filtered.
          filters:
              report.scopeOf(
                page,
                visual,
                selection:
                    effect == BiCrossFilter.filtered ||
                        effect == BiCrossFilter.unsupported
                    ? [selection!.filter]
                    : const [],
              ) ??
              report.scopeOf(page, visual) ??
              const [],
          selection: effect == BiCrossFilter.filtered ? selection : null,
          onPick: (row) => onSelection(biSelectionOf(page, visual, row)),
        ),
        if (effect == BiCrossFilter.outsideScope)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              l10n.biEditorOutsideScope,
              key: ValueKey('bi-visual-outside-${visual.id}'),
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
    final card = Card(
      key: ValueKey('bi-visual-${visual.id}'),
      margin: EdgeInsets.zero,
      shape: selected
          ? RoundedRectangleBorder(
              side: BorderSide(color: theme.colorScheme.primary, width: 2),
              borderRadius: AppRadius.lgAll,
            )
          : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: _rowHeight * visual.layout.height,
        ),
        child: Padding(padding: AppSpacing.mdAll, child: body),
      ),
    );
    if (edit == null) {
      return Semantics(
        container: true,
        label: l10n.biEditorReadLabel(title, kind),
        child: card,
      );
    }
    return Semantics(
      container: true,
      selected: selected,
      label: l10n.biEditorVisualLabel(
        title,
        kind,
        '$position',
        '$count',
        '${visual.layout.span}',
      ),
      child: Focus(
        focusNode: edit.focusNode(visual.id),
        onKeyEvent: (_, event) => edit.onKey(visual.id, event)
            ? KeyEventResult.handled
            : KeyEventResult.ignored,
        child: GestureDetector(
          key: ValueKey('bi-visual-select-${visual.id}'),
          behavior: HitTestBehavior.translucent,
          onTap: () {
            edit.focusNode(visual.id).requestFocus();
            edit.onSelect(visual.id);
          },
          child: card,
        ),
      ),
    );
  }
}

/// A visual's visible heading: its own, else its figure's name, else its
/// kind (a text).
String biVisualTitle(AppLocalizations l10n, BiReportVisual visual) =>
    visual.style.title ??
    switch (biModuleOf(visual.metricId)) {
      final m? => biModuleViews[m.id]?.title(l10n) ?? m.id,
      null => biVisualKindLabel(l10n, visual.type),
    };
