// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The report editor's frame. Wide: the Pages and Visuals catalogue on the
// left, the page's responsive grid in the centre, the Properties of what is
// selected on the right. Compact: the grid full width, the catalogue and the
// properties in labelled sheets from the bottom bar; focus returns to the
// selected visual when a sheet closes. Every drag-free operation has a
// button and a key:
//   * on a focused visual: Alt+arrows move it earlier or later, Shift+arrows
//     narrow, widen, lower or heighten it, Delete removes it, Enter selects;
//   * anywhere: Ctrl/⌘+Z undoes, Ctrl/⌘+Shift+Z or Ctrl+Y redoes, Ctrl/⌘+S
//     saves.
// Leaving with unsaved changes asks Save / Discard / Keep editing; closing
// that question keeps editing and saves nothing.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../application/report_editor/bi_report_commands.dart';
import '../../application/report_editor/bi_report_editor.dart';
import '../../application/report_editor/bi_report_editor_state.dart';
import '../../domain/bi_report_definition.dart';
import '../../domain/bi_saved_view.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/bi_views_bar.dart' show biCanShareViews;
import 'bi_report_canvas.dart';
import 'bi_report_editor_notices.dart';
import 'bi_report_filter_pane.dart';
import 'bi_report_labels.dart';
import 'bi_report_pages_panel.dart';
import 'bi_report_properties.dart';

/// From this width the catalogue and the properties sit beside the grid.
const _wideLayout = 900.0;
const _sideWidth = 260.0;

class BiReportEditorView extends ConsumerStatefulWidget {
  const BiReportEditorView({super.key, required this.seed});

  final BiReportEditorSeed seed;

  @override
  ConsumerState<BiReportEditorView> createState() => _BiReportEditorViewState();
}

class _BiReportEditorViewState extends ConsumerState<BiReportEditorView> {
  final _nodes = <String, FocusNode>{};

  /// Set once the person chose to leave: the next pop is not asked about.
  var _leaving = false;

  BiReportEditorProvider get _provider => biReportEditorProvider(widget.seed);
  BiReportEditor get _editor => ref.read(_provider.notifier);

  FocusNode _node(String id) =>
      _nodes.putIfAbsent(id, () => FocusNode(debugLabel: 'bi-visual-$id'));

