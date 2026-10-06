// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the ONE versioned task-recording model.
//
// This is the canonical semantic schema every consumer reads: the review
// and plain-JSON export (#1865), the task package (#1872), the Word
// document (#1866), the storyboard (#1876) and the
// guided task compiler (#1867). None of them defines a second format;
// the codec beside this file is the only parser.
//
// A TaskRecording holds nothing private BY CONSTRUCTION: steps carry
// registered identifiers and minimized payloads (safe_payload.dart),
// times are milliseconds since the recording started (no clock time),
// and command attempts are linked to their outcomes by recording-local
// aliases ("op1", "op2"), never by a reservation, request, account or
// workspace id. What binds a recording to the account and workspace it
// was made in lives in the store's private header (recorder_store.dart),
// is a digest, and is never part of this model or of an export.

import 'action_registry.dart';
import 'safe_payload.dart';

/// The format marker every encoded recording starts with.
const String taskRecordingFormat = 'deskilo.task-recording';

/// The schema version this build writes and the newest it reads.
const int taskRecordingSchemaVersion = 1;

/// Why a recording ended.
enum RecordingEndReason {
  /// The person stopped it.
  stopped('stopped'),

  /// The account, workspace or installation changed under it.
  scopeChanged('scope_changed'),

  /// A step, size or duration limit was reached.
  limitReached('limit_reached'),

  /// Writing it failed (a full disk, a refused write). What was written
  /// before stays, and the recording says it is partial.
  storageFailed('storage_failed'),

  /// The app stopped while it was recording; found on the next start.
  interrupted('interrupted');

  const RecordingEndReason(this.wire);
  final String wire;

  static RecordingEndReason? fromWire(Object? raw) =>
      values.where((v) => v.wire == raw).firstOrNull;
}

/// Whether a recording can be trusted to hold the whole task.
enum Completeness {
  /// Stopped by the person, every attempt answered.
  complete('complete'),

  /// Ended early or with an attempt nobody answered.
  partial('partial'),

  /// The app stopped while recording. Never "complete".
  interrupted('interrupted');

  const Completeness(this.wire);
  final String wire;

  static Completeness? fromWire(Object? raw) =>
      values.where((v) => v.wire == raw).firstOrNull;
}

/// The source evidence, or a version a person edited from it.
enum RecordingKind {
  source('source'),
  edited('edited');

  const RecordingKind(this.wire);
  final String wire;

  static RecordingKind? fromWire(Object? raw) =>
      values.where((v) => v.wire == raw).firstOrNull;
}

/// Where a step came from.
enum StepOrigin {
  /// Captured by the recorder.
  captured('captured'),

  /// Written by a person while editing; never claimed as observed.
  authored('authored');

  const StepOrigin(this.wire);
  final String wire;

  static StepOrigin? fromWire(Object? raw) =>
      values.where((v) => v.wire == raw).firstOrNull;
}

/// The platform family a recording was made on. Never a device model.
enum RecordingPlatform {
  android('android'),
  ios('ios'),
  web('web'),
  macos('macos'),
  windows('windows'),
  linux('linux'),
  unknown('unknown');

  const RecordingPlatform(this.wire);
  final String wire;

  static RecordingPlatform? fromWire(Object? raw) =>
      values.where((v) => v.wire == raw).firstOrNull;
}

/// The bounds a recording lives within. Shown in the UI and enforced by
/// the controller (capture), the store (disk) and the codec (import).
class RecordingLimits {
  const RecordingLimits({
    this.maxSteps = 500,
    this.maxBytes = 512 * 1024,
    this.maxDuration = const Duration(minutes: 30),
    this.maxSegments = 50,
    this.maxPrerequisites = 8,
    this.maxTitleLength = 120,
    this.maxNoteLength = 500,
    this.retention = const Duration(days: 30),
    this.maxQueuedWrites = 64,
  });

  final int maxSteps;

  /// Encoded size, in bytes, of one recording on disk or on import.
  final int maxBytes;
  final Duration maxDuration;
  final int maxSegments;
  final int maxPrerequisites;
  final int maxTitleLength;
  final int maxNoteLength;

  /// How long a private recording is kept on this device before it is
  /// deleted. An exported copy is outside the app's reach and is not.
  final Duration retention;

  /// Writes waiting for the disk. Past it, recording stops (partial)
  /// rather than holding memory or slowing the app.
  final int maxQueuedWrites;
}

/// A condition stated by the recording, without the session it came from.
class Prerequisite {
  const Prerequisite(this.id, {this.value});

  final String id;
  final String? value;

  @override
  bool operator ==(Object other) =>
      other is Prerequisite && other.id == id && other.value == value;

  @override
  int get hashCode => Object.hash(id, value);
}

/// An uninterrupted stretch of recording. A pause ends one; resuming
/// starts the next, so a gap is always visible.
class RecordingSegment {
  const RecordingSegment({
    required this.index,
    required this.startMs,
    this.endMs,
  });

  final int index;
  final int startMs;
  final int? endMs;

  RecordingSegment closedAt(int ms) =>
      RecordingSegment(index: index, startMs: startMs, endMs: ms);

