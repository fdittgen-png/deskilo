// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1867 — following a guide: a pure state machine fed by what really
// happens on the forms.
//
// It advances on actual events only. Doing the registered action of a
// plain step completes it; doing a command's action only ATTEMPTS it —
// the step waits for the command's real outcome, and only an expected
// outcome completes it. A refusal enters the step's recovery, then
// returns to the same step; a lost answer leaves the step uncertain,
// asking the person to check before trying again. Instructions and
// manual steps are acknowledged, never "verified". Skipping marks a
// step skipped, never done. Back, stop and pause never undo or repeat a
// command, and nothing here enters a value or starts anything: the
// runner only listens.

import '../domain/action_registry.dart';
import 'task_guide.dart';

enum GuideStepStatus { pending, waiting, done, acknowledged, skipped }

enum GuideRunState { running, paused, completed, stopped }

class GuideRun {
  GuideRun(this.guide, {this.registry = recorderRegistry})
    : _status = {
        for (final s in guide.steps) ...{
          s.id: GuideStepStatus.pending,
          for (final r in s.recovery) r.id: GuideStepStatus.pending,
        },
      };

  final TaskGuide guide;
  final ActionRegistry registry;
  final Map<String, GuideStepStatus> _status;

  int _index = 0;
  int? _recoveryIndex;
  GuideRunState _state = GuideRunState.running;
  bool _uncertain = false;
  Object? _attempt;

  GuideRunState get state => _state;

  /// The last command's answer never came: the person should check
  /// whether it happened before trying again.
  bool get uncertain => _uncertain;

  GuideStepStatus statusOf(String stepId) =>
      _status[stepId] ?? GuideStepStatus.pending;

  GuideStep? get _main =>
      _index < guide.steps.length ? guide.steps[_index] : null;

  /// The step the person is on: a recovery step while recovering.
  GuideStep? get current {
    final main = _main;
    final r = _recoveryIndex;
    if (main == null || r == null) return main;
    return main.recovery[r];
  }

  bool get _live => _state == GuideRunState.running;

  /// The person did [actionId] on a form — on [target] when the recorder
  /// could name the control. A step that names its control completes only
  /// on that control: the same kind of tap elsewhere is not this step.
  Object? onAction(String actionId, {String? target}) {
    final step = current;
    if (!_live || step == null || step.kind != GuideStepKind.perform) {
      return null;
    }
    if (step.action != actionId) return null;
    if (step.target != null && step.target != target) return null;
    if (_status[step.id] == GuideStepStatus.waiting) return null;
    if (step.isCommand) {
      // A tap is not a booking: wait for what the command answers.
      _status[step.id] = GuideStepStatus.waiting;
      _uncertain = false;
      return _attempt = Object();
    } else {
      _complete(step, GuideStepStatus.done);
    }
    return null;
  }

  /// The command the current step waits for answered [outcomeId].
  void onOutcome(String outcomeId, {required Object? token}) {
    final step = current;
    if (!_live ||
        step == null ||
        token == null ||
        !identical(token, _attempt)) {
      return;
    }
    if (_status[step.id] != GuideStepStatus.waiting) return;
    _attempt = null;
    if (step.expectedOutcomes.contains(outcomeId)) {
      _complete(step, GuideStepStatus.done);
      return;
    }
    final state = registry.outcome(outcomeId)?.state;
    _status[step.id] = GuideStepStatus.pending;
    if (state == ObservationState.refused &&
        _recoveryIndex == null &&
        step.recovery.isNotEmpty) {
      _recoveryIndex = 0;
    } else if (state == ObservationState.outcomeUnknown) {
      _uncertain = true;
    }
  }

  /// The person read an instruction or did a manual step.
  void acknowledge() {
    final step = current;
    if (!_live || step == null) return;
    if (step.kind == GuideStepKind.perform) return;
    _complete(step, GuideStepStatus.acknowledged);
  }

  /// The person chose to skip. Skipped is never done.
  void skip() {
    final step = current;
    if (!_live || step == null) return;
    if (_status[step.id] == GuideStepStatus.waiting) return;
    _complete(step, GuideStepStatus.skipped);
  }

  /// Shows the previous main step again. Nothing is undone or repeated.
  void back() {
    if (!_live) return;
    _abandonAttempt();
    if (_recoveryIndex != null) {
      _recoveryIndex = null;
      return;
    }
    if (_index > 0) _index--;
  }

  /// Inspect or revisit any step without marking intervening steps complete
  /// and without abandoning an in-flight command.
  void visit(String id) {
    if (!_live ||
        current != null && statusOf(current!.id) == GuideStepStatus.waiting) {
      return;
    }
    final index = guide.steps.indexWhere((s) => s.id == id);
    if (index < 0) return;
    _index = index;
    _recoveryIndex = null;
  }

  /// The account, workspace or feature changed under the guide.
  void pause() {
    if (_state == GuideRunState.running) {
      _abandonAttempt();
      _state = GuideRunState.paused;
    }
  }

  /// Resumes after a pause. A command that was waiting is not assumed to
  /// have happened: the step asks again.
  void resume() {
    if (_state != GuideRunState.paused) return;
    _state = GuideRunState.running;
    final step = current;
    if (step != null && _status[step.id] == GuideStepStatus.waiting) {
      _status[step.id] = GuideStepStatus.pending;
      _uncertain = true;
    }
  }

  void _abandonAttempt() {
    if (_attempt == null) return;
    _attempt = null;
    final step = current;
    if (step != null) _status[step.id] = GuideStepStatus.pending;
    _uncertain = true;
  }

  void stop() {
    _abandonAttempt();
    if (_state != GuideRunState.completed) _state = GuideRunState.stopped;
  }

  void _complete(GuideStep step, GuideStepStatus status) {
    _status[step.id] = status;
    _uncertain = false;
    final r = _recoveryIndex;
    if (r != null) {
      final main = _main!;
      if (r + 1 < main.recovery.length) {
        _recoveryIndex = r + 1;
      } else {
        // Recovery done: back to the command step, to try again.
        _recoveryIndex = null;
      }
      return;
    }
    _index++;
    while (_index < guide.steps.length &&
        _status[guide.steps[_index].id] != GuideStepStatus.pending) {
      _index++;
    }
    if (_index >= guide.steps.length) {
      final remaining = guide.steps.indexWhere(
        (s) => _status[s.id] == GuideStepStatus.pending,
      );
      if (remaining >= 0) {
        _index = remaining;
      } else {
        _state = GuideRunState.completed;
      }
    }
  }
}
