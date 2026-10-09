// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the recorder's lifecycle: start, pause, resume, stop, discard.
//
// ## What this class promises the task being recorded
//
// Nothing. It observes, it never governs. Every observing method
// ([record], [attempt], [outcome], [excluded], [unrecorded], [annotate])
// is synchronous, returns at once, and never throws: a full disk, a
// failed write, a queue that will not drain or a bug in here ends the
// recording as partial and is traced, and the booking (or whatever the
// person was doing) runs exactly as it would with the recorder off. No
// method here retries, cancels, delays or changes a command.
//
// ## Causal order
//
// A command is recorded as an ATTEMPT before it runs: [attempt] returns
// an [OperationToken] carrying a recording-local alias ("op3") and the
// recording's EPOCH. The caller runs its command exactly once and hands
// the token back to [outcome] with what actually came back. So a
// command that completes synchronously still yields attempt-then-
// outcome, never an orphan outcome first.
//
// ## Epochs
//
// Each [start] opens a new epoch. An outcome whose token belongs to an
// older epoch — a booking that returns after Stop, after Discard, after
// a new recording started — is dropped. It never lands in the next
// recording; the old one keeps an unanswered attempt and says it is
// partial.
//
// ## Scope
//
// A recording belongs to one account, workspace and installation
// ([RecorderScope], a digest). When the scope changes under it, it ends
// (`scope_changed`) before anything from the new scope can enter.
// Recording again needs a new, explicit [start].

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../../core/cache/cache_scope.dart' show cacheDigest;
import '../../../core/trace/trace_logger.dart';
import '../domain/action_registry.dart';
import '../domain/recording_sink.dart';
import '../domain/safe_payload.dart';
import '../domain/step_values.dart';
import '../domain/task_recording.dart';
import '../domain/recording_reference.dart';
import '../domain/task_recording_codec.dart' show encodeStep;

part 'recorder_types.dart';
part 'recorder_persistence.dart';

class RecorderController {
  RecorderController({
    required this._sink,
    required this._platform,
    MonotonicMs? clock,
    this.registry = recorderRegistry,
    this.limits = const RecordingLimits(),
    this.dedupeWindowMs = 300,
    String Function()? newId,
    String? initialPage,
  }) : _clock = clock ?? stopwatchClock(),
       _newId = newId ?? _randomId,
       _page = initialPage != null && isGuideDestination(initialPage)
           ? initialPage
           : null;

  final RecordingSink _sink;
  final RecordingPlatform _platform;
  final MonotonicMs _clock;
  final String Function() _newId;
  final ActionRegistry registry;
  final RecordingLimits limits;

  /// Identical non-command steps closer together than this are one step
  /// (a double tap, a rebuild firing twice). Commands are never merged:
  /// two attempts are two attempts.
  final int dedupeWindowMs;

  final _changes = StreamController<RecorderStatus>.broadcast(sync: true);

  RecorderState _state = RecorderState.idle;
  int _epoch = 0;
  RecorderScope? _scope;
  RecordingWriter? _writer;
  Future<void> _chain = Future<void>.value();
  int _queued = 0;
  bool _writeFailed = false;
  RecordingWriter? _failedWriter;

  String? _page;
  String? get currentPage => _page;

  /// Route context is updated even while paused, before deferred UI capture.
  void setPage(String? page) {
    _page = page == null ? null : guidePageForTarget(page);
  }

  String? _referencePage({
    String? action,
    String? surface,
    String? target,
    String? page,
  }) {
    if (page != null) return isGuideDestination(page) ? page : null;
    if (action == RecorderActions.uiOpenScreen) {
      return guidePageForTarget(target);
    }
    return _page ?? guideSurfaceRoutes[surface];
  }

  int _startMs = 0;
  int _bytes = 0;
  int _nextOp = 1;
  String? _title;
  bool _captureValues = false;
  List<Prerequisite> _prerequisites = const [];
  final List<RecordedStep> _steps = [];
  final List<RecordingSegment> _segments = [];
  RecordingEndReason? _endReason;

  RecorderState get state => _state;
  int get epoch => _epoch;
  Stream<RecorderStatus> get changes => _changes.stream;

