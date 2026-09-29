// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1648 — one clear "Continue with Deskilo" transition, out of the widgets
// (ADR 0024): which stage is true right now, one browser per explicit
// attempt, a resume that inspects instead of relaunching, and a failure
// that names its own next action.
import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/federation_port.dart';
import '../providers/auth_providers.dart';

part 'federation_handoff_controller.g.dart';

/// What the handoff panel shows. Idle is "no stage and no failure".
class FederationHandoffState {
  const FederationHandoffState({this.stage, this.failure, this.link = false});
  const FederationHandoffState.idle() : this();

  /// The stage that is actually happening, or null.
  final FederationStage? stage;

  /// Why the last attempt ended without a session, until dismissed.
  final FederationFailure? failure;

  /// Linking Deskilo to the signed-in account, not signing in.
  final bool link;

  /// An attempt is in flight: a second tap must not open a second browser.
  bool get busy => stage != null;

  /// Cancel is honest only before the return was claimed; once completing,
  /// the session exchange is already under way.
  bool get cancellable =>
      stage == FederationStage.opening || stage == FederationStage.waiting;
}

@Riverpod(keepAlive: true)
class FederationHandoffController extends _$FederationHandoffController {
  StreamSubscription<FederationEvent>? _events;

  /// The explicit attempt in flight; replaced by Cancel or a new attempt.
  Object? _attempt;

  /// The flow this controller is waiting for. Events of any other flow —
  /// an abandoned one, another installation's — are ignored.
  String? _flow;

  FederationPort? get _port => ref.read(authRepositoryProvider).federation;

  @override
  FederationHandoffState build() {
    final port = ref.watch(authRepositoryProvider).federation;
    _attempt = null;
    _flow = null;
    if (port == null) return const FederationHandoffState.idle();
    _events = port.events.listen(_on);
    ref.onDispose(() => _events?.cancel());
    // The app was stopped while the browser was open: the flow it left is
    // shown as waiting — never relaunched.
    final pending = port.pending;
    if (pending == null) return const FederationHandoffState.idle();
    _flow = pending.flow;
    return FederationHandoffState(
      stage: FederationStage.waiting,
      link: pending.link,
    );
  }

  /// The one explicit action. A second call while one is in flight does
  /// nothing: one tap, one browser.
  Future<void> start({bool link = false}) async {
    final port = _port;
    if (port == null || state.busy) return;
    final attempt = Object();
    _attempt = attempt;
    _flow = null;
    state = FederationHandoffState(stage: FederationStage.opening, link: link);
    try {
      final flow = await port.begin(link: link);
      if (!identical(_attempt, attempt)) {
        // Cancelled while the browser was opening: let that flow go too.
        await port.cancel(flow);
        return;
      }
      _flow = flow;
      final last = port.lastEvent;
      if (last != null && last.flow == flow) {
        _on(last);
      } else if (port.awaiting(flow)) {
        state = FederationHandoffState(
          stage: FederationStage.waiting,
          link: link,
        );
      }
    } on FederationStartFailure catch (error, stack) {
      TraceLogger.instance.warn(
        'auth',
        'federation start failed: ${error.failure.name}',
        stackTrace: stack,
      );
      if (!identical(_attempt, attempt)) return;
      _attempt = null;
      state = FederationHandoffState(failure: error.failure, link: link);
    }
  }

  /// The app came back to the foreground. Inspects the matching flow ONCE:
  /// still waiting stays waiting (the browser may still be open), a result
  /// that already arrived is shown, and a flow that is gone has expired.
  /// Regaining focus is not a cancellation, and nothing is relaunched.
  void resumed() {
    final port = _port;
    final flow = _flow;
    if (port == null || flow == null) return;
    if (state.stage != FederationStage.waiting) return;
    if (port.awaiting(flow) || port.completing(flow)) return;
    final last = port.lastEvent;
    if (last != null && last.flow == flow) {
      _on(last);
      return;
    }
    _finish(
      FederationHandoffState(
        failure: FederationFailure.expired,
        link: state.link,
      ),
    );
    unawaited(port.cancel(flow));
  }

  /// Back out before the return was claimed. The previous working context
  /// is untouched, and a late return for this flow is refused.
  Future<void> cancel() async {
    if (!state.cancellable) return;
    final flow = _flow;
    _finish(const FederationHandoffState.idle());
    if (flow != null) await _port?.cancel(flow);
  }

  /// Puts a failure away.
  void dismiss() {
    if (state.busy) return;
    state = const FederationHandoffState.idle();
  }

  void _on(FederationEvent event) {
    if (event.flow != _flow) return;
    if (event.completing) {
      state = FederationHandoffState(
        stage: FederationStage.completing,
        link: state.link,
      );
    } else {
      // Success needs no panel: the router resumes the saved task (#1650)
      // and linked accounts reloads. A failure keeps its next action.
      _finish(FederationHandoffState(failure: event.failure, link: state.link));
    }
  }

  void _finish(FederationHandoffState next) {
    _attempt = null;
    _flow = null;
    state = next;
  }
}

/// Whether this build can run the handoff at all (it owns the callback).
@riverpod
bool federationHandoffAvailable(Ref ref) =>
    ref.watch(authRepositoryProvider).federation != null;

/// Where "Continue with Deskilo" leads, for the one-sentence explanation.
@riverpod
Future<FederationDestination?> federationDestination(Ref ref) async =>
    ref.watch(authRepositoryProvider).federation?.destination();
