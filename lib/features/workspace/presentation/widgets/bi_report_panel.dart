// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2579 — the editor of a saved report (a v2 view): rename it, add, remove
// and reorder the cards of the page on screen, add a page, set its print
// layout, save. The draft is local and is never rebased silently onto
// someone else's save:
//   * a save that lost the race (someone saved since this draft was read)
//     keeps the draft and says so; the person then saves theirs over the
//     newer version or discards it — both explicit;
//   * a save whose answer was lost keeps the draft and offers Retry, which
//     resends the SAME request, so the server answers it once;
//   * the space's report limits (`bi.report_max_*`) stop the editor from
//     offering a card or a page beyond them; the server refuses them anyway.
// The cards below the panel are the SAVED page, rendered by the same module
// widgets as any view, under the reader's current rights.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/settings/active_settings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/bi_modules.dart';
import '../../domain/bi_report_definition.dart';
import '../../domain/bi_report_edit.dart';
import '../../domain/bi_report_limits.dart';
import '../../domain/bi_saved_view.dart';
import '../../providers/bi_providers.dart';
import 'bi_module_section.dart' show biModuleViews;
import 'bi_print_layout_sheet.dart';
import 'bi_report_parts.dart';
import 'bi_view_failure_text.dart';

class BiReportPanel extends ConsumerStatefulWidget {
  const BiReportPanel({
    super.key,
    required this.workspaceId,
    required this.view,
    required this.pageIndex,
    required this.visibleModules,
    required this.onPage,
  });

  final String workspaceId;

  /// A view whose definition is a report.
  final BiSavedView view;

  /// The page on screen.
  final int pageIndex;

  /// The module ids this reader may see now.
  final Set<String> visibleModules;

  /// Opens page `index` of a (just saved) view.
  final void Function(BiSavedView view, int index) onPage;

  @override
  ConsumerState<BiReportPanel> createState() => _BiReportPanelState();
}

class _BiReportPanelState extends ConsumerState<BiReportPanel> {
  late final TextEditingController _name;
  late List<BiReportVisual> _visuals;
  late BiPrintStyle _printStyle;
  late int _revision;
  var _dirty = false;

  /// The revision this draft was read at moved on: someone else saved.
  var _conflict = false;

  /// The last save's answer was lost; Retry resends [_requestId].
  var _failed = false;
  String? _requestId;

  BiReportDefinition get _stored => widget.view.definition!.report!;
  int get _page => widget.pageIndex.clamp(0, _stored.pages.length - 1);

