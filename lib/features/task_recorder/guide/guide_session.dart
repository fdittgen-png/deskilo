// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1867 — a guide being followed on the live app.
//
// The session holds ONE run of a reviewed guide and feeds it what really
// happens: the actions and outcomes the recorder's own capture already
// resolves (the screen seams of recorder_seam.dart and the generic layer
// of ui_capture.dart, #2142). They reach the session through
// [GuideEvents.sink] — the same static-hook idiom as `UiCapture.current`
// and `guardedCommandWatcher`, so there is no second event bus, and
// nothing is listened to while no guide runs.
//
// The run is bound to the scope it was started in (installation, account,
// workspace). When the scope changes, or the workspace turns the task
// recorder off, the run pauses with its reason; resuming rechecks both
// and a command step that was waiting is asked again, never assumed
// (guide_runner.dart). Nothing here enters a value or starts a command.

import 'package:deskilo_task_recording/deskilo_task_recording.dart'
    show ReplayCoordinator, ReplayRefusal, ReplayRequest, ReplayTicket;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/help/help_arbiter.dart';
import '../application/recorder_controller.dart' show RecorderScope;
import '../domain/action_registry.dart';
import '../providers/recorder_providers.dart';
import 'guide_destination.dart';
import 'guide_replay.dart';
import 'guide_runner.dart';
import 'task_guide.dart';

part 'guide_session.g.dart';

/// What the live capture tells a running guide.
abstract interface class GuideEventSink {
  Object? action(String actionId, {String? target});
  void outcome(String outcomeId, {required Object? token});
}

/// The running guide's event hook; null while no guide runs.
abstract final class GuideEvents {
  static GuideEventSink? sink;
}

/// Why a run is paused.
enum GuidePauseReason {
  /// The account, workspace or installation changed under the guide.
  scopeChanged,

  /// The workspace turned the task recorder off.
  featureOff,
}

class GuideSessionState {
  const GuideSessionState({
    this.run,
    this.pauseReason,
    this.revision = 0,
    this.refusal,
  });

  final GuideRun? run;
  final GuidePauseReason? pauseReason;

  /// Why the last command attempt was not counted: the host's current
  /// authority said no (role, workspace, feature). The command itself still
  /// answers for itself; the step simply stays where it is.
  final ReplayRefusal? refusal;

  /// Bumps on every change: the run itself is mutable.
  final int revision;

  bool get active =>
      run != null &&
      (run!.state == GuideRunState.running ||
          run!.state == GuideRunState.paused);

  TaskGuide? get guide => run?.guide;
}

@Riverpod(keepAlive: true)
class GuideSession extends _$GuideSession implements GuideEventSink {
  RecorderScope? _startScope;
  late ReplayCoordinator _replay;
  final Map<Object, ReplayTicket> _tickets = {};

  @override
  GuideSessionState build() {
    _replay = ReplayCoordinator(
      registry: recorderRegistry,
      authorizer: DeskiloReplayAuthorizer(() => ref.read(guideReplayFactsProvider)),
    );
    ref
      ..listen(recorderScopeProvider, (_, next) {
        if (next != _startScope) _pause(GuidePauseReason.scopeChanged);
      })
      ..listen(taskRecorderAvailableProvider, (_, on) {
        if (!on) _pause(GuidePauseReason.featureOff);
      })
      ..onDispose(_release);
    return const GuideSessionState();
  }

  /// Starts [guide] in the current scope. A guide that is not runnable
  /// (unknown actions, a newer contract) is refused by the caller's
  /// decoder before it gets here; a signed-out person cannot start one.
  bool start(TaskGuide guide) {
    final linked = linkedGuide(guide);
    if (linked == null) return false;
    final scope = ref.read(recorderScopeProvider);
    if (scope == null || !ref.read(taskRecorderAvailableProvider)) {
      return false;
    }
    _startScope = scope;
    GuideEvents.sink = this;
    _set(GuideRun(linked), pauseReason: null);
    return true;
  }

  // ── what really happened ──────────────────────────────────────────────

  @override
  Object? action(String actionId, {String? target}) {
    Object? token;
    ReplayRefusal? refusal;
    _change((run) {
      ReplayTicket? ticket;
      if (run.wouldAttemptCommand(actionId, target: target)) {
        // A guide step is not a permission: ask again, now, in the scope
        // the person is in at this moment.
        final now = _replay.authorizer.currentScope();
        final started = now == null
            ? null
            : _replay.begin(
                ReplayRequest(action: actionId, target: target),
                startedIn: now,
              );
        ticket = started?.ticket;
        if (ticket == null) {
          refusal = started?.reason ?? ReplayRefusal.noScope;
          return;
        }
      }
      token = run.onAction(actionId, target: target);
      if (token != null && ticket != null) _tickets[token!] = ticket;
    }, refusal: () => refusal);
    return token;
  }

  @override
  void outcome(String outcomeId, {required Object? token}) =>
      _change((run) {
        final ticket = token == null ? null : _tickets.remove(token);
        if (ticket != null && !_replay.stillCurrent(ticket)) {
          // Asked in one scope, answered in another: the answer belongs to
          // the first and completes nothing in the second. The step asks
          // again, never assumed.
          run.abandonAttempt();
          return;
        }
        run.onOutcome(outcomeId, token: token);
      });

  // ── what the person chose ─────────────────────────────────────────────

  void acknowledge() => _change((run) => run.acknowledge());

  void skip() => _change((run) => run.skip());

  void back() => _change((run) => run.back());

  void visit(String id) => _change((run) => run.visit(id));

  /// Resumes only where it paused: the same scope, the feature on.
  bool resume() {
    final run = state.run;
    if (run == null || run.state != GuideRunState.paused) return false;
    if (ref.read(recorderScopeProvider) != _startScope ||
        !ref.read(taskRecorderAvailableProvider)) {
      return false;
    }
    run.resume();
    _set(run, pauseReason: null);
    return true;
  }

  void stop() {
    final run = state.run;
    if (run == null) return;
    run.stop();
    _release();
    _set(run, pauseReason: state.pauseReason);
  }

  /// Closes a finished or stopped guide.
  void close() {
    _release();
    state = GuideSessionState(revision: state.revision + 1);
    _tellArbiter();
  }

  void _pause(GuidePauseReason reason) {
    final run = state.run;
    if (run == null || run.state != GuideRunState.running) return;
    run.pause();
    _set(run, pauseReason: reason);
  }

  void _change(
    void Function(GuideRun run) apply, {
    ReplayRefusal? Function()? refusal,
  }) {
    final run = state.run;
    if (run == null) return;
    apply(run);
    if (run.state == GuideRunState.completed) _release();
    _set(run, pauseReason: state.pauseReason, refusal: refusal?.call());
  }

  void _set(
    GuideRun run, {
    required GuidePauseReason? pauseReason,
    ReplayRefusal? refusal,
  }) {
    state = GuideSessionState(
      run: run,
      pauseReason: run.state == GuideRunState.paused ? pauseReason : null,
      revision: state.revision + 1,
      refusal: refusal,
    );
    _tellArbiter();
  }

  /// The help surface's one arbiter: an open guide outranks tips.
  void _tellArbiter() =>
      ref.read(helpArbiterProvider.notifier).guide(active: state.run != null);

  void _release() {
    _tickets.clear();
    if (identical(GuideEvents.sink, this)) GuideEvents.sink = null;
  }
}
