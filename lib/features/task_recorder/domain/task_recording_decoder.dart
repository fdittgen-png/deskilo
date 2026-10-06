// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the validator half of task_recording_codec.dart: what an
// untrusted recording must satisfy before it becomes a TaskRecording.
part of 'task_recording_codec.dart';

const _rootKeys = {
  'format',
  'schema_version',
  'action_contract_version',
  'platform',
  'kind',
  'source_digest',
  'title',
  'values_mode',
  'prerequisites',
  'segments',
  'steps',
  'end_reason',
  'completeness',
};

const _stepKeys = {
  'seq',
  'segment',
  'elapsed_ms',
  'kind',
  'surface',
  'action',
  'action_version',
  'target',
  'payload',
  'values',
  'op',
  'state',
  'outcome',
  'note',
  'protected',
  'origin',
  'source_seq',
};

typedef _Build = RecordedStep Function({
  StepKind? as,
  String? surface,
  String? action,
  int? actionVersion,
  String? target,
  SafePayload payload,
  StepValues values,
  String? op,
  ObservationState? state,
  String? outcome,
  String? note,
  ProtectedSurface? protectedCategory,
});

final _opPattern = RegExp(r'^op[1-9][0-9]{0,4}$');
final _digestPattern = RegExp(r'^[0-9a-f]{64}$');

/// Control characters other than newline and tab: refused in prose.
final _controlChars = RegExp(r'[\u0000-\u0008\u000B-\u001F\u007F]');

class _Decoder {
  _Decoder(this.registry, this.limits);

  final ActionRegistry registry;
  final RecordingLimits limits;
  final issues = <RecordingIssue>[];

  // Whether the file says it captures values (its header decides, before any step).
  bool _captures = false;

  bool get _failed => issues.any((i) => i.fatal);

  void _fatal(RecordingIssueCode code, String path) =>
      issues.add(RecordingIssue(code, path));

  RecordingDecodeResult _refused() => RecordingDecodeResult(null, issues);

  bool _onlyKeys(Map<Object?, Object?> map, Set<String> allowed, String path) {
    for (final key in map.keys) {
      if (key is! String || !allowed.contains(key)) {
        _fatal(RecordingIssueCode.unknownKey, path);
        return false;
      }
    }
    return true;
  }

  int? _int(Object? v, String path, {int min = 0, int? max, bool req = true}) {
    if (v == null && !req) return null;
    if (v is! int || v < min || (max != null && v > max)) {
      _fatal(
        v == null
            ? RecordingIssueCode.missingField
            : RecordingIssueCode.badValue,
        path,
      );
      return null;
    }
    return v;
  }

  String? _prose(Object? v, int maxLength, String path) {
    if (v == null) return null;
    if (v is! String) {
      _fatal(RecordingIssueCode.badValue, path);
      return null;
    }
    if (v.length > maxLength) {
      _fatal(RecordingIssueCode.tooLong, path);
      return null;
    }
    if (_controlChars.hasMatch(v)) {
      _fatal(RecordingIssueCode.badValue, path);
      return null;
    }
    return v;
  }

