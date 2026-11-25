// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- the till layout editor: the owner or an admin starts a till's layout from a trade template, places widgets on
// the grid of each size, moves and resizes them with buttons (never only by dragging), saves the draft and publishes it.
// Every step is checked before it is offered (till_layout_edits.dart); the server checks the same rules again on save.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/service_item.dart';
import '../../domain/till_drawer.dart';
import '../../domain/till_layout.dart';
import '../../domain/till_layout_edits.dart';
import '../../domain/till_layout_port.dart';
import '../../domain/till_layout_templates.dart';
import '../../providers/money_providers.dart' show servicesProvider;
import '../../providers/till_drawer_providers.dart';
import '../../providers/till_layout_providers.dart';
import 'till_layout_canvas.dart';
import 'till_layout_editing.dart';
import 'till_layout_words.dart';

class TillLayoutScreen extends ConsumerStatefulWidget {
  const TillLayoutScreen({super.key, required this.workspaceId, required this.tillId, required this.tillName});

  final String workspaceId;
  final String tillId;
  final String tillName;

  @override
  ConsumerState<TillLayoutScreen> createState() => _TillLayoutScreenState();
}

class _TillLayoutScreenState extends ConsumerState<TillLayoutScreen> {
  final _edit = TillLayoutEditing();

  TillLayoutPort get _port => ref.read(tillLayoutPortProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _edit.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final draft = await _port.draft(widget.workspaceId, widget.tillId);
    final published = draft == null ? await _port.published(widget.workspaceId, widget.tillId) : null;
    if (mounted) _edit.loadedWith(draft: draft, published: published);
  }

  void _start(TillLayoutTemplate t) => _edit.start(t.build(widget.tillName, pageName: (p) => tillTemplatePageName(context.l10n, p)));

  /// The business's items for an item key; a failed read offers none, and the trace keeps why.
  Future<List<ServiceItem>> _items() => guardRead(
    domain: 'till',
    message: 'the items could not be read for a till key',
    read: () => ref.read(servicesProvider.future),
    fallback: (_) => const <ServiceItem>[],
  );

  Future<void> _add() async {
    final grid = _edit.grid;
    if (grid == null) return;
    final picked = await showTillWidgetPicker(context, _items, pages: [for (final p in _edit.layout!.pages) p.name]);
    if (picked == null || !mounted) return;
    final added = addCell(grid, picked.kind, params: picked.params);
    if (added == null) {
      AppSnack.info(context, context.l10n.tillLayoutNoRoom);
      return;
    }
    _edit.replaceGrid(added, select: added.cells.length - 1);
  }

  Future<void> _run(Future<int> Function(String requestId) command, String done, {required bool publish}) async {
    _edit.running(on: true);
    try {
      final version = await command(newRequestId());
      if (!mounted) return;
      _edit.done(savedVersion: publish ? null : version);
      AppSnack.success(context, done);
    } on TillLayoutRefused catch (e, st) {
      TraceLogger.instance.warn('till', 'a till layout was refused: ${e.kind.name}', error: e, stackTrace: st);
      if (!mounted) return;
      final l10n = context.l10n;
      AppSnack.error(context, switch (e.kind) {
        TillLayoutRefusalKind.stale => l10n.tillLayoutStale,
        TillLayoutRefusalKind.invalid => l10n.tillLayoutInvalid(e.reason),
        TillLayoutRefusalKind.other => l10n.tillDrawerFailed,
      });
    } finally {
      if (mounted) _edit.running(on: false);
    }
  }

  /// The layout as it stands, saved as another till's draft over that till's own version; published there by its editor.
  Future<void> _copy() async {
    final l10n = context.l10n;
    final tills = await guardRead(
      domain: 'till',
      message: 'the tills could not be read to copy a layout',
      read: () => ref.read(tillDrawerProvider(widget.workspaceId).future),
      fallback: (_) => const <DrawerTill>[],
    );
    if (!mounted) return;
    final to = await showTillChoice(context, l10n.tillLayoutCopyTo, [for (final t in tills) if (t.id != widget.tillId) (t, 'till-layout-copy-${t.id}', t.name)]);
    if (to == null || !mounted) return;
    final target = await _port.draft(widget.workspaceId, to.id);
    await _run(
      (id) => _port.save(widget.workspaceId, requestId: id, tillId: to.id, layout: TillLayout(name: to.name, pages: _edit.layout!.pages), expectedVersion: target?.version ?? 0),
      l10n.tillLayoutCopied(to.name),
      publish: true,   // this till's own draft keeps its version
    );
  }

