// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A setup step's answers saved as a draft while the person edits them,
// once they pause. "Saved" is said only after the server answered. A
// save whose answer never came is sent again under the SAME request id,
// so the server answers its first write instead of counting it twice;
// newer edits follow under a new one. Every save is made against the
// version last read or written, and a draft another configurer moved is
// reported with their answers — the person reloads or keeps theirs, and
// nothing is overwritten without that choice. Leaving the page sends what
// is still pending.
import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/ids/request_id.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_durations.dart';
import '../domain/local_setup.dart';
import '../domain/setup_step_draft.dart';
import '../providers/local_setup_providers.dart';

part 'setup_draft_autosave.g.dart';

/// Where the step's draft stands.
sealed class SetupDraftState {
  const SetupDraftState();
}

/// Nothing to save, or nothing saved yet.
class SetupDraftIdle extends SetupDraftState {
  const SetupDraftIdle();
}

/// A save is on its way.
class SetupDraftSaving extends SetupDraftState {
  const SetupDraftSaving();
}

/// The server confirmed the draft written at [at].
class SetupDraftSaved extends SetupDraftState {
  const SetupDraftSaved(this.at);
  final DateTime at;
}

/// The last save got no answer; [SetupDraftAutosave.retry] sends it again.
class SetupDraftFailed extends SetupDraftState {
  const SetupDraftFailed(this.error);
  final Object error;
}

/// Another configurer changed the draft: [theirs] is what the server holds
/// now (null when they discarded it).
class SetupDraftConflicted extends SetupDraftState {
  const SetupDraftConflicted(this.theirs);
  final SetupStepDraft? theirs;
}

/// One write: what was sent, under which id, against which version.
typedef _Attempt = ({
  Map<String, Object?> payload,
  String requestId,
  int? expectedVersion,
});

/// The draft of one setup [step] of one workspace.
@riverpod
class SetupDraftAutosave extends _$SetupDraftAutosave {
  late LocalSetupRepository _repository;
  late String _workspaceId;
  late String _step;
  Timer? _timer;

  /// The last state set, readable after the page stopped listening.
  SetupDraftState _last = const SetupDraftIdle();

  /// The version the next write is made against; null: no draft.
  int? _version;

  /// Sent and not answered: sent again, unchanged, before anything newer.
  _Attempt? _unconfirmed;

  /// The newest answers not sent yet.
  Map<String, Object?>? _pending;

  /// What was being saved when the conflict was found.
  Map<String, Object?>? _mine;

  Future<void>? _draining;

  @override
  SetupDraftState build(String workspaceId, String step) {
    _repository = ref.watch(localSetupRepositoryProvider);
    _workspaceId = workspaceId;
    _step = step;
    ref.onDispose(() {
      _timer?.cancel();
      if (_last is! SetupDraftConflicted) unawaited(_drain());
    });
    return _last = const SetupDraftIdle();
  }

  /// The draft the server holds, remembered as the version to write
  /// against. Null when there is none.
  Future<SetupStepDraft?> load() async {
    final draft = await _repository.stepDraft(_workspaceId, _step);
    _version = draft?.version;
    return draft;
  }

  /// The person changed the answers: saved once they pause.
  void changed(Map<String, Object?> answers) {
    _pending = answers;
    if (_last is SetupDraftConflicted) return;
    _timer?.cancel();
    _timer = Timer(AppDurations.draftAutosave, () => unawaited(_drain()));
  }

  /// Sends the failed save again, under its own request id.
  Future<void> retry() {
    _timer?.cancel();
    return _drain();
  }

  /// After a conflict: writes the person's answers over the draft the
  /// server holds now, against its version.
  Future<void> keepMine() {
    final conflict = _last;
    if (conflict is! SetupDraftConflicted) return Future.value();
    _version = conflict.theirs?.version;
    _pending ??= _mine;
    _mine = null;
    return _drain();
  }

  /// After a conflict: the person took the other configurer's answers.
  void reloaded() {
    final conflict = _last;
    if (conflict is! SetupDraftConflicted) return;
    _version = conflict.theirs?.version;
    _pending = null;
    _mine = null;
    _set(const SetupDraftIdle());
  }

  /// Drops the draft: the person discarded it, or the step's own command
  /// applied the answers. Pending edits are dropped; a save that got no
  /// answer is settled first, so the discard is made against the version
  /// it really wrote. False when there was no draft to drop.
  Future<bool> discard() async {
    _timer?.cancel();
    _pending = null;
    await _draining;
    if (_unconfirmed != null) await _drain();
    if (_unconfirmed != null) return false;
    try {
      final dropped = await _repository.discardStepDraft(
        _workspaceId,
        _step,
        expectedVersion: _version,
      );
      _version = null;
      _set(const SetupDraftIdle());
      return dropped;
    } on SetupDraftConflict catch (e, st) {
      TraceLogger.instance.warn(
        'workspace',
        'setup draft moved before its '
            'discard',
        error: e,
        stackTrace: st,
      );
      await _conflicted();
      return false;
    }
  }

  Future<void> _drain() => _draining ??= _send().whenComplete(() {
    _draining = null;
  });

  Future<void> _send() async {
    while (true) {
      final pending = _pending;
      final attempt =
          _unconfirmed ??
          (pending == null
              ? null
              : (
                  payload: pending,
                  requestId: newRequestId(),
                  expectedVersion: _version,
                ));
      if (attempt == null) return;
      if (identical(attempt.payload, pending)) _pending = null;
      _unconfirmed = attempt;
      _set(const SetupDraftSaving());
      try {
        final saved = await _repository.saveStepDraft(
          _workspaceId,
          _step,
          payload: attempt.payload,
          expectedVersion: attempt.expectedVersion,
          requestId: attempt.requestId,
        );
        _unconfirmed = null;
        _version = saved.version;
        _set(SetupDraftSaved(saved.updatedAt));
      } on SetupDraftConflict catch (e, st) {
        TraceLogger.instance.warn(
          'workspace',
          'setup draft changed by '
              'someone else',
          error: e,
          stackTrace: st,
        );
        _unconfirmed = null;
        _mine = _pending ?? attempt.payload;
        _pending = null;
        await _conflicted();
        return;
      } on Object catch (e, st) {
        TraceLogger.instance.warn(
          'workspace',
          'setup draft not saved',
          error: e,
          stackTrace: st,
        );
        _set(SetupDraftFailed(e));
        return;
      }
    }
  }

  /// Reads what the other configurer left, to show beside the conflict.
  Future<void> _conflicted() async {
    SetupStepDraft? theirs;
    try {
      theirs = await _repository.stepDraft(_workspaceId, _step);
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'workspace',
        'setup draft conflict could not '
            'be read',
        error: e,
        stackTrace: st,
      );
    }
    _set(SetupDraftConflicted(theirs));
  }

  /// Leaving the page does not stop a save on its way; only the screen
  /// stops listening.
  void _set(SetupDraftState next) {
    _last = next;
    if (ref.mounted) state = next;
  }
}