  @override
  bool operator ==(Object other) =>
      other is RecordingSegment &&
      other.index == index &&
      other.startMs == startMs &&
      other.endMs == endMs;

  @override
  int get hashCode => Object.hash(index, startMs, endMs);
}

/// One step of a recording.
class RecordedStep {
  const RecordedStep({
    required this.seq,
    required this.segment,
    required this.elapsedMs,
    required this.kind,
    this.surface,
    this.action,
    this.actionVersion,
    this.target,
    this.payload = SafePayload.empty,
    this.op,
    this.state,
    this.outcome,
    this.note,
    this.protectedCategory,
    this.origin = StepOrigin.captured,
    this.sourceSeq,
  });

  /// 1-based, strictly increasing within a recording.
  final int seq;
  final int segment;

  /// Milliseconds since the recording started, from a monotonic clock.
  final int elapsedMs;
  final StepKind kind;
  final String? surface;
  final String? action;
  final int? actionVersion;
  final String? target;
  final SafePayload payload;

  /// The recording-local alias linking a command attempt to its outcome.
  final String? op;

  /// [ObservationState.attempted] on a command attempt; the outcome's
  /// state on an observation.
  final ObservationState? state;
  final String? outcome;

  /// A person's own words, on an annotation only.
  final String? note;

  /// On an excluded step: which kind of protected surface it was.
  final ProtectedSurface? protectedCategory;
  final StepOrigin origin;

  /// On an edited recording: the source step this one was kept from.
  final int? sourceSeq;

  bool get isAttempt =>
      kind == StepKind.action && state == ObservationState.attempted;

  RecordedStep renumbered(int newSeq, {int? keepSourceSeq}) => RecordedStep(
    seq: newSeq,
    segment: segment,
    elapsedMs: elapsedMs,
    kind: kind,
    surface: surface,
    action: action,
    actionVersion: actionVersion,
    target: target,
    payload: payload,
    op: op,
    state: state,
    outcome: outcome,
    note: note,
    protectedCategory: protectedCategory,
    origin: origin,
    sourceSeq: keepSourceSeq ?? sourceSeq,
  );

  @override
  bool operator ==(Object other) =>
      other is RecordedStep &&
      other.seq == seq &&
      other.segment == segment &&
      other.elapsedMs == elapsedMs &&
      other.kind == kind &&
      other.surface == surface &&
      other.action == action &&
      other.actionVersion == actionVersion &&
      other.target == target &&
      other.payload == payload &&
      other.op == op &&
      other.state == state &&
      other.outcome == outcome &&
      other.note == note &&
      other.protectedCategory == protectedCategory &&
      other.origin == origin &&
      other.sourceSeq == sourceSeq;

  @override
  int get hashCode => Object.hash(
    seq,
    segment,
    elapsedMs,
    kind,
    surface,
    action,
    target,
    payload,
    op,
    state,
    outcome,
    note,
    protectedCategory,
    origin,
    sourceSeq,
  );
}

/// A recording: the source evidence or an edited version of it.
class TaskRecording {
  TaskRecording({
    required this.actionContractVersion,
    required this.platform,
    required List<RecordedStep> steps,
    required List<RecordingSegment> segments,
    this.kind = RecordingKind.source,
    this.sourceDigest,
    this.title,
    List<Prerequisite> prerequisites = const [],
    this.endReason,
    Completeness? completeness,
  }) : steps = List.unmodifiable(steps),
       segments = List.unmodifiable(segments),
       prerequisites = List.unmodifiable(prerequisites),
       completeness = completeness ?? completenessOf(endReason, steps);

  final int actionContractVersion;
  final RecordingPlatform platform;
  final RecordingKind kind;

  /// On an edited recording: the digest of the source it was edited
  /// from (task_recording_codec.dart `recordingDigest`).
  final String? sourceDigest;
  final String? title;
  final List<Prerequisite> prerequisites;
  final List<RecordingSegment> segments;
  final List<RecordedStep> steps;

  /// Null while the recording is live.
  final RecordingEndReason? endReason;
  final Completeness completeness;

  /// Command attempts with no outcome in this recording.
  Iterable<RecordedStep> get unansweredAttempts {
    final answered = {
      for (final s in steps)
        if (s.kind == StepKind.observation && s.op != null) s.op,
    };
    return steps.where((s) => s.isAttempt && !answered.contains(s.op));
  }
}

/// The completeness a recording earns: complete only when the person
/// stopped it and every attempt it holds was answered.
Completeness completenessOf(
  RecordingEndReason? endReason,
  List<RecordedStep> steps,
) {
  if (endReason == null || endReason == RecordingEndReason.interrupted) {
    return Completeness.interrupted;
  }
  if (endReason != RecordingEndReason.stopped) return Completeness.partial;
  final answered = {
    for (final s in steps)
      if (s.kind == StepKind.observation && s.op != null) s.op,
  };
  final unanswered = steps.any((s) => s.isAttempt && !answered.contains(s.op));
  return unanswered ? Completeness.partial : Completeness.complete;
}
