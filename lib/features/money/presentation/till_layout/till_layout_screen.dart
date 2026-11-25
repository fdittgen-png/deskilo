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
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/till_layout.dart';
import '../../domain/till_layout_edits.dart';
import '../../domain/till_layout_port.dart';
import '../../domain/till_layout_templates.dart';
import '../../providers/till_layout_providers.dart';
import 'till_layout_canvas.dart';
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
  TillLayout? _layout;
  int _version = 0;
  bool _loaded = false;
  bool _dirty = false;
  bool _busy = false;
  int _page = 0;
  int? _selected;
  TillLayoutSize _size = TillLayoutSize.phone;

  TillLayoutPort get _port => ref.read(tillLayoutPortProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final draft = await _port.draft(widget.workspaceId, widget.tillId);
    final published = draft == null ? await _port.published(widget.workspaceId, widget.tillId) : null;
    if (!mounted) return;
    setState(() {
      // the published layout is the starting point of a new draft; nothing published: a template is chosen
      _layout = draft ?? (published == null ? null : TillLayout(name: published.name, pages: published.pages));
      _version = draft?.version ?? 0;
      _loaded = true;
      _dirty = draft == null && published != null;
    });
  }

  void _start(TillLayoutTemplate t) => setState(() {
    _layout = t.build(widget.tillName, pageName: (p) => tillTemplatePageName(context.l10n, p));
    _dirty = true;
  });

  TillGrid? get _grid => _layout?.pages[_page].grids[_size];

  void _replaceGrid(TillGrid g, {int? select}) {
    final layout = _layout!;
    final page = layout.pages[_page];
    final pages = [...layout.pages]..[_page] = TillPage(name: page.name, grids: {...page.grids, _size: g});
    setState(() {
      _layout = TillLayout(name: layout.name, pages: pages, version: layout.version);
      _selected = select;
      _dirty = true;
    });
  }

  Future<void> _add() async {
    final grid = _grid;
    if (grid == null) return;
    final picked = await showTillWidgetPicker(context, ref);
    if (picked == null || !mounted) return;
    final added = addCell(grid, picked.kind, params: picked.params);
    if (added == null) {
      AppSnack.info(context, context.l10n.tillLayoutNoRoom);
      return;
    }
    _replaceGrid(added, select: added.cells.length - 1);
  }

  Future<void> _run(Future<int> Function(String requestId) command, String done, {required bool publish}) async {
    setState(() => _busy = true);
    try {
      final version = await command(newRequestId());
      if (!mounted) return;
      setState(() {
        if (!publish) _version = version;
        _dirty = false;
      });
      AppSnack.success(context, done);
    } on TillLayoutRefused catch (e) {
      if (!mounted) return;
      final l10n = context.l10n;
      AppSnack.error(context, switch (e.kind) {
        TillLayoutRefusalKind.stale => l10n.tillLayoutStale,
        TillLayoutRefusalKind.invalid => l10n.tillLayoutInvalid(e.reason),
        TillLayoutRefusalKind.other => l10n.tillDrawerFailed,
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(
    (id) => _port.save(widget.workspaceId, requestId: id, tillId: widget.tillId, layout: _layout!, expectedVersion: _version),
    context.l10n.tillLayoutSaved,
    publish: false,
  );

  Future<void> _publish() => _run(
    (id) => _port.publish(widget.workspaceId, requestId: id, tillId: widget.tillId, expectedVersion: _version),
    context.l10n.tillLayoutPublished,
    publish: true,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layout = _layout;
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.tillLayoutTitle),
        actions: [HelpDot(l10n.tillLayoutTitle, anchor: HelpAnchor.moneyTillLayout)],
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
                        onPressed: _busy || !_dirty ? null : _save,
                        child: Text(l10n.commonSave),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('till-layout-publish'),
                        onPressed: _busy || _dirty || _version == 0 ? null : _publish,
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
              onPressed: _busy ? null : _add,
              icon: const Icon(Icons.add),
              label: Text(l10n.tillLayoutAdd),
            ),
      body: !_loaded
          ? const LoadingView()
          : layout == null
          ? _Templates(onPick: _start)
          : _Editor(
              layout: layout,
              page: _page,
              size: _size,
              selected: _selected,
              onPage: (p) => setState(() {
                _page = p;
                _selected = null;
              }),
              onSize: (s) => setState(() {
                _size = s;
                _selected = null;
              }),
              onSelect: (i) => setState(() => _selected = i),
              onStep: (step) {
                final next = stepCell(_grid!, _selected!, step);
                if (next != null) _replaceGrid(next, select: _selected);
              },
              onRemove: () => _replaceGrid(removeCell(_grid!, _selected!)),
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, kFloatingActionButtonMargin * 6),
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