  @override
  void dispose() {
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  /// Focus on the selected visual once the frame that shows it is built.
  void _focusSelected() {
    final id = ref.read(_provider).selected;
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nodes[id]?.requestFocus();
    });
  }

  /// Runs [command]; the moved or new visual keeps (or takes) the focus,
  /// and a refusal is said aloud.
  void _run(BiEdit Function(BiReportDefinition report, int page) command) {
    _editor.run(command);
    _afterCommand();
  }

  void _afterCommand() {
    final s = ref.read(_provider);
    final l10n = context.l10n;
    final reason = s.refusal != null
        ? biEditRefusalText(l10n, s.refusal!)
        : s.binding != null
        ? biBindingRefusalText(l10n, s.binding!)
        : null;
    if (reason != null) {
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          reason,
          Directionality.of(context),
        ),
      );
    }
    _focusSelected();
  }

  bool _onKey(String id, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final key = event.logicalKey;
    final keys = HardwareKeyboard.instance;
    final step = switch (key) {
      LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.arrowLeft => -1,
      LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.arrowRight => 1,
      _ => 0,
    };
    final horizontal =
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;
    if (step != 0 && keys.isAltPressed) {
      _run((r, p) => biMoveVisualBy(r, p, id, step));
    } else if (step != 0 && keys.isShiftPressed) {
      _run(
        (r, p) => horizontal
            ? biResizeVisual(r, p, id, span: step)
            : biResizeVisual(r, p, id, height: step),
      );
    } else if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      _run((r, p) => biDeleteVisual(r, p, id));
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      _editor.show(selected: id);
    } else {
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    await _editor.save();
    _afterSave();
  }

  /// The draft as a new view (Save copy: private; Publish: the team's),
  /// then opened in its own editor; the report it came from is unchanged.
  Future<void> _copy({BiViewScope scope = BiViewScope.private}) async {
    final l10n = context.l10n;
    final router = GoRouter.of(context);
    final name = scope == BiViewScope.private
        ? l10n.biReportCopyName(ref.read(_provider).name.trim())
        : ref.read(_provider).name.trim();
    final copy = await _editor.saveCopy(name, scope: scope);
    if (!mounted || copy == null) {
      _afterSave();
      return;
    }
    _leaving = true;
    unawaited(router.replace<void>('/bi/report/${copy.id}'));
  }

  void _afterSave() {
    if (!mounted) return;
    final s = ref.read(_provider);
    final l10n = context.l10n;
    final text = switch (s.save) {
      BiEditorSave.idle when !s.dirty => l10n.biEditorSaved,
      BiEditorSave.conflict => l10n.biEditorConflict,
      BiEditorSave.lost => l10n.biReportSaveFailed,
      _ => null,
    };
    if (text == null) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        text,
        Directionality.of(context),
      ),
    );
  }

  Future<void> _leave() async {
    final navigator = Navigator.of(context);
    final choice = await _showLeaveDialog(context);
    if (!mounted || choice == null) return;
    if (choice == _LeaveChoice.save) {
      final saved = await _editor.save();
      if (saved == null) {
        _afterSave();
        return;
      }
    }
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.canPop()) navigator.pop();
    });
  }

  Future<void> _sheet(Widget Function(BuildContext) builder) async {
    await showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.gutterAll,
          child: builder(context),
        ),
      ),
    );
    _focusSelected();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(_provider);
    final canShare = biCanShareViews(ref.watch(myPermissionsProvider));
    return PopScope(
      canPop: _leaving || !s.dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: CallbackShortcuts(
        bindings: _shortcuts(),
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: _appBar(s, canShare: canShare),
            body: LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth >= _wideLayout
                  ? _wide(s)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _centre(s)),
                        if (!s.preview) _compactBar(),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts() => {
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
        _redo,
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
        _redo,
    const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
    const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
    const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
  };

  void _undo() {
    _editor.undo();
    _focusSelected();
  }

  void _redo() {
    _editor.redo();
    _focusSelected();
  }

  PreferredSizeWidget _appBar(BiEditorState s, {required bool canShare}) {
    final l10n = context.l10n;
    final saving = s.save == BiEditorSave.saving;
    return AppBar(
      leading: IconButton(
        key: const ValueKey('bi-editor-cancel'),
        tooltip: l10n.biEditorClose,
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(s.name, key: const ValueKey('bi-editor-name')),
      actions: [
        IconButton(
          key: const ValueKey('bi-editor-undo'),
          tooltip: l10n.biEditorUndo,
          icon: const Icon(Icons.undo),
          onPressed: s.canUndo ? _undo : null,
        ),
        IconButton(
          key: const ValueKey('bi-editor-redo'),
          tooltip: l10n.biEditorRedo,
          icon: const Icon(Icons.redo),
          onPressed: s.canRedo ? _redo : null,
        ),
        IconButton(
          key: const ValueKey('bi-editor-preview'),
          tooltip: s.preview ? l10n.biEditorBackToEdit : l10n.biEditorPreview,
          isSelected: s.preview,
          icon: const Icon(Icons.visibility_outlined),
          selectedIcon: const Icon(Icons.edit_outlined),
          onPressed: () => _editor.preview(on: !s.preview),
        ),
        IconButton(
          key: const ValueKey('bi-editor-save'),
          tooltip: l10n.biViewSave,
          icon: const Icon(Icons.save_outlined),
          onPressed: s.dirty && !saving && s.save != BiEditorSave.conflict
              ? _save
              : null,
        ),
        PopupMenuButton<BiViewScope>(
          key: const ValueKey('bi-editor-more'),
          tooltip: l10n.biEditorMore,
          enabled: !saving,
          onSelected: (scope) => _copy(scope: scope),
          itemBuilder: (context) => [
            PopupMenuItem(
              key: const ValueKey('bi-editor-save-copy'),
              value: BiViewScope.private,
              child: Text(l10n.biEditorSaveCopy),
            ),
            if (canShare && s.base.scope == BiViewScope.private)
              PopupMenuItem(
                key: const ValueKey('bi-editor-publish'),
                value: BiViewScope.workspace,
                child: Text(l10n.biEditorPublish),
              ),
          ],
        ),
      ],
    );
  }

  Widget _canvas(BiEditorState s) => BiReportCanvas(
    workspaceId: widget.seed.workspaceId,
    report: s.report,
    page: s.page,
    selection: s.selection,
    onSelection: _editor.select,
    onKeepSelection: s.preview ? null : (_) => _keep(),
    onKeepForReport: s.preview ? null : (_) => _keep(forReport: true),
    editing: s.preview
        ? null
        : BiCanvasEditing(
            selected: s.selected,
            onSelect: (id) => _editor.show(selected: id),
            onKey: _onKey,
            focusNode: _node,
          ),
  );

  void _keep({bool forReport = false}) {
    _editor.keepSelection(forReport: forReport);
    _afterCommand();
  }

  Widget _centre(BiEditorState s) => ListView(
    key: const ValueKey('bi-editor-canvas'),
    padding: AppSpacing.gutterAll,
    children: [
      BiEditorNotices(provider: _provider, onCopy: _copy),
      BiFilterPane(
        workspaceId: widget.seed.workspaceId,
        report: s.report,
        page: s.page,
        editable: !s.preview,
        onRemove: (page, index) {
          _editor.removeFilter(page: page, index: index);
          _afterCommand();
        },
      ),
      if (s.report.pages.length > 1)
        BiPageTabs(
          report: s.report,
          page: s.page,
          onPage: (i) => _editor.show(page: i),
        ),
      _canvas(s),
    ],
  );

  Widget _wide(BiEditorState s) {
    if (s.preview) return _centre(s);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: _sideWidth,
          child: SingleChildScrollView(
            padding: AppSpacing.mdAll,
            child: BiPagesPanel(provider: _provider, onCommand: _afterCommand),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _centre(s)),
        const VerticalDivider(width: 1),
        SizedBox(
          width: _sideWidth,
          child: SingleChildScrollView(
            padding: AppSpacing.mdAll,
            child: BiPropertiesPanel(
              workspaceId: widget.seed.workspaceId,
              provider: _provider,
              onCommand: _afterCommand,
            ),
          ),
        ),
      ],
    );
  }

  Widget _compactBar() {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('bi-editor-open-pages'),
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: Text(l10n.biEditorPagesAndVisuals),
              onPressed: () => _sheet(
                (_) =>
                    BiPagesPanel(provider: _provider, onCommand: _afterCommand),
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('bi-editor-open-properties'),
              icon: const Icon(Icons.tune),
              label: Text(l10n.biEditorProperties),
              onPressed: () => _sheet(
                (_) => BiPropertiesPanel(
                  workspaceId: widget.seed.workspaceId,
                  provider: _provider,
                  onCommand: _afterCommand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the person chose when leaving with unsaved changes.
enum _LeaveChoice { save, discard }

/// Save / Discard / Keep editing; null (Keep editing, or the question
/// dismissed) saves nothing and stays.
Future<_LeaveChoice?> _showLeaveDialog(BuildContext context) {
  final l10n = context.l10n;
  return showDialog<_LeaveChoice>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('bi-editor-leave'),
      title: Text(l10n.biEditorLeaveTitle),
      content: Text(l10n.biEditorLeaveBody),
      actions: [
        TextButton(
          key: const ValueKey('bi-editor-keep-editing'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.biEditorKeepEditing),
        ),
        TextButton(
          key: const ValueKey('bi-editor-discard'),
          onPressed: () => Navigator.of(context).pop(_LeaveChoice.discard),
          child: Text(l10n.biEditorDiscard),
        ),
        FilledButton(
          key: const ValueKey('bi-editor-leave-save'),
          onPressed: () => Navigator.of(context).pop(_LeaveChoice.save),
          child: Text(l10n.biViewSave),
        ),
      ],
    ),
  );
}
