// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2579 — the pieces of the report editor and reader: the page choices, a
// card row with its moves, the add menus and a notice with its choices.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/bi_report_definition.dart';

/// The pages of a report as choices; a page with no card this reader may
/// see is not offered (an empty question is never "every card").
class BiReportPages extends StatelessWidget {
  const BiReportPages({
    super.key,
    required this.report,
    required this.selected,
    required this.visibleModules,
    required this.onSelected,
    this.enabled = true,
  });

  final BiReportDefinition report;
  final int selected;
  final Set<String> visibleModules;
  final ValueChanged<int> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    child: Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final (i, p) in report.pages.indexed)
          ChoiceChip(
            key: ValueKey('bi-report-page-${p.id}'),
            label: Text(p.title),
            selected: i == selected,
            onSelected:
                enabled &&
                    BiReportDefinition.cardsOf(p).any(visibleModules.contains)
                ? (_) => onSelected(i)
                : null,
          ),
      ],
    ),
  );
}

/// A card of the page with its reading-order moves and its removal, each a
/// button (keyboard and screen readers reach them like any other).
class BiReportCardRow extends StatelessWidget {
  const BiReportCardRow({
    super.key,
    required this.visual,
    required this.title,
    required this.first,
    required this.last,
    required this.onMove,
    required this.onRemove,
  });

  final BiReportVisual visual;
  final String title;
  final bool first;
  final bool last;
  final ValueChanged<int> onMove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final id = visual.id;
    return ListTile(
      key: ValueKey('bi-report-card-$id'),
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: ValueKey('bi-report-up-$id'),
            tooltip: l10n.biReportMoveUp(title),
            icon: const Icon(Icons.arrow_upward),
            onPressed: first ? null : () => onMove(-1),
          ),
          IconButton(
            key: ValueKey('bi-report-down-$id'),
            tooltip: l10n.biReportMoveDown(title),
            icon: const Icon(Icons.arrow_downward),
            onPressed: last ? null : () => onMove(1),
          ),
          IconButton(
            key: ValueKey('bi-report-remove-$id'),
            tooltip: l10n.biReportRemove(title),
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// A chip that opens the list of [modules] to choose one from.
class BiReportAddMenu extends StatelessWidget {
  const BiReportAddMenu({
    super.key,
    required this.keyPrefix,
    required this.label,
    required this.icon,
    required this.modules,
    required this.enabled,
    required this.title,
    required this.onSelected,
  });

  final String keyPrefix;
  final String label;
  final IconData icon;
  final List<String> modules;
  final bool enabled;
  final String Function(String id) title;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    key: ValueKey('$keyPrefix-menu'),
    enabled: enabled && modules.isNotEmpty,
    tooltip: label,
    onSelected: onSelected,
    itemBuilder: (_) => [
      for (final id in modules)
        PopupMenuItem(
          key: ValueKey('$keyPrefix-$id'),
          value: id,
          child: Text(title(id)),
        ),
    ],
    child: Chip(avatar: Icon(icon), label: Text(label)),
  );
}

/// A message inside the editor with the choices it offers.
class BiReportNotice extends StatelessWidget {
  const BiReportNotice({super.key, required this.text, required this.actions});

  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text),
        Wrap(spacing: AppSpacing.sm, children: actions),
      ],
    ),
  );
}
