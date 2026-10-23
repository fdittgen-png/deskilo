// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Where the guide's observed times come from (9999): a session on a step.
// It opens with the step's page and ends when the page is left; the next
// reading of the setup status decides what it was — the step is ready, so
// the time on the page is reported, or it is still open, so nothing is.
// A step that turns ready while its page is open (the page's own command
// read the status again) is reported at that reading. A step that was
// already ready when its page opened is a visit, not a session. Nothing is
// reported while the workspace films with invented people, and a report
// that fails is let go: an estimate's sample is not worth a retry.
import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/privacy/recording_providers.dart';
import '../../../core/time/clock.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/local_setup.dart';
import '../domain/setup_status.dart';
import '../domain/setup_step_timing.dart';
import '../providers/local_setup_providers.dart';

part 'setup_step_timing_recorder.g.dart';

/// One step page, open or just left, whose step may still turn ready.
class _Session {
  _Session(this.workspaceId, this.step, this.openedAt);

  final String workspaceId;
  final String step;
  final DateTime openedAt;

  /// When the page was left; null while it is open.
  DateTime? closedAt;

  /// Whether the step was open when the page opened; null until a status
  /// was read.
  bool? wasOpen;
}

/// Records the sessions on setup step pages and reports the ones that
/// finished their step. One per app: a page reports to it on opening and
/// on leaving, and it reads the status whenever the guide does.
@Riverpod(keepAlive: true)
class SetupStepTimingRecorder extends _$SetupStepTimingRecorder {
  final Map<String, _Session> _sessions = {};

  /// Per workspace with a session, what stops reading its status.
  final Map<String, void Function()> _readings = {};

  @override
  void build() {}

  static String _key(String workspaceId, String step) => '$workspaceId/$step';

  /// The page of [step] in [workspaceId] opened now.
  void opened(String workspaceId, String step) {
    if (!ref.mounted || ref.read(recordingPrivacyProvider)) return;
    final session = _Session(workspaceId, step, ref.read(clockProvider).now());
    _sessions[_key(workspaceId, step)] = session;
    final status = workspaceSetupStatusProvider(workspaceId);
    _readings[workspaceId] ??= ref.listen(status, (_, next) {
      if (_fresh(next) case final value?) _read(workspaceId, value);
    }).close;
    if (_fresh(ref.read(status)) case final value?) _read(workspaceId, value);
  }

  /// A status the server answered, not the previous one shown again while
  /// the guide refreshes it.
  static SetupStatus? _fresh(AsyncValue<SetupStatus> status) => switch (status) {
    AsyncData(:final value, isRefreshing: false) => value,
    _ => null,
  };

  /// The page of [step] in [workspaceId] was left.
  void closed(String workspaceId, String step) {
    final session = _sessions[_key(workspaceId, step)];
    if (session == null || !ref.mounted) return;
    session.closedAt = ref.read(clockProvider).now();
  }

  /// The status of [workspaceId] was read: settles what it decides.
  void _read(String workspaceId, SetupStatus status) {
    final now = ref.read(clockProvider).now();
    final repository = ref.read(localSetupRepositoryProvider);
    for (final session in [..._sessions.values]) {
      if (session.workspaceId != workspaceId) continue;
      final step = status.steps
          .where((s) => s.step == session.step)
          .firstOrNull;
      final ready = step?.state == SetupStepState.ready;
      session.wasOpen ??= step != null && !ready;
      if (!session.wasOpen!) {
        _drop(session);
      } else if (ready) {
        _drop(session);
        unawaited(
          _report(
            repository,
            SetupStepObservation(
              workspaceId: workspaceId,
              step: session.step,
              openedAt: session.openedAt,
              duration: (session.closedAt ?? now).difference(session.openedAt),
            ),
          ),
        );
      } else if (session.closedAt != null) {
        _drop(session);
      }
    }
  }

  void _drop(_Session session) {
    _sessions.remove(_key(session.workspaceId, session.step));
    if (_sessions.values.any((s) => s.workspaceId == session.workspaceId)) {
      return;
    }
    _readings.remove(session.workspaceId)?.call();
  }

  Future<void> _report(
    LocalSetupRepository repository,
    SetupStepObservation observation,
  ) async {
    try {
      await repository.recordStepTiming(observation);
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'workspace',
        'setup step timing not reported',
        error: e,
        stackTrace: st,
      );
    }
  }
}
