// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The report editor's controller: the commands change the one immutable
// state; Save writes the draft to the saved-definitions store (0588) against
// the revision it was read at, in the workspace it was read in, under one
// request id that a Retry resends — so a timeout followed by a retry is one
// revision, a save that lost the race is a conflict the person resolves
// (reload, or keep the draft as a private copy), and nothing is ever
// overwritten silently. Save copy and Publish write NEW views; the report
// they were made from is untouched. A refusal never discards the draft.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/ids/request_id.dart';
import '../../../../core/settings/active_settings.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../domain/bi_report_definition.dart';
import '../../domain/bi_report_limits.dart';
import '../../domain/bi_report_selection.dart';
import '../../domain/bi_saved_view.dart';
import '../../providers/bi_providers.dart';
import '../../providers/workspace_providers.dart';
import 'bi_report_commands.dart';
import 'bi_report_editor_state.dart';

part 'bi_report_editor.g.dart';

@riverpod
class BiReportEditor extends _$BiReportEditor {
  @override
  BiEditorState build(BiReportEditorSeed seed) => BiEditorState.of(seed.view);

  /// The space's report limits.
  BiReportLimits get _limits =>
      BiReportLimits.fromSettings(ref.read(activeSettingsProvider));

  /// Runs [command] on the draft and the page on screen; with [coalesce],
  /// a run of the same key is one step of the history.
  void run(
    BiEdit Function(BiReportDefinition report, int page) command, {
    String? coalesce,
  }) => state = state.applied(
    command(state.report, state.page),
    coalesceKey: coalesce,
  );

  void undo() => state = state.undone();

  void redo() => state = state.redone();

  void rename(String name) => state = state.withName(name);

  /// Shows page [page] and/or selects visual [selected].
  void show({int? page, String? selected}) =>
      state = state.shown(page: page, selected: selected);

  /// Picks (or, with null, resets) the selection of the page on screen.
  void select(BiReportSelection? selection) =>
      state = state.withSelection(selection);

  void preview({required bool on}) => state = state.withPreview(on: on);

  /// Keeps the page's selection as a filter of the page, or with
  /// [forReport] of every page — an explicit choice, saved with the report —
  /// and clears the temporary selection.
  void keepSelection({bool forReport = false}) {
    final picked = state.selection;
    if (picked == null) return;
    run(
      (report, page) => forReport
          ? biAddReportFilter(report, picked.filter)
          : biAddPageFilter(report, page, picked.filter),
    );
    if (state.refusal == null) state = state.withSelection(null);
  }

  /// Limits visual [id] alone to the page's selection, then clears it.
  void keepSelectionOn(String id) {
    final picked = state.selection;
    if (picked == null) return;
    run((report, page) => biAddVisualFilter(report, page, id, picked.filter));
    if (state.refusal == null) state = state.withSelection(null);
  }

  /// Removes filter [index] of the report ([page] null) or of page [page].
  void removeFilter({required int? page, required int index}) =>
      run((report, _) => biRemoveFilter(report, page, index));

  /// Whether the workspace on screen is still the one the report was read
  /// in: a save never lands in another workspace.
  bool get _sameWorkspace =>
      ref.read(currentWorkspaceProvider).value?.id == seed.workspaceId;

  /// Saves the draft over the report at the revision it was read at. The
  /// saved view, or null when it was not saved (the state says why).
  Future<BiSavedView?> save() async {
    final s = state;
    if (!s.dirty || s.save == BiEditorSave.saving) return null;
    if (s.save == BiEditorSave.conflict) return null;
    final requestId = s.requestId ?? newRequestId();
    return _write(
      requestId,
      over: s.base,
      scope: s.base.scope,
      name: s.name.trim(),
      report: s.report,
    );
  }

  /// The draft as a NEW view named [name], private unless [scope] says the
  /// workspace's (Publish); the report it came from is left as it was.
  Future<BiSavedView?> saveCopy(
    String name, {
    BiViewScope scope = BiViewScope.private,
  }) {
    if (state.save == BiEditorSave.saving) return Future.value();
    return _write(
      state.requestId ?? newRequestId(),
      scope: scope,
      name: name.trim(),
      report: state.report,
      copy: true,
    );
  }

  /// Drops the draft and reads the report as it is now.
  Future<void> reload() async {
    final ws = seed.workspaceId;
    final id = state.base.id;
    ref.invalidate(biViewsProvider(ws));
    try {
      final views = await ref.read(biViewsProvider(ws).future);
      final latest = views.where((v) => v.id == id).firstOrNull;
      if (!ref.mounted) return;
      if (latest?.definition?.report == null) {
        state = state.withSave(
          BiEditorSave.refused,
          failure: BiViewFailure.forbidden,
        );
        return;
      }
      state = BiEditorState.of(latest!);
    } on Exception catch (e, st) {
      TraceLogger.instance.warn(
        'bi',
        'report reload failed',
        error: e,
        stackTrace: st,
      );
      if (ref.mounted) state = state.withSave(BiEditorSave.lost);
    }
  }

  /// The last write whose answer was lost, to resend as the same request.
  Future<BiSavedView?> Function()? _lost;

  /// Resends the write whose answer was lost, under its request id.
  Future<BiSavedView?> retry() async =>
      state.save == BiEditorSave.lost ? await _lost?.call() : null;

  Future<BiSavedView?> _write(
    String requestId, {
    BiSavedView? over,
    required BiViewScope scope,
    required String name,
    required BiReportDefinition report,
    bool copy = false,
  }) async {
    if (!_sameWorkspace) {
      state = state.withSave(
        BiEditorSave.refused,
        failure: BiViewFailure.forbidden,
      );
      return null;
    }
    if (name.isEmpty || !_limits.admits(report)) {
      state = state.withSave(
        BiEditorSave.refused,
        failure: BiViewFailure.invalid,
      );
      return null;
    }
    final before = state.save;
    state = state.withSave(BiEditorSave.saving, requestId: requestId);
    try {
      final saved = await ref
          .read(biViewActionsProvider)
          .save(
            seed.workspaceId,
            over: over,
            scope: scope,
            name: name,
            definition: BiViewDefinition.ofReport(report),
            requestId: requestId,
          );
      if (!ref.mounted) return saved;
      state = copy
          ? state.withSave(
              before == BiEditorSave.conflict ? before : BiEditorSave.idle,
            )
          : state.withSave(BiEditorSave.idle, base: saved);
      return saved;
    } on BiViewRefused catch (e, st) {
      TraceLogger.instance.warn(
        'bi',
        'report save refused: ${e.failure.name}',
        error: e,
        stackTrace: st,
      );
      if (ref.mounted) {
        state = e.failure == BiViewFailure.stale && !copy
            ? state.withSave(BiEditorSave.conflict)
            : state.withSave(BiEditorSave.refused, failure: e.failure);
      }
    } on Exception catch (e, st) {
      TraceLogger.instance.warn(
        'bi',
        'report save not answered',
        error: e,
        stackTrace: st,
      );
      if (ref.mounted) {
        state = state.withSave(BiEditorSave.lost, requestId: requestId);
        _lost = () => _write(
          requestId,
          over: over,
          scope: scope,
          name: name,
          report: report,
          copy: copy,
        );
      }
    }
    return null;
  }
}
