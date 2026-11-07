// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3407 — the step half of the validator: the steps list, one step, one
// action, and the degraded step an unknown outcome becomes. The header,
// prerequisites and segments stay in task_recording_decoder.dart.
part of 'task_recording_codec.dart';

extension _StepDecoding on _Decoder {
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
    final page = raw['page'];
    if ((_schema >= 3 && page == null) ||
        (page != null &&
            (_schema < 3 || page is! String || !registry.acceptsPage(page)))) {
      _fatal(RecordingIssueCode.badValue, '$path.page');
    }
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
      page: page as String?,
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
    'page',
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
      'page',
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
    final payload = SafePayload.parse(
      spec.payloadFields,
      raw['payload'],
      fields: registry.safeFields,
    );
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
    final payload = SafePayload.parse(
      spec.payloadFields,
      raw['payload'],
      fields: registry.safeFields,
    );
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
