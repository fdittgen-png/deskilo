// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2583 C2 — Customize on the workspace overview: pin a key-indicator tile,
// unpin it, move it earlier or later (buttons, so no drag is needed; focus
// stays on the tile that moved), copy the layout of a saved report, save the
// layout as a report of its own. The layout is the person's own saved
// report (bi_overview_layout.dart): Save writes it against the revision it
// was read at under one request id, so
//   * a layout changed elsewhere since it was read is reported and never
//     overwritten — the person reloads it and makes the change again;
//   * a save whose answer was lost is retried as the same request, applied
//     once;
//   * Cancel saves nothing.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../domain/bi_modules.dart';
import '../../domain/bi_overview_layout.dart';
import '../../domain/bi_query.dart';
import '../../domain/bi_report_definition.dart';
import '../../domain/bi_saved_view.dart';
import '../../providers/bi_providers.dart';
import 'bi_module_section.dart' show biModuleViews;
import 'bi_report_parts.dart' show BiReportNotice;
import 'bi_view_failure_text.dart';

enum _Status { idle, saving, conflict, lost }

class OverviewLayoutEditor extends ConsumerStatefulWidget {
  const OverviewLayoutEditor({
    super.key,
    required this.workspaceId,
    required this.modules,
    required this.layout,
    required this.reports,
    required this.onClose,
  });

  final String workspaceId;

  /// The figures this reader may see now, in registry order.
  final List<BiModule> modules;

  /// The person's saved layout, or null (the standard overview).
  final BiSavedView? layout;

  /// The saved reports a layout may be copied from.
  final List<BiSavedView> reports;

  /// Leaves customizing (after a save, a cancel or a reload).
  final VoidCallback onClose;

  @override
  ConsumerState<OverviewLayoutEditor> createState() =>
      _OverviewLayoutEditorState();
}

class _OverviewLayoutEditorState extends ConsumerState<OverviewLayoutEditor> {
  late List<String> _tiles;

  /// The layout as it was read: every save names its revision, and a retry
  /// resends exactly that write even after the list was read again.
  late final BiSavedView? _base = widget.layout;
  var _status = _Status.idle;
  BiViewFailure? _refused;
  String? _requestId;
  final _nodes = <String, FocusNode>{};

  Set<String> get _visible => {for (final m in widget.modules) m.id};

  @override
  void initState() {
    super.initState();
    final report = _base?.definition?.report;
    _tiles = report == null
        ? [for (final m in widget.modules) m.id]
        : [
            for (final t in biTilesOf(report))
              if (_visible.contains(t)) t,
          ];
  }

  @override
  void dispose() {
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  FocusNode _node(String id) =>
      _nodes.putIfAbsent(id, () => FocusNode(debugLabel: 'overview-$id'));

  void _update(VoidCallback change) => setState(change);

  /// A new draft: the pending request is dropped, a retry would be another.
  void _edit(List<String> next, {String? focus}) {
    _update(() {
      _tiles = next;
      _requestId = null;
      _refused = null;
      if (_status != _Status.conflict) _status = _Status.idle;
    });
    if (focus == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nodes[focus]?.requestFocus();
    });
  }

  String _title(String id) => biModuleViews[id]?.title(context.l10n) ?? id;

  void _say(String text) => unawaited(
    SemanticsService.sendAnnouncement(
      View.of(context),
      text,
      Directionality.of(context),
    ),
  );