  Future<void> _save() => _run(
    (id) => _port.save(widget.workspaceId, requestId: id, tillId: widget.tillId, layout: _edit.layout!, expectedVersion: _edit.version),
    context.l10n.quoteDraftSaved,
    publish: false,
  );

  Future<void> _publish() => _run(
    (id) => _port.publish(widget.workspaceId, requestId: id, tillId: widget.tillId, expectedVersion: _edit.version),
    context.l10n.tillLayoutPublished,
    publish: true,
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: _edit, builder: (context, _) => _page(context));

  Widget _page(BuildContext context) {
    final l10n = context.l10n;
    final layout = _edit.layout;
    final busy = _edit.busy;
    final dirty = _edit.dirty;
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.tillLayoutTitle),
        actions: [
          if (layout != null)
            IconButton(
              key: const ValueKey('till-layout-copy'),
              tooltip: l10n.tillLayoutCopy,
              icon: const Icon(Icons.copy_all_outlined),
              onPressed: busy ? null : _copy,
            ),
          HelpDot(l10n.tillLayoutTitle, anchor: HelpAnchor.moneyTillLayout),
        ],
      ),
      // save and publish sit at the bottom, where a phone has the width for both
      bottomNavigationBar: layout == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('till-layout-save'),
                        onPressed: busy || !dirty ? null : _save,
                        child: Text(l10n.commonSave),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('till-layout-publish'),
                        onPressed: busy || dirty || _edit.version == 0 ? null : _publish,
                        child: Text(l10n.tillLayoutPublish),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: layout == null
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('till-layout-add'),
              onPressed: busy ? null : _add,
              icon: const Icon(Icons.add),
              label: Text(l10n.tillLayoutAdd),
            ),
      body: !_edit.loaded
          ? const LoadingView()
          : layout == null
          ? _Templates(onPick: _start)
          : _Editor(
              layout: layout,
              page: _edit.page,
              size: _edit.size,
              selected: _edit.selected,
              onPage: _edit.showPage,
              onSize: _edit.showSize,
              onSelect: _edit.select,
              onStep: _edit.step,
              onRemove: _edit.remove,
            ),
    );
  }
}

class _Templates extends StatelessWidget {
  const _Templates({required this.onPick});

  final void Function(TillLayoutTemplate) onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(l10n.tillLayoutStartFrom, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final t in TillLayoutTemplate.values)
          Card(
            child: ListTile(
              key: ValueKey('till-layout-template-${t.wire}'),
              title: Text(tillTemplateName(l10n, t)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onPick(t),
            ),
          ),
      ],
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({
    required this.layout,
    required this.page,
    required this.size,
    required this.selected,
    required this.onPage,
    required this.onSize,
    required this.onSelect,
    required this.onStep,
    required this.onRemove,
  });

  final TillLayout layout;
  final int page;
  final TillLayoutSize size;
  final int? selected;
  final ValueChanged<int> onPage;
  final ValueChanged<TillLayoutSize> onSize;
  final ValueChanged<int> onSelect;
  final ValueChanged<TillCellStep> onStep;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final grid = layout.pages[page].grids[size];
    final sel = selected;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, kFabSafeBottom),
      children: [
        SegmentedButton<TillLayoutSize>(
          key: const ValueKey('till-layout-size'),
          segments: [for (final s in TillLayoutSize.values) ButtonSegment(value: s, label: Text(tillSizeName(l10n, s)))],
          selected: {size},
          onSelectionChanged: (s) => onSize(s.single),
        ),
        if (layout.pages.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < layout.pages.length; i++)
                ChoiceChip(
                  key: ValueKey('till-layout-page-$i'),
                  label: Text(layout.pages[i].name),
                  selected: i == page,
                  onSelected: (_) => onPage(i),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (grid != null) TillLayoutCanvas(grid: grid, selected: sel, onSelect: onSelect),
        if (grid != null && sel != null && sel < grid.cells.length) ...[
          const SizedBox(height: AppSpacing.md),
          TillCellToolbar(grid: grid, index: sel, onStep: onStep, onRemove: onRemove),
        ],
      ],
    );
  }
}
