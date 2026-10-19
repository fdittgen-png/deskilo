// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2579 C1 — the editor of a saved report (a v2 view): rename it, add,
// remove and reorder the cards of its first page, save. The draft is local;
// a refused save (someone saved first, the designer went off) keeps it and
// says why. The cards below the panel are the SAVED first page, rendered by
// the same module widgets as any view, under the reader's current rights.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/bi_modules.dart';
import '../../domain/bi_report_definition.dart';
import '../../domain/bi_report_edit.dart';
import '../../domain/bi_saved_view.dart';
import '../../providers/bi_providers.dart';
import 'bi_module_section.dart' show biModuleViews;
import 'bi_view_failure_text.dart';

class BiReportPanel extends ConsumerStatefulWidget {
  const BiReportPanel({
    super.key,
    required this.workspaceId,
    required this.view,
    required this.visibleModules,
  });

  final String workspaceId;

  /// A view whose definition is a report.
  final BiSavedView view;

  /// The module ids this reader may see now.
  final Set<String> visibleModules;

  @override
  ConsumerState<BiReportPanel> createState() => _BiReportPanelState();
}

class _BiReportPanelState extends ConsumerState<BiReportPanel> {
  late final TextEditingController _name;
  late List<BiReportVisual> _visuals;
  late int _revision;
  var _dirty = false;

  BiReportDefinition get _stored => widget.view.definition!.report!;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _reset();
  }

  void _reset() {
    _name.text = widget.view.name;
    _visuals = biVisualsInOrder(_stored.pages.first.visuals);
    _revision = widget.view.revision;
    _dirty = false;
  }

  @override
  void didUpdateWidget(BiReportPanel old) {
    super.didUpdateWidget(old);
    final other = old.view.id != widget.view.id;
    // A newer revision replaces a draft nobody touched; a touched draft is
    // kept and only rebased, so the next save is the person's explicit one.
    if (other || (!_dirty && old.view.revision != widget.view.revision)) {
      _reset();
    } else {
      _revision = widget.view.revision;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _change(List<BiReportVisual> next) => setState(() {
    _visuals = next;
    _dirty = true;
  });

  Future<void> _save() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final page = _stored.pages.first.withVisuals(biRenumber(_visuals));
    try {
      await ref
          .read(biViewActionsProvider)
          .save(
            widget.workspaceId,
            over: BiSavedView(
              id: widget.view.id,
              scope: widget.view.scope,
              name: widget.view.name,
              definition: widget.view.definition,
              isDefault: widget.view.isDefault,
              revision: _revision,
              mine: widget.view.mine,
            ),
            scope: widget.view.scope,
            name: name,
            definition: BiViewDefinition.ofReport(_stored.withFirstPage(page)),
          );
      if (mounted) setState(() => _dirty = false);
    } on BiViewRefused catch (e, st) {
      TraceLogger.instance.warn(
        'bi',
        'report save refused: ${e.failure.name}',
        error: e,
        stackTrace: st,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(biViewFailureText(l10n, e.failure))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    String title(String id) => biModuleViews[id]?.title(l10n) ?? id;
    final used = {for (final v in _visuals) v.metricId};
    final addable = [
      for (final m in biModules)
        if (widget.visibleModules.contains(m.id) && !used.contains(m.id)) m,
    ];
    return Card(
      key: const ValueKey('bi-report-panel'),
      margin: AppSpacing.mdAll,
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.biReportEditorTitle, style: theme.textTheme.titleSmall),
            AppTextField(
              key: const ValueKey('bi-report-name'),
              controller: _name,
              label: l10n.biViewName,
              maxLength: 80,
              onChanged: (_) => setState(() => _dirty = true),
            ),
            if (_visuals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  l10n.biReportNoCards,
                  key: const ValueKey('bi-report-empty'),
                ),
              ),
            for (final (i, v) in _visuals.indexed)
              ListTile(
                key: ValueKey('bi-report-card-${v.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(title(v.metricId ?? v.id)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: ValueKey('bi-report-up-${v.id}'),
                      tooltip: l10n.biReportMoveUp(title(v.metricId ?? v.id)),
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: i == 0
                          ? null
                          : () => _change(biMoveVisual(_visuals, i, -1)),
                    ),
                    IconButton(
                      key: ValueKey('bi-report-down-${v.id}'),
                      tooltip: l10n.biReportMoveDown(title(v.metricId ?? v.id)),
                      icon: const Icon(Icons.arrow_downward),
                      onPressed: i == _visuals.length - 1
                          ? null
                          : () => _change(biMoveVisual(_visuals, i, 1)),
                    ),
                    IconButton(
                      key: ValueKey('bi-report-remove-${v.id}'),
                      tooltip: l10n.biReportRemove(title(v.metricId ?? v.id)),
                      icon: const Icon(Icons.close),
                      onPressed: () => _change([
                        for (final x in _visuals)
                          if (x.id != v.id) x,
                      ]),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                PopupMenuButton<String>(
                  key: const ValueKey('bi-report-add'),
                  enabled: addable.isNotEmpty,
                  tooltip: l10n.biReportAddCard,
                  onSelected: (id) => _change([
                    ..._visuals,
                    BiReportVisual(
                      id: biNextVisualId(
                        _stored.pages
                            .expand((p) => p.visuals)
                            .map((x) => x.id)
                            .followedBy(_visuals.map((x) => x.id)),
                      ),
                      type: BiVisualType.kpi,
                      metricId: id,
                      layout: BiVisualLayout(order: _visuals.length),
                    ),
                  ]),
                  itemBuilder: (_) => [
                    for (final m in addable)
                      PopupMenuItem(
                        key: ValueKey('bi-report-add-${m.id}'),
                        value: m.id,
                        child: Text(title(m.id)),
                      ),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.add),
                    label: Text(l10n.biReportAddCard),
                  ),
                ),
                FilledButton(
                  key: const ValueKey('bi-report-save'),
                  onPressed: _dirty ? _save : null,
                  child: Text(l10n.biViewSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