  RecordingDecodeResult root(Object? json) {
    if (json is! Map) {
      _fatal(RecordingIssueCode.notAnObject, r'$');
      return _refused();
    }
    if (json['format'] != taskRecordingFormat) {
      _fatal(RecordingIssueCode.wrongFormat, 'format');
      return _refused();
    }
    final schema = json['schema_version'];
    if (schema is! int || schema < 1 || schema > taskRecordingSchemaVersion) {
      _fatal(RecordingIssueCode.unsupportedSchema, 'schema_version');
      return _refused();
    }
    if (!_onlyKeys(json, _rootKeys, r'$')) return _refused();

    final contract = _int(
      json['action_contract_version'],
      'action_contract_version',
      min: 1,
    );
    final platform = RecordingPlatform.fromWire(json['platform']);
    if (platform == null) _fatal(RecordingIssueCode.badValue, 'platform');
    final kind = RecordingKind.fromWire(json['kind']);
    if (kind == null) _fatal(RecordingIssueCode.badValue, 'kind');
    final digest = json['source_digest'];
    if (digest != null &&
        (digest is! String || !_digestPattern.hasMatch(digest))) {
      _fatal(RecordingIssueCode.badValue, 'source_digest');
    }
    if ((kind == RecordingKind.edited) != (digest != null)) {
      _fatal(RecordingIssueCode.inconsistent, 'source_digest');
    }
    final title = _prose(json['title'], limits.maxTitleLength, 'title');
    final endRaw = json['end_reason'];
    final endReason = RecordingEndReason.fromWire(endRaw);
    if (endRaw != null && endReason == null) {
      _fatal(RecordingIssueCode.badValue, 'end_reason');
    }
    final completeness = Completeness.fromWire(json['completeness']);
    if (completeness == null) {
      _fatal(RecordingIssueCode.badValue, 'completeness');
    }

    // "Capture values" is the person's choice, written in the header: only
    // a schema-2 file may carry it, and only such a file may carry values.
    final mode = json['values_mode'];
    if (mode != null && (mode != 'captured' || schema < 2)) {
      _fatal(RecordingIssueCode.badValue, 'values_mode');
    }
    _captures = mode == 'captured';

    final prerequisites = _prerequisites(json['prerequisites']);
    final segments = _segments(json['segments']);
    if (_failed) return _refused();
    final steps = _steps(json['steps'], segments!.length);
    if (_failed) return _refused();

    final recording = TaskRecording(
      actionContractVersion: contract!,
      platform: platform!,
      kind: kind!,
      sourceDigest: digest as String?,
      title: title,
      prerequisites: prerequisites!,
      segments: segments,
      steps: steps!,
      endReason: endReason,
      completeness: completeness,
      capturesValues: _captures,
    );
    // A recording may say less than it earned, never more.
    final earned = completenessOf(endReason, recording.steps);
    // An edited version keeps its source's word, but only a stopped
    // recording may ever call itself complete.
    final claimsMore = kind == RecordingKind.source
        ? completeness!.index < earned.index
        : completeness == Completeness.complete &&
              endReason != RecordingEndReason.stopped;
    if (claimsMore) {
      _fatal(RecordingIssueCode.inconsistent, 'completeness');
      return _refused();
    }
    return RecordingDecodeResult(recording, issues);
  }

  List<Prerequisite>? _prerequisites(Object? raw) {
    if (raw == null) return const [];
    if (raw is! List) {
      _fatal(RecordingIssueCode.badValue, 'prerequisites');
      return null;
    }
    if (raw.length > limits.maxPrerequisites) {
      _fatal(RecordingIssueCode.tooMany, 'prerequisites');
      return null;
    }
    final out = <Prerequisite>[];
    for (var i = 0; i < raw.length; i++) {
      final path = 'prerequisites[$i]';
      final p = raw[i];
      if (p is! Map || !_onlyKeys(p, const {'id', 'value'}, path)) {
        if (p is! Map) _fatal(RecordingIssueCode.badValue, path);
        return null;
      }
      final spec = registry.prerequisite(p['id']);
      final value = p['value'];
      if (spec == null ||
          (value == null && spec.values.isNotEmpty) ||
          (value != null &&
              (value is! String || !spec.values.contains(value)))) {
        _fatal(RecordingIssueCode.badValue, path);
        return null;
      }
      out.add(Prerequisite(spec.id, value: value as String?));
    }
    return out;
  }

  List<RecordingSegment>? _segments(Object? raw) {
    if (raw is! List || raw.isEmpty) {
      _fatal(RecordingIssueCode.missingField, 'segments');
      return null;
    }
    if (raw.length > limits.maxSegments) {
      _fatal(RecordingIssueCode.tooMany, 'segments');
      return null;
    }
    final maxMs = limits.maxDuration.inMilliseconds;
    final out = <RecordingSegment>[];
    var lastEnd = 0;
    for (var i = 0; i < raw.length; i++) {
      final path = 'segments[$i]';
      final s = raw[i];
      if (s is! Map) {
        _fatal(RecordingIssueCode.badValue, path);
        return null;
      }
      if (!_onlyKeys(s, const {'index', 'start_ms', 'end_ms'}, path)) {
        return null;
      }
      final index = _int(s['index'], '$path.index', max: i);
      final start = _int(s['start_ms'], '$path.start_ms', max: maxMs);
      final end = _int(s['end_ms'], '$path.end_ms', max: maxMs, req: false);
      if (_failed) return null;
      if (index != i || start! < lastEnd || (end != null && end < start)) {
        _fatal(RecordingIssueCode.time, path);
        return null;
      }
      // Only the last segment may still be open.
      if (end == null && i != raw.length - 1) {
        _fatal(RecordingIssueCode.inconsistent, path);
        return null;
      }
      lastEnd = end ?? start;
      out.add(RecordingSegment(index: index!, startMs: start, endMs: end));
    }
    return out;
  }