  Future<void> _save() async {
    final l10n = context.l10n;
    final requestId = _requestId ??= newRequestId();
    _update(() => _status = _Status.saving);
    try {
      await ref
          .read(biViewActionsProvider)
          .save(
            widget.workspaceId,
            over: _base,
            scope: BiViewScope.private,
            name: l10n.overviewLayoutName,
            definition: BiViewDefinition.ofReport(
              biOverviewReport(_tiles, title: l10n.overviewTitle),
            ),
            requestId: requestId,
          );
      if (!mounted) return;
      _say(l10n.overviewLayoutSaved);
      widget.onClose();
    } on BiViewRefused catch (e, st) {
      TraceLogger.instance.warn(
        'bi',
        'overview layout refused: ${e.failure.name}',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      _update(() {
        _status = e.failure == BiViewFailure.stale
            ? _Status.conflict
            : _Status.idle;
        _refused = e.failure == BiViewFailure.stale ? null : e.failure;
        _requestId = null;
      });
    } on Exception catch (e, st) {
      TraceLogger.instance.warn(
        'bi',
        'overview layout not answered',
        error: e,
        stackTrace: st,
      );
      if (mounted) _update(() => _status = _Status.lost);
    }
  }

  /// The layout as a private report of its own; the overview is unchanged.
  Future<void> _saveAsReport() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final name = l10n.biReportCopyName(l10n.overviewTitle);
    try {
      await ref
          .read(biViewActionsProvider)
          .save(
            widget.workspaceId,
            scope: BiViewScope.private,
            name: name,
            definition: BiViewDefinition.ofReport(
              BiReportDefinition.standard(
                query: BiQueryContext.standard,
                cards: _tiles,
                pageTitle: l10n.overviewTitle,
              ),
            ),
          );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.overviewCopiedAsReport(name))),
      );
    } on BiViewRefused catch (e, st) {
      TraceLogger.instance.warn(
        'bi',
        'overview copy refused: ${e.failure.name}',
        error: e,
        stackTrace: st,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(biViewFailureText(l10n, e.failure))),
      );
    }
  }

  void _reload() {
    ref.invalidate(biViewsProvider(widget.workspaceId));
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final saving = _status == _Status.saving;
    final unpinned = [
      for (final m in widget.modules)
        if (!_tiles.contains(m.id)) m.id,
    ];
    return Card(
      key: const ValueKey('overview-layout-editor'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.overviewPinned,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            ..._notices(),
            if (_tiles.isEmpty)
              Text(
                l10n.overviewNoPinned,
                key: const ValueKey('overview-layout-empty'),
              ),
            for (final (i, id) in _tiles.indexed) _row(i, id),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _pinMenu(unpinned),
                _copyMenu(),
                TextButton(
                  key: const ValueKey('overview-copy-to'),
                  onPressed: saving ? null : _saveAsReport,
                  child: Text(l10n.overviewCopyTo),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  key: const ValueKey('overview-layout-cancel'),
                  onPressed: widget.onClose,
                  child: Text(
                    MaterialLocalizations.of(context).cancelButtonLabel,
                  ),
                ),
                FilledButton(
                  key: const ValueKey('overview-layout-save'),
                  onPressed: saving || _status == _Status.conflict
                      ? null
                      : _save,
                  child: Text(l10n.overviewLayoutSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _notices() {
    final l10n = context.l10n;
    return [
      if (_status == _Status.conflict)
        Semantics(
          liveRegion: true,
          child: BiReportNotice(
            key: const ValueKey('overview-layout-conflict'),
            text: l10n.overviewLayoutConflict,
            actions: [
              TextButton(
                key: const ValueKey('overview-layout-reload'),
                onPressed: _reload,
                child: Text(l10n.overviewLayoutReload),
              ),
            ],
          ),
        ),
      if (_status == _Status.lost)
        Semantics(
          liveRegion: true,
          child: BiReportNotice(
            key: const ValueKey('overview-layout-lost'),
            text: l10n.overviewLayoutLost,
            actions: [
              TextButton(
                key: const ValueKey('overview-layout-retry'),
                onPressed: _save,
                child: Text(l10n.biReportRetry),
              ),
            ],
          ),
        ),
      if (_refused case final failure?)
        Semantics(
          liveRegion: true,
          child: Text(
            biViewFailureText(l10n, failure),
            key: const ValueKey('overview-layout-refused'),
          ),
        ),
    ];
  }

  Widget _row(int index, String id) {
    final l10n = context.l10n;
    final title = _title(id);
    return Focus(
      focusNode: _node(id),
      child: Semantics(
        container: true,
        label: l10n.overviewTilePosition(
          title,
          '${index + 1}',
          '${_tiles.length}',
        ),
        child: Row(
          key: ValueKey('overview-layout-tile-$id'),
          children: [
            Expanded(child: Text(title)),
            IconButton(
              key: ValueKey('overview-earlier-$id'),
              tooltip: l10n.overviewMoveEarlier(title),
              icon: const Icon(Icons.arrow_upward),
              onPressed: index == 0
                  ? null
                  : () => _edit(biMoveTile(_tiles, id, -1), focus: id),
            ),
            IconButton(
              key: ValueKey('overview-later-$id'),
              tooltip: l10n.overviewMoveLater(title),
              icon: const Icon(Icons.arrow_downward),
              onPressed: index == _tiles.length - 1
                  ? null
                  : () => _edit(biMoveTile(_tiles, id, 1), focus: id),
            ),
            IconButton(
              key: ValueKey('overview-unpin-$id'),
              tooltip: l10n.overviewUnpinTile(title),
              icon: const Icon(Icons.push_pin),
              onPressed: () => _edit(biUnpinTile(_tiles, id)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pinMenu(List<String> unpinned) => PopupMenuButton<String>(
    key: const ValueKey('overview-pin'),
    enabled: unpinned.isNotEmpty,
    tooltip: context.l10n.overviewAddTile,
    onSelected: (id) => _edit(biPinTile(_tiles, id), focus: id),
    itemBuilder: (context) => [
      for (final id in unpinned)
        PopupMenuItem(
          key: ValueKey('overview-pin-$id'),
          value: id,
          child: Text(_title(id)),
        ),
    ],
    child: Padding(
      padding: AppSpacing.smAll,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.push_pin_outlined),
          const SizedBox(width: AppSpacing.xs),
          Text(context.l10n.overviewAddTile),
        ],
      ),
    ),
  );

  Widget _copyMenu() => PopupMenuButton<BiSavedView>(
    key: const ValueKey('overview-copy-from'),
    enabled: widget.reports.isNotEmpty,
    tooltip: context.l10n.overviewCopyFrom,
    onSelected: (view) {
      final report = view.definition?.report;
      if (report == null) return;
      _edit([
        for (final t in biTilesOf(report))
          if (_visible.contains(t)) t,
      ]);
    },
    itemBuilder: (context) => [
      for (final v in widget.reports)
        PopupMenuItem(
          key: ValueKey('overview-copy-from-${v.id}'),
          value: v,
          child: Text(v.name),
        ),
    ],
    child: Padding(
      padding: AppSpacing.smAll,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.content_copy_outlined),
          const SizedBox(width: AppSpacing.xs),
          Text(context.l10n.overviewCopyFrom),
        ],
      ),
    ),
  );
}
