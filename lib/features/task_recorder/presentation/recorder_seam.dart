// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the registration seam: the three calls a screen makes to tell
// the recorder what happened. This is the whole adoption contract for a
// form (#1881/#1884 add identifiers to action_registry.dart and these
// calls at the callbacks that already exist):
//
//   recordTaskStep(ref, RecorderActions.selectDate, payload: {...});
//   final attempt = recordTaskAttempt(ref, RecorderActions.confirmBooking);
//   ...the command runs exactly as before...
//   attempt?.resolve(RecorderOutcomes.bookingConfirmed);
//
// Each call is synchronous, never throws, never awaits and changes
// nothing about the command beside it. When the recorder was never
// opened in this run (`ref.exists` is false) the call does not even
// create it: no provider, no store, no work on the screen's path.
//
// #1867 — the same calls tell a running guide what happened
// ([GuideEvents.sink]), recording or not: a guide follows the real
// action and outcome, never a guess. No guide, no work.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/trace/trace_logger.dart';
import '../../../core/validation/pending_validation.dart';
import '../application/booking_observation.dart' show errorObservation;
import '../application/recorder_controller.dart';
import '../guide/guide_session.dart';
import '../domain/action_registry.dart';
import '../domain/step_values.dart';
import '../providers/recorder_providers.dart';

RecorderController? _live(WidgetRef ref) =>
    ref.exists(recorderControllerProvider)
    ? ref.read(recorderControllerProvider)
    : null;

/// A non-command step: a navigation, a selection, a committed field.
void recordTaskStep(
  WidgetRef ref,
  String actionId, {
  String? target,
  Map<String, Object?> payload = const {},
  StepValues values = StepValues.none,
}) {
  try {
    _live(ref)?.record(
      actionId,
      target: target,
      payload: payload,
      values: values,
    );
  } catch (e, st) {
    TraceLogger.instance.warn('recorder', 'step not recorded', stackTrace: st);
  }
  try {
    GuideEvents.sink?.action(actionId, target: target);
  } catch (e, st) {
    TraceLogger.instance.warn('recorder', 'guide not told', stackTrace: st);
  }
}

/// A command's attempt, recorded BEFORE the command runs. Resolve it
/// with what the command actually returned or threw; it needs no
/// [WidgetRef] then, so a screen that closed meanwhile still answers.
class TaskAttempt {
  TaskAttempt._(this._controller, this._token, this._guide, this._guideToken);

  /// Null when only a guide listens (nothing is being recorded).
  final RecorderController? _controller;
  final OperationToken? _token;

  /// The guide that saw the attempt, told the outcome too (#1867).
  final GuideEventSink? _guide;
  final Object? _guideToken;

  /// Attaches the outcome. Never throws; a late answer from an older
  /// recording is dropped by the controller.
  void resolve(String outcomeId, {Map<String, Object?> payload = const {}}) {
    try {
      // The guide that saw the attempt, if it is still the running one.
      final guide = _guide;
      if (guide != null && identical(GuideEvents.sink, guide)) {
        guide.outcome(outcomeId, token: _guideToken);
      }
    } catch (e, st) {
      TraceLogger.instance.warn('recorder', 'guide not told', stackTrace: st);
    }
    try {
      _controller?.outcome(_token, outcomeId, payload: payload);
    } catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'outcome not recorded',
        stackTrace: st,
      );
    }
  }

  /// [resolve] with an observation from an adapter.
  void resolveWith(({String outcome, Map<String, Object?> payload}) o) =>
      resolve(o.outcome, payload: o.payload);
}

/// Null when nothing is recording and no guide runs; the command runs
/// regardless.
TaskAttempt? recordTaskAttempt(
  WidgetRef ref,
  String actionId, {
  String? target,
  Map<String, Object?> payload = const {},
  StepValues values = StepValues.none,
}) {
  GuideEventSink? guide;
  Object? guideToken;
  try {
    guide = GuideEvents.sink;
    guideToken = guide?.action(actionId, target: target);
  } catch (e, st) {
    TraceLogger.instance.warn('recorder', 'guide not told', stackTrace: st);
  }
  try {
    final controller = _live(ref);
    final token = controller?.attempt(
      actionId,
      target: target,
      payload: payload,
      values: values,
    );
    if (token == null && guide == null) return null;
    return TaskAttempt._(token == null ? null : controller, token, guide, guideToken);
  } catch (e, st) {
    TraceLogger.instance.warn(
      'recorder',
      'attempt not recorded',
      stackTrace: st,
    );
    return null;
  }
}

/// #1884 B — runs [command] for [attempt] and records its real result:
/// [done] when it returns, [pending] when a policy holds it for a
/// decision, [refused] or [unknown] as [errorObservation] reads the
/// error. The value or the error goes back to the caller unchanged, so
/// a guarded caller (runGuarded's snack, its bool) behaves as before;
/// with no recording, [command] simply runs.
Future<T> observeTaskCommand<T>(
  TaskAttempt? attempt,
  Future<T> Function() command, {
  required String done,
  required String pending,
  required String refused,
  required String unknown,
}) async {
  if (attempt == null) return command();
  try {
    final value = await command();
    attempt.resolve(done);
    return value;
  } on PendingValidationException {
    attempt.resolve(pending);
    rethrow;
    // ignore: catch_no_st — recorded, then rethrown for the caller.
  } catch (e) {
    attempt.resolveWith(
      errorObservation(e, refused: refused, unknown: unknown),
    );
    // The caller traces it, exactly as before.
    rethrow;
  }
}

/// A management form's save, observed with the setting outcomes.
Future<T> observeTaskSetting<T>(
  TaskAttempt? attempt,
  Future<T> Function() command,
) => observeTaskCommand(
  attempt,
  command,
  done: RecorderOutcomes.settingSaved,
  pending: RecorderOutcomes.settingPending,
  refused: RecorderOutcomes.settingNotSaved,
  unknown: RecorderOutcomes.settingUnknown,
);