  List<RecordedStep>? _steps(Object? raw, int segmentCount) {
    if (raw is! List) {
      _fatal(RecordingIssueCode.missingField, 'steps');
      return null;
    }
    if (raw.length > limits.maxSteps) {
      _fatal(RecordingIssueCode.tooMany, 'steps');
      return null;
    }
    final out = <RecordedStep>[];
    final attempts = <String, String>{}; // op -> action id
    final answered = <String>{};
    var lastSeq = 0;
    var lastMs = 0;
    for (var i = 0; i < raw.length; i++) {
      final step = _step(raw[i], 'steps[$i]', segmentCount, attempts, answered);
      if (step == null) return null;
      if (step.seq <= lastSeq) {
        _fatal(RecordingIssueCode.sequence, 'steps[$i].seq');
        return null;
      }
      if (step.elapsedMs < lastMs) {
        _fatal(RecordingIssueCode.time, 'steps[$i].elapsed_ms');
        return null;
      }
      lastSeq = step.seq;
      lastMs = step.elapsedMs;
      out.add(step);
    }
    return out;
  }

  RecordedStep? _step(
    Object? raw,
    String path,
    int segmentCount,
    Map<String, String> attempts,
    Set<String> answered,
  ) {
    if (raw is! Map) {
      _fatal(RecordingIssueCode.badValue, path);
      return null;
    }
    if (!_onlyKeys(raw, _stepKeys, path)) return null;
    final seq = _int(raw['seq'], '$path.seq', min: 1, max: limits.maxSteps * 4);
    final segment = _int(
      raw['segment'],
      '$path.segment',
      max: segmentCount - 1,
    );
    final elapsed = _int(
      raw['elapsed_ms'],
      '$path.elapsed_ms',
      max: limits.maxDuration.inMilliseconds,
    );
    final kind = StepKind.fromWire(raw['kind']);
    if (kind == null) _fatal(RecordingIssueCode.badValue, '$path.kind');
    final origin = raw['origin'] == null
        ? StepOrigin.captured
        : StepOrigin.fromWire(raw['origin']);
    if (origin == null) _fatal(RecordingIssueCode.badValue, '$path.origin');
    final sourceSeq = _int(
      raw['source_seq'],
      '$path.source_seq',
      min: 1,
      max: limits.maxSteps * 4,
      req: false,
    );
    if (_failed) return null;

    RecordedStep build({
      StepKind? as,
      String? surface,
      String? action,
      int? actionVersion,
      String? target,
      SafePayload payload = SafePayload.empty,
      StepValues values = StepValues.none,
      String? op,
      ObservationState? state,
      String? outcome,
      String? note,
      ProtectedSurface? protectedCategory,
    }) => RecordedStep(
      seq: seq!,
      segment: segment!,
      elapsedMs: elapsed!,
      kind: as ?? kind!,
      surface: surface,
      action: action,
      actionVersion: actionVersion,
      target: target,
      payload: payload,
      values: values,
      op: op,
      state: state,
      outcome: outcome,
      note: note,
      protectedCategory: protectedCategory,
      origin: origin!,
      sourceSeq: sourceSeq,
    );

    // Fields a kind does not use must be absent.
    bool only(Set<String> used) {
      for (final key in raw.keys) {
        if (!_alwaysAllowed.contains(key) && !used.contains(key)) {
          _fatal(RecordingIssueCode.inconsistent, '$path.$key');
          return false;
        }
      }
      return true;
    }

    switch (kind!) {
      case StepKind.annotation:
        if (!only(const {'note'})) return null;
        final note = _prose(raw['note'], limits.maxNoteLength, '$path.note');
        if (note == null) {
          if (!_failed) _fatal(RecordingIssueCode.missingField, '$path.note');
          return null;
        }
        return build(note: note);
      case StepKind.excluded:
        if (!only(const {'protected'})) return null;
        final category = ProtectedSurface.fromWire(raw['protected']);
        if (category == null) {
          _fatal(RecordingIssueCode.badValue, '$path.protected');
          return null;
        }
        return build(protectedCategory: category);
      case StepKind.unrecorded:
        if (!only(const {'surface'})) return null;
        final surface = raw['surface'];
        if (surface != null && registry.surface(surface) == null) {
          // A surface this build does not know says nothing it can show.
          return build();
        }
        return build(surface: surface as String?);
      case StepKind.action:
        return _action(raw, path, build, attempts, only);
      case StepKind.observation:
        return _observation(raw, path, build, attempts, answered, only);
    }
  }

  static const _alwaysAllowed = {
    'seq',
    'segment',
    'elapsed_ms',
    'kind',
    'origin',
    'source_seq',
  };

  RecordedStep _degraded(String path, RecordingIssueCode code, _Build build) {
    issues.add(RecordingIssue(code, path, fatal: false));
    return build(as: StepKind.unrecorded);
  }

