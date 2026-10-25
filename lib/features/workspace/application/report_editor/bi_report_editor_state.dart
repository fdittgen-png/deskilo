// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The report editor's one immutable state: the report as it was read (the
// revision a save names), the draft, the page and visual on screen, the
// history Undo and Redo walk, and what the last save answered. Nothing here
// holds a figure: the draft is a question, the answers stay in the query
// providers, so a permission change empties the answers and keeps the
// draft.
//
// Pure Dart.
library;

import 'dart:convert';

import 'package:meta/meta.dart';

import '../../domain/bi_report_definition.dart';
import '../../domain/bi_report_rules.dart';
import '../../domain/bi_report_selection.dart';
import '../../domain/bi_saved_view.dart';
import 'bi_report_commands.dart';

/// What the editor was opened on: a workspace and a saved report at one
/// revision. Two openings of the same revision are the same editor.
@immutable
class BiReportEditorSeed {
  const BiReportEditorSeed(this.workspaceId, this.view);

  /// The workspace the report was read in; every save names it.
  final String workspaceId;
  final BiSavedView view;

  @override
  bool operator ==(Object other) =>
      other is BiReportEditorSeed &&
      other.workspaceId == workspaceId &&
      other.view.id == view.id &&
      other.view.revision == view.revision;

  @override
  int get hashCode => Object.hash(workspaceId, view.id, view.revision);
}

/// Where the last save stands.
enum BiEditorSave {
  /// Nothing sent since the last change.
  idle,

  /// A save is on its way; another one is not sent meanwhile.
  saving,

  /// Someone saved the report since this draft was read: reload it or keep
  /// the draft as a private copy — never an overwrite.
  conflict,

  /// The answer was lost; Retry resends the same request.
  lost,

  /// The server refused the save ([BiEditorState.failure] says why).
  refused,
}

/// One step of the history: what Undo returns to.
@immutable
class BiEditorStep {
  const BiEditorStep(this.report, this.page, this.selected);

  final BiReportDefinition report;
  final int page;
  final String? selected;
}

@immutable
class BiEditorState {
  const BiEditorState({
    required this.base,
    required this.report,
    required this.name,
    this.page = 0,
    this.selected,
    this.past = const [],
    this.future = const [],
    this.save = BiEditorSave.idle,
    this.failure,
    this.requestId,
    this.refusal,
    this.binding,
    this.coalesce,
    this.selection,
    this.preview = false,
  });

  /// The editor on [view] as read: the draft is the stored report.
  factory BiEditorState.of(BiSavedView view) => BiEditorState(
    base: view,
    report: view.definition!.report!,
    name: view.name,
  );

  /// The report as read; its revision is what a save names.
  final BiSavedView base;

  /// The draft.
  final BiReportDefinition report;
  final String name;
  final int page;

  /// The visual whose properties are shown, and which keyboard moves act on.
  final String? selected;
  final List<BiEditorStep> past;
  final List<BiEditorStep> future;
  final BiEditorSave save;
  final BiViewFailure? failure;

  /// The request a Retry resends; cleared once answered or changed.
  final String? requestId;

  /// Why the last command did nothing, to be said once.
  final BiEditRefusal? refusal;
  final BiBindingRefusal? binding;

  /// The key of the last command that merges with the next one of the same
  /// key (typing a title is one step, not one per letter).
  final String? coalesce;

  /// The group picked on the page on screen: local to it, never saved and
  /// never part of the history.
  final BiReportSelection? selection;

  /// The report as its readers see it: no selection frame, no properties.
  final bool preview;

  BiReportPage get currentPage => report.pages[page];

  BiReportVisual? get selectedVisual => selected == null
      ? null
      : currentPage.visuals.where((v) => v.id == selected).firstOrNull;

  bool get canUndo => past.isNotEmpty;
  bool get canRedo => future.isNotEmpty;

  /// Whether the draft or its name differ from what was read.
  bool get dirty =>
      name.trim() != base.name ||
      jsonEncode(report.toJson()) !=
          jsonEncode(base.definition?.report?.toJson());