  RecorderStatus get status => RecorderStatus(
    state: _state,
    epoch: _epoch,
    stepCount: _steps.length,
    endReason: _endReason,
  );

  /// Whether the recording that is live keeps the typed values of what the
  /// person enters or chooses — their choice at the start, never a default.
  bool get capturesValues => _captureValues && _live;

  /// #2142 — whether the newest step is a command still waiting for its
  /// result: a screen's own seam asked first, so the generic layer keeps
  /// quiet about the same command.
  bool get awaitingOutcome => _steps.lastOrNull?.isAttempt ?? false;

  bool get _live =>
      _state == RecorderState.recording || _state == RecorderState.paused;

  /// The recording as it stands, or null before the first [start].
  TaskRecording? get snapshot => _state == RecorderState.idle
      ? null
      : TaskRecording(
          actionContractVersion: registry.contractVersion,
          platform: _platform,
          title: _title,
          prerequisites: _prerequisites,
          segments: _segments,
          steps: _steps,
          endReason: _endReason,
          capturesValues: _captureValues,
        );

  /// Starts a new recording in [scope]. Only ever called from an
  /// explicit person's action after the start disclosure. Returns false
  /// when one is already live or the store refused to open one.
  Future<bool> start({
    required RecorderScope scope,
    String? title,
    List<Prerequisite> prerequisites = const [],
    bool captureValues = false,
  }) async {
    if (_live) return false;
    final kept = _validPrerequisites(prerequisites);
    final cleanTitle = _cleanProse(title, limits.maxTitleLength);
    final RecordingWriter writer;
    try {
      writer = await _sink.begin(
        RecordingHeader(
          id: _newId(),
          scopeDigest: scope.digest,
          platform: _platform,
          contractVersion: registry.contractVersion,
          title: cleanTitle,
          prerequisites: kept,
          captureValues: captureValues,
        ),
      );
    } catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'could not open a recording (${e.runtimeType})',
        stackTrace: st,
      );
      return false;
    }
    if (_live) {
      // Another start won the race while this one waited for the store.
      unawaited(_quietly(writer.discard));
      return false;
    }
    _epoch++;
    _scope = scope;
    _writer = writer;
    _chain = Future<void>.value();
    _queued = 0;
    _writeFailed = false;
    _startMs = _clock();
    _bytes = 0;
    _nextOp = 1;
    _title = cleanTitle;
    _captureValues = captureValues;
    _prerequisites = kept;
    _steps.clear();
    const first = RecordingSegment(index: 0, startMs: 0);
    _segments
      ..clear()
      ..add(first);
    _endReason = null;
    _state = RecorderState.recording;
    _enqueue((w) => w.segment(first));
    _emit();
    return true;
  }

  /// Pauses: nothing is recorded until [resume], and the gap stays
  /// visible as a segment boundary.
  void pause() => _guard(() {
    if (_state != RecorderState.recording) return;
    final closed = _segments.removeLast().closedAt(_elapsed());
    _segments.add(closed);
    _enqueue((w) => w.segment(closed));
    _state = RecorderState.paused;
    _emit();
  });

  void resume() => _guard(() {
    if (_state != RecorderState.paused) return;
    if (_segments.length >= limits.maxSegments ||
        _elapsed() > limits.maxDuration.inMilliseconds) {
      _end(RecordingEndReason.limitReached);
      return;
    }
    final opened = RecordingSegment(
      index: _segments.length,
      startMs: _elapsed(),
    );
    _segments.add(opened);
    _enqueue((w) => w.segment(opened));
    _state = RecorderState.recording;
    _emit();
  });

  /// Stops and waits for the disk. Returns the finished recording.
  Future<TaskRecording?> stop() async {
    _guard(() => _end(RecordingEndReason.stopped));
    await _drain();
    return snapshot;
  }

  /// Throws the current recording away, on disk too. Business history
  /// is untouched: only this artifact goes.
  Future<void> discard() async {
    final writer = _writer;
    if (_state == RecorderState.idle || writer == null) return;
    _epoch++; // late outcomes of the discarded recording go nowhere
    _state = RecorderState.idle;
    _writer = null;
    _steps.clear();
    _segments.clear();
    _endReason = null;
    _emit();
    await _drain();
    await _quietly(writer.discard);
  }

  /// Ends a live recording whose scope is no longer [next] — a sign-out,
  /// another account, another workspace, another installation.
  void scopeChanged(RecorderScope? next) => _guard(() {
    if (_live && next != _scope) _end(RecordingEndReason.scopeChanged);
  });

  /// Records a non-command action. Unknown actions, the recorder's own
  /// controls and actions while paused are ignored.
  void record(
    String actionId, {
    String? target,
    String? page,
    Map<String, Object?> payload = const {},
    StepValues values = StepValues.none,
  }) => _guard(() {
    if (_state != RecorderState.recording) return;
    final spec = registry.action(actionId);
    if (spec == null || spec.isCommand) {
      if (spec == null) unrecorded();
      return;
    }
    if (registry.isRecorderControl(actionId)) return;
    final safeTarget = target != null && spec.targets.contains(target)
        ? target
        : null;
    final safe = SafePayload.minimize(spec.payloadFields, payload);
    // Values are kept only by a recording that was started to capture them.
    final kept = _captureValues ? values : StepValues.none;
    final last = _steps.lastOrNull;
    final now = _elapsed();
    if (last != null &&
        last.kind == StepKind.action &&
        last.action == spec.id &&
        last.target == safeTarget &&
        last.page ==
            _referencePage(
              action: spec.id,
              surface: spec.surface,
              target: safeTarget,
              page: page,
            ) &&
        last.segment == _segments.last.index) {
      // A field committed again is one field change — unless it now holds
      // another value, which is a change worth its own step; an identical
      // tap inside the window is one tap.
      if (spec.kind == ActionKind.fieldCommit && last.values == kept) return;
      if (spec.kind != ActionKind.fieldCommit &&
          last.payload == safe &&
          last.values == kept &&
          now - last.elapsedMs <= dedupeWindowMs) {
        return;
      }
    }
    _append(
      RecordedStep(
        seq: _steps.length + 1,
        segment: _segments.last.index,
        elapsedMs: now,
        kind: StepKind.action,
        surface: spec.surface,
        action: spec.id,
        actionVersion: spec.version,
        target: safeTarget,
        page: page,
        payload: safe,
        values: kept,
      ),
    );
  });

  /// Records the attempt of a command BEFORE it runs. Returns null when
  /// nothing is being recorded; the caller runs its command regardless.
  OperationToken? attempt(
    String actionId, {
    String? target,
    String? page,
    Map<String, Object?> payload = const {},
    StepValues values = StepValues.none,
  }) {
    OperationToken? token;
    _guard(() {
      if (_state != RecorderState.recording) return;
      final spec = registry.action(actionId);
      if (spec == null || !spec.isCommand) return;
      final op = 'op${_nextOp++}';
      final appended = _append(
        RecordedStep(
          seq: _steps.length + 1,
          segment: _segments.last.index,
          elapsedMs: _elapsed(),
          kind: StepKind.action,
          surface: spec.surface,
          action: spec.id,
          actionVersion: spec.version,
          target: target != null && spec.targets.contains(target)
              ? target
              : null,
          page: page,
          payload: SafePayload.minimize(spec.payloadFields, payload),
          values: _captureValues ? values : StepValues.none,
          op: op,
          state: ObservationState.attempted,
        ),
      );
      if (appended) token = OperationToken._(_epoch, op, spec.id);
    });
    return token;
  }

  /// Attaches what the command ACTUALLY returned to its attempt. A token
  /// from another epoch, or an outcome the action does not declare, is
  /// dropped; an outcome is recorded at most once per attempt.
  void outcome(
    OperationToken? token,
    String outcomeId, {
    Map<String, Object?> payload = const {},
  }) => _guard(() {
    if (token == null || token.epoch != _epoch || !_live) return;
    final action = registry.action(token.actionId);
    final spec = registry.outcome(outcomeId);
    if (action == null || spec == null || !action.outcomes.contains(spec.id)) {
      return;
    }
    final answered = _steps.any(
      (s) => s.kind == StepKind.observation && s.op == token.op,
    );
    if (answered) return;
    _append(
      RecordedStep(
        seq: _steps.length + 1,
        segment: _segments.last.index,
        elapsedMs: _elapsed(),
        kind: StepKind.observation,
        surface: action.surface,
        op: token.op,
        state: spec.state,
        outcome: spec.id,
        payload: SafePayload.minimize(spec.payloadFields, payload),
      ),
    );
  });

  /// A protected surface was entered: one marker, its category only.
  void excluded(ProtectedSurface category) => _guard(() {
    if (_state != RecorderState.recording) return;
    final last = _steps.lastOrNull;
    if (last != null &&
        last.kind == StepKind.excluded &&
        last.page == _referencePage() &&
        last.protectedCategory == category) {
      return;
    }
    _append(
      RecordedStep(
        seq: _steps.length + 1,
        segment: _segments.last.index,
        elapsedMs: _elapsed(),
        kind: StepKind.excluded,
        protectedCategory: category,
      ),
    );
  });

  /// Something happened that the recorder cannot describe. Shown as a
  /// manual step, never invented coverage.
  void unrecorded({String? surface}) => _guard(() {
    if (_state != RecorderState.recording) return;
    final known = registry.surface(surface);
    final last = _steps.lastOrNull;
    if (last != null &&
        last.kind == StepKind.unrecorded &&
        last.page == _referencePage(surface: known?.id) &&
        last.surface == known?.id) {
      return;
    }
    if (known?.recorderControl ?? false) return;
    _append(
      RecordedStep(
        seq: _steps.length + 1,
        segment: _segments.last.index,
        elapsedMs: _elapsed(),
        kind: StepKind.unrecorded,
        surface: known?.id,
      ),
    );
  });

  /// A note the person typed themselves, labelled as theirs.
  void annotate(String note) => _guard(() {
    if (!_live) return;
    final clean = _cleanProse(note, limits.maxNoteLength);
    if (clean == null) return;
    _append(
      RecordedStep(
        seq: _steps.length + 1,
        segment: _segments.last.index,
        elapsedMs: _elapsed(),
        kind: StepKind.annotation,
        note: clean,
      ),
    );
  });

  /// Releases the stream. The controller is unusable afterwards.
  Future<void> dispose() async {
    await _drain();
    await _changes.close();
  }

  // -------------------------------------------------------------------

  int _elapsed() => max(0, _clock() - _startMs);

  bool _append(RecordedStep step) {
    final attemptPage = step.kind == StepKind.observation
        ? _steps.where((s) => s.isAttempt && s.op == step.op).firstOrNull?.page
        : null;
    final page =
        attemptPage ??
        _referencePage(
          action: step.action,
          surface: step.surface,
          target: step.target,
          page: step.page,
        );
    if (page == null) {
      _end(RecordingEndReason.referenceMissing);
      return false;
    }
    _page ??= page;
    step = step.renumbered(step.seq, page: page);
    if (_steps.length >= limits.maxSteps ||
        step.elapsedMs > limits.maxDuration.inMilliseconds) {
      _end(RecordingEndReason.limitReached);
      return false;
    }
    final size = utf8.encode(jsonEncode(encodeStep(step))).length + 1;
    if (_bytes + size > limits.maxBytes) {
      _end(RecordingEndReason.limitReached);
      return false;
    }
    _bytes += size;
    _steps.add(step);
    _enqueue((w) => w.step(step));
    _emit();
    return true;
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(status);
  }

  List<Prerequisite> _validPrerequisites(List<Prerequisite> given) => [
    for (final p in given.take(limits.maxPrerequisites))
      if (registry.prerequisite(p.id) case final spec?)
        if ((spec.values.isEmpty && p.value == null) ||
            spec.values.contains(p.value))
          p,
  ];

  static Future<void> _quietly(Future<void> Function() body) async {
    try {
      await body();
    } catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'discard failed (${e.runtimeType})',
        stackTrace: st,
      );
    }
  }
}