  RecordedStep? _action(
    Map<Object?, Object?> raw,
    String path,
    _Build build,
    Map<String, String> attempts,
    bool Function(Set<String>) only,
  ) {
    if (!only(const {
      'surface',
      'action',
      'action_version',
      'target',
      'payload',
      'values',
      'op',
      'state',
    })) {
      return null;
    }
    final spec = registry.action(raw['action']);
    final version = raw['action_version'];
    if (spec == null || version is! int || version != spec.version) {
      if (raw['action'] is! String) {
        _fatal(RecordingIssueCode.missingField, '$path.action');
        return null;
      }
      // An unknown command's outcome is unknown too, not an orphan.
      final op = raw['op'];
      if (op is String &&
          _opPattern.hasMatch(op) &&
          !attempts.containsKey(op)) {
        attempts[op] = '';
      }
      return _degraded('$path.action', RecordingIssueCode.unknownAction, build);
    }
    if (raw['surface'] != spec.surface ||
        spec.surface.startsWith('recorder.')) {
      _fatal(RecordingIssueCode.inconsistent, '$path.surface');
      return null;
    }
    var target = raw['target'];
    if (target != null &&
        (target is! String || !spec.targets.contains(target))) {
      // #2142 — a generic name this build does not know is dropped, not
      // refused; any other unknown target still refuses the file.
      if (spec.softTargets && target is String && target.length <= 128) {
        target = null;
      } else {
        _fatal(RecordingIssueCode.badValue, '$path.target');
        return null;
      }
    }
    final payload = SafePayload.parse(spec.payloadFields, raw['payload']);
    if (payload == null) {
      _fatal(RecordingIssueCode.unsafePayload, '$path.payload');
      return null;
    }
    // Values: only in a recording that captures them, and only what the
    // recorder itself would have kept.
    final values = StepValues.parse(raw['values']);
    if (values == null) {
      _fatal(RecordingIssueCode.unsafePayload, '$path.values');
      return null;
    }
    if (!values.isEmpty && !_captures) {
      _fatal(RecordingIssueCode.inconsistent, '$path.values');
      return null;
    }
    final op = raw['op'];
    final state = raw['state'];
    if (spec.isCommand) {
      if (op is! String ||
          !_opPattern.hasMatch(op) ||
          state != ObservationState.attempted.wire ||
          attempts.containsKey(op)) {
        _fatal(RecordingIssueCode.inconsistent, '$path.op');
        return null;
      }
      attempts[op] = spec.id;
    } else if (op != null || state != null) {
      _fatal(RecordingIssueCode.inconsistent, '$path.op');
      return null;
    }
    return build(
      surface: spec.surface,
      action: spec.id,
      actionVersion: spec.version,
      target: target as String?,
      payload: payload,
      values: values,
      op: op as String?,
      state: spec.isCommand ? ObservationState.attempted : null,
    );
  }

  RecordedStep? _observation(
    Map<Object?, Object?> raw,
    String path,
    _Build build,
    Map<String, String> attempts,
    Set<String> answered,
    bool Function(Set<String>) only,
  ) {
    if (!only(const {'surface', 'op', 'state', 'outcome', 'payload'})) {
      return null;
    }
    final op = raw['op'];
    if (op is! String || !attempts.containsKey(op) || answered.contains(op)) {
      // An outcome must answer an EARLIER attempt, once.
      _fatal(RecordingIssueCode.orphanOutcome, '$path.op');
      return null;
    }
    final attemptAction = attempts[op]!;
    if (attemptAction.isEmpty) {
      // The attempt was degraded: its outcome cannot be read either.
      answered.add(op);
      return _degraded(
        '$path.outcome',
        RecordingIssueCode.unknownOutcome,
        build,
      );
    }
    final spec = registry.outcome(raw['outcome']);
    final action = registry.action(attemptAction)!;
    if (spec == null || !action.outcomes.contains(spec.id)) {
      if (raw['outcome'] is! String) {
        _fatal(RecordingIssueCode.missingField, '$path.outcome');
        return null;
      }
      answered.add(op);
      return _degraded(
        '$path.outcome',
        RecordingIssueCode.unknownOutcome,
        build,
      );
    }
    if (raw['state'] != spec.state.wire || raw['surface'] != action.surface) {
      _fatal(RecordingIssueCode.inconsistent, '$path.state');
      return null;
    }
    final payload = SafePayload.parse(spec.payloadFields, raw['payload']);
    if (payload == null) {
      _fatal(RecordingIssueCode.unsafePayload, '$path.payload');
      return null;
    }
    answered.add(op);
    return build(
      surface: action.surface,
      op: op,
      state: spec.state,
      outcome: spec.id,
      payload: payload,
    );
  }
}