  BiReportDefinition get _draft => _stored
      .withPage(_page, _stored.pages[_page].withVisuals(biRenumber(_visuals)))
      .withPrintStyle(_printStyle);

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _reset();
  }

  void _reset() {
    _name.text = widget.view.name;
    _visuals = biVisualsInOrder(_stored.pages[_page].visuals);
    _printStyle = _stored.printStyle;
    _revision = widget.view.revision;
    _dirty = false;
    _conflict = false;
    _failed = false;
    _requestId = null;
  }

  @override
  void didUpdateWidget(BiReportPanel old) {
    super.didUpdateWidget(old);
    // A newer revision replaces a draft nobody touched. A touched draft
    // keeps the revision it was read at: the next save then meets the
    // conflict and the person decides, never a silent overwrite.
    if (old.view.id != widget.view.id ||
        old.pageIndex != widget.pageIndex ||
        (!_dirty && old.view.revision != widget.view.revision)) {
      _reset();
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
    _failed = false;
    _requestId = null;
  });

  /// The print layout, edited in its own sheet, joins the draft.
  Future<void> _editPrintLayout() async {
    final next = await showBiPrintLayoutSheet(context, _printStyle);
    if (next == null || !mounted) return;
    setState(() {
      _printStyle = next;
      _dirty = true;
      _failed = false;
      _requestId = null;
    });
  }

  /// Saves the draft at the revision it was read at, or — [overwrite], the
  /// person's explicit choice after a conflict — over the newest one.
  Future<void> _save({bool overwrite = false}) async {
    final name = _name.text.trim();
    if (name.isEmpty || _visuals.isEmpty) return;
    if (overwrite) _requestId = null;
    final requestId = _requestId ??= newRequestId();
    final revision = overwrite ? widget.view.revision : _revision;
    await _write(
      () => ref
          .read(biViewActionsProvider)
          .save(
            widget.workspaceId,
            over: widget.view.atRevision(revision),
            scope: widget.view.scope,
            name: name,
            definition: BiViewDefinition.ofReport(_draft),
            requestId: requestId,
          ),
    );
  }

  /// A new page holding the card [metricId], saved at once, then opened.
  Future<void> _addPage(String metricId) async {
    final ids = [
      for (final p in _stored.pages) ...[p.id, ...p.visuals.map((v) => v.id)],
    ];
    final number = _stored.pages.length + 1;
    final page = BiReportPage(
      id: biNextPageId(ids),
      title: context.l10n.biReportPageNumbered('$number'),
      visuals: [
        BiReportVisual.kpi(
          id: biNextVisualId(ids),
          metricId: metricId,
          layout: const BiVisualLayout(order: 0),
        ),
      ],
    );
    final saved = await _write(
      () => ref
          .read(biViewActionsProvider)
          .save(
            widget.workspaceId,
            over: widget.view,
            scope: widget.view.scope,
            name: widget.view.name,
            definition: BiViewDefinition.ofReport(
              _stored.withPage(_stored.pages.length, page),
            ),
          ),
    );
    if (saved != null) widget.onPage(saved, number - 1);
  }

  /// Runs [write] and keeps what its outcome means for the draft: saved
  /// (clean), refused (finished: another attempt is another request; a
  /// stale one is the conflict the person decides), or not answered (the
  /// same request may be resent).
  Future<BiSavedView?> _write(Future<BiSavedView> Function() write) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    BiSavedView? saved;
    BiViewFailure? refused;
    var lost = false;
    try {
      saved = await write();
    } on BiViewRefused catch (e, st) {
      TraceLogger.instance.warn(
        'bi',
        'report save refused: ${e.failure.name}',
        error: e,
        stackTrace: st,
      );
      refused = e.failure;
    } on Exception catch (e, st) {
      TraceLogger.instance.warn(
        'bi',
        'report save not answered',
        error: e,
        stackTrace: st,
      );
      lost = true;
    }
    if (!mounted) return null;
    setState(() {
      _failed = lost;
      _conflict = refused == BiViewFailure.stale;
      if (!lost) _requestId = null;
      if (saved != null) _dirty = false;
    });
    if (refused != null && refused != BiViewFailure.stale) {
      messenger.showSnackBar(
        SnackBar(content: Text(biViewFailureText(l10n, refused))),
      );
    }
    return saved;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final limits = BiReportLimits.fromSettings(
      ref.watch(activeSettingsProvider),
    );
    String title(String id) => biModuleViews[id]?.title(l10n) ?? id;
    final used = {for (final v in _visuals) v.metricId};
    final addable = [
      for (final m in biModules)
        if (widget.visibleModules.contains(m.id)) m,
    ];
    final canAddCard = limits.canAddVisual(_draft);
    return Card(
      key: const ValueKey('bi-report-panel'),
      margin: AppSpacing.mdAll,
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.biReportEditorTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (_stored.pages.length > 1)
              BiReportPages(
                key: const ValueKey('bi-report-pages-edit'),
                report: _stored,
                selected: _page,
                visibleModules: widget.visibleModules,
                enabled: !_dirty,
                onSelected: (i) => widget.onPage(widget.view, i),
              ),
            AppTextField(
              key: const ValueKey('bi-report-name'),
              controller: _name,
              label: l10n.biViewName,
              maxLength: 80,
              onChanged: (_) => _change(_visuals),
            ),
            if (_conflict)
              BiReportNotice(
                key: const ValueKey('bi-report-conflict'),
                text: l10n.biReportConflict,
                actions: [
                  TextButton(
                    key: const ValueKey('bi-report-overwrite'),
                    onPressed: () => _save(overwrite: true),
                    child: Text(l10n.biReportConflictOverwrite),
                  ),
                  TextButton(
                    key: const ValueKey('bi-report-discard'),
                    onPressed: () => setState(_reset),
                    child: Text(l10n.biReportConflictDiscard),
                  ),
                ],
              ),
            if (_failed)
              BiReportNotice(
                key: const ValueKey('bi-report-failed'),
                text: l10n.biReportSaveFailed,
                actions: [
                  TextButton(
                    key: const ValueKey('bi-report-retry'),
                    onPressed: _save,
                    child: Text(l10n.biReportRetry),
                  ),
                ],
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
              BiReportCardRow(
                visual: v,
                title: title(v.metricId ?? v.id),
                first: i == 0,
                last: i == _visuals.length - 1,
                onMove: (delta) => _change(biMoveVisual(_visuals, i, delta)),
                onRemove: () => _change([
                  for (final x in _visuals)
                    if (x.id != v.id) x,
                ]),
              ),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                BiReportAddMenu(
                  key: const ValueKey('bi-report-add'),
                  keyPrefix: 'bi-report-add',
                  label: l10n.biReportAddCard,
                  icon: Icons.add,
                  modules: [
                    for (final m in addable)
                      if (!used.contains(m.id)) m.id,
                  ],
                  enabled: canAddCard,
                  title: title,
                  onSelected: (id) => _change([
                    ..._visuals,
                    BiReportVisual.kpi(
                      id: biNextVisualId(
                        _stored.pages
                            .expand((p) => p.visuals)
                            .map((x) => x.id)
                            .followedBy(_visuals.map((x) => x.id)),
                      ),
                      metricId: id,
                      layout: BiVisualLayout(order: _visuals.length),
                    ),
                  ]),
                ),
                BiReportAddMenu(
                  key: const ValueKey('bi-report-add-page'),
                  keyPrefix: 'bi-report-add-page',
                  label: l10n.biReportAddPage,
                  icon: Icons.note_add_outlined,
                  modules: [for (final m in addable) m.id],
                  enabled:
                      !_dirty && canAddCard && limits.canAddPage(_stored),
                  title: title,
                  onSelected: _addPage,
                ),
                OutlinedButton.icon(
                  key: const ValueKey('bi-report-print-layout'),
                  icon: const Icon(Icons.print_outlined),
                  label: Text(l10n.biPrintLayoutAction),
                  onPressed: _conflict ? null : _editPrintLayout,
                ),
                FilledButton(
                  key: const ValueKey('bi-report-save'),
                  onPressed: _dirty && _visuals.isNotEmpty && !_conflict
                      ? _save
                      : null,
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