  BiEditorStep get _step => BiEditorStep(report, page, selected);

  /// The state after [edit]: a new step in the history (or, with the same
  /// [coalesceKey] as the last change, the same step updated), or the reason
  /// nothing changed.
  BiEditorState applied(BiEdit edit, {String? coalesceKey}) {
    final next = edit.report;
    if (next == null) {
      return BiEditorState._from(
        this,
        refusal: edit.refusal,
        binding: edit.binding,
      );
    }
    final merge = coalesceKey != null && coalesceKey == coalesce;
    final history = merge ? past : [...past, _step];
    return BiEditorState._from(
      this,
      report: next,
      page: edit.page ?? page,
      selected: edit.selected ?? selected,
      // The whole session's history: each step is a bounded report (the
      // space's byte limit), and a run of typing is one step.
      past: history,
      future: const [],
      coalesce: coalesceKey,
      // A conflict stays until the person resolves it; an edit is not that.
      save: save == BiEditorSave.saving || save == BiEditorSave.conflict
          ? save
          : BiEditorSave.idle,
      clearRequest: true,
    );
  }

  BiEditorState undone() {
    if (!canUndo) return this;
    final last = past.last;
    return BiEditorState._from(
      this,
      report: last.report,
      page: last.page.clamp(0, last.report.pages.length - 1),
      selected: last.selected,
      past: past.sublist(0, past.length - 1),
      future: [_step, ...future],
      clearRequest: true,
    );
  }

  BiEditorState redone() {
    if (!canRedo) return this;
    final next = future.first;
    return BiEditorState._from(
      this,
      report: next.report,
      page: next.page.clamp(0, next.report.pages.length - 1),
      selected: next.selected,
      past: [...past, _step],
      future: future.sublist(1),
      clearRequest: true,
    );
  }

  BiEditorState withName(String value) => BiEditorState._from(
    this,
    name: value,
    coalesce: 'name',
    clearRequest: true,
  );

  /// Page [page] and/or visual [selected] on screen. Another page drops
  /// the selection made on this one.
  BiEditorState shown({int? page, String? selected}) {
    final p = (page ?? this.page).clamp(0, report.pages.length - 1);
    return BiEditorState._from(
      this,
      page: p,
      selected: selected,
      clearSelected: page != null && selected == null,
      clearSelection: p != this.page,
    );
  }

  BiEditorState withSelection(BiReportSelection? value) => BiEditorState._from(
    this,
    selection: value,
    clearSelection: value == null,
  );

  BiEditorState withPreview({required bool on}) =>
      BiEditorState._from(this, preview: on);

  BiEditorState withSave(
    BiEditorSave save, {
    BiViewFailure? failure,
    String? requestId,
    BiSavedView? base,
  }) => BiEditorState(
    base: base ?? this.base,
    report: report,
    name: name,
    page: page,
    selected: selected,
    past: past,
    future: future,
    save: save,
    failure: failure,
    requestId: requestId,
    coalesce: coalesce,
    selection: selection,
    preview: preview,
  );

  /// [o] with the parts named replaced; a `clear…` flag empties its part,
  /// and the one-shot refusal, binding and coalescing key are not carried.
  BiEditorState._from(
    BiEditorState o, {
    BiReportDefinition? report,
    String? name,
    int? page,
    String? selected,
    bool clearSelected = false,
    List<BiEditorStep>? past,
    List<BiEditorStep>? future,
    BiEditorSave? save,
    this.refusal,
    this.binding,
    this.coalesce,
    bool clearRequest = false,
    BiReportSelection? selection,
    bool clearSelection = false,
    bool? preview,
  }) : base = o.base,
       report = report ?? o.report,
       name = name ?? o.name,
       page = page ?? o.page,
       selected = clearSelected ? null : selected ?? o.selected,
       past = past ?? o.past,
       future = future ?? o.future,
       save = save ?? o.save,
       failure = o.failure,
       requestId = clearRequest ? null : o.requestId,
       selection = clearSelection ? null : selection ?? o.selection,
       preview = preview ?? o.preview;
}
