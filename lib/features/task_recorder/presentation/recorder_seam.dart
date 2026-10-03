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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/trace/trace_logger.dart';
import '../application/recorder_controller.dart';
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
}) {
  try {
    _live(ref)?.record(actionId, target: target, payload: payload);
  } catch (e, st) {
    TraceLogger.instance.warn('recorder', 'step not recorded', stackTrace: st);
  }
}

/// A command's attempt, recorded BEFORE the command runs. Resolve it
/// with what the command actually returned or threw; it needs no
/// [WidgetRef] then, so a screen that closed meanwhile still answers.
class TaskAttempt {
  TaskAttempt._(this._controller, this._token);

  final RecorderController _controller;
  final OperationToken _token;

  /// Attaches the outcome. Never throws; a late answer from an older
  /// recording is dropped by the controller.
  void resolve(String outcomeId, {Map<String, Object?> payload = const {}}) {
    try {
      _controller.outcome(_token, outcomeId, payload: payload);
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

/// Null when nothing is recording; the command runs regardless.
TaskAttempt? recordTaskAttempt(
  WidgetRef ref,
  String actionId, {
  Map<String, Object?> payload = const {},
}) {
  try {
    final controller = _live(ref);
    final token = controller?.attempt(actionId, payload: payload);
    return token == null ? null : TaskAttempt._(controller!, token);
  } catch (e, st) {
    TraceLogger.instance.warn(
      'recorder',
      'attempt not recorded',
      stackTrace: st,
    );
    return null;
  }
}
