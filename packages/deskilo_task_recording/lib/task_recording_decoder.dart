// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the validator half of task_recording_codec.dart: what an
// untrusted recording must satisfy before it becomes a TaskRecording.
part of 'task_recording_codec.dart';

final _digestPattern = RegExp(r'^[0-9a-f]{64}$');

class _Decoder {
  _Decoder(this.registry, this.limits);

  final ActionRegistry registry;
  final RecordingLimits limits;
  final checks = FieldChecks();

  // Whether the file says it captures values (its header decides, before any step).
  bool _captures = false;
  int _schema = 1;

  List<RecordingIssue> get issues => checks.issues;

  RecordingDecodeResult _refused() => RecordingDecodeResult(null, issues);

  RecordingDecodeResult root(Object? json) {
    if (json is! Map) {
      checks.fatal(RecordingIssueCode.notAnObject, r'$');
      return _refused();
    }
    if (json['format'] != taskRecordingFormat) {
      checks.fatal(RecordingIssueCode.wrongFormat, 'format');
      return _refused();
    }
    final schema = json['schema_version'];
    if (schema is int) _schema = schema;
    if (schema is! int || schema < 1 || schema > taskRecordingSchemaVersion) {
      checks.fatal(RecordingIssueCode.unsupportedSchema, 'schema_version');
      return _refused();
    }
    if (!checks.onlyKeys(json, _rootKeys, r'$')) return _refused();

    final contract = checks.integer(
      json['action_contract_version'],
      'action_contract_version',
      min: 1,
    );
    final platform = RecordingPlatform.fromWire(json['platform']);
    if (platform == null) checks.fatal(RecordingIssueCode.badValue, 'platform');
    final kind = RecordingKind.fromWire(json['kind']);
    if (kind == null) checks.fatal(RecordingIssueCode.badValue, 'kind');
    final digest = json['source_digest'];
    if (digest != null &&
        (digest is! String || !_digestPattern.hasMatch(digest))) {
      checks.fatal(RecordingIssueCode.badValue, 'source_digest');
    }
    if ((kind == RecordingKind.edited) != (digest != null)) {
      checks.fatal(RecordingIssueCode.inconsistent, 'source_digest');
    }
    final title = checks.prose(json['title'], limits.maxTitleLength, 'title');
    final endRaw = json['end_reason'];
    final endReason = RecordingEndReason.fromWire(endRaw);
    if (endRaw != null && endReason == null) {
      checks.fatal(RecordingIssueCode.badValue, 'end_reason');
    }
    final completeness = Completeness.fromWire(json['completeness']);
    if (completeness == null) {
      checks.fatal(RecordingIssueCode.badValue, 'completeness');
    }

    // "Capture values" is the person's choice, written in the header: only
    // a schema-2 file may carry it, and only such a file may carry values.
    final mode = json['values_mode'];
    if (mode != null && (mode != 'captured' || schema < 2)) {
      checks.fatal(RecordingIssueCode.badValue, 'values_mode');
    }
    _captures = mode == 'captured';

    final prerequisites = _prerequisites(json['prerequisites']);
    final segments = _segments(json['segments']);
    if (checks.failed) return _refused();
    final steps = StepDecoder(
      registry: registry,
      limits: limits,
      checks: checks,
      schema: _schema,
      captures: _captures,
    ).steps(json['steps'], segments!.length);
    if (checks.failed) return _refused();

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
      checks.fatal(RecordingIssueCode.inconsistent, 'completeness');
      return _refused();
    }
    return RecordingDecodeResult(recording, issues);
  }

  List<Prerequisite>? _prerequisites(Object? raw) {
    if (raw == null) return const [];
    if (raw is! List) {
      checks.fatal(RecordingIssueCode.badValue, 'prerequisites');
      return null;
    }
    if (raw.length > limits.maxPrerequisites) {
      checks.fatal(RecordingIssueCode.tooMany, 'prerequisites');
      return null;
    }
    final out = <Prerequisite>[];
    for (var i = 0; i < raw.length; i++) {
      final path = 'prerequisites[$i]';
      final p = raw[i];
      if (p is! Map || !checks.onlyKeys(p, const {'id', 'value'}, path)) {
        if (p is! Map) checks.fatal(RecordingIssueCode.badValue, path);
        return null;
      }
      final spec = registry.prerequisite(p['id']);
      final value = p['value'];
      if (spec == null ||
          (value == null && spec.values.isNotEmpty) ||
          (value != null &&
              (value is! String || !spec.values.contains(value)))) {
        checks.fatal(RecordingIssueCode.badValue, path);
        return null;
      }
      out.add(Prerequisite(spec.id, value: value as String?));
    }
    return out;
  }

  List<RecordingSegment>? _segments(Object? raw) {
    if (raw is! List || raw.isEmpty) {
      checks.fatal(RecordingIssueCode.missingField, 'segments');
      return null;
    }
    if (raw.length > limits.maxSegments) {
      checks.fatal(RecordingIssueCode.tooMany, 'segments');
      return null;
    }
    final maxMs = limits.maxDuration.inMilliseconds;
    final out = <RecordingSegment>[];
    var lastEnd = 0;
    for (var i = 0; i < raw.length; i++) {
      final path = 'segments[$i]';
      final s = raw[i];
      if (s is! Map) {
        checks.fatal(RecordingIssueCode.badValue, path);
        return null;
      }
      if (!checks.onlyKeys(s, const {'index', 'start_ms', 'end_ms'}, path)) {
        return null;
      }
      final index = checks.integer(s['index'], '$path.index', max: i);
      final start = checks.integer(s['start_ms'], '$path.start_ms', max: maxMs);
      final end = checks.integer(s['end_ms'], '$path.end_ms', max: maxMs, req: false);
      if (checks.failed) return null;
      if (index != i || start! < lastEnd || (end != null && end < start)) {
        checks.fatal(RecordingIssueCode.time, path);
        return null;
      }
      // Only the last segment may still be open.
      if (end == null && i != raw.length - 1) {
        checks.fatal(RecordingIssueCode.inconsistent, path);
        return null;
      }
      lastEnd = end ?? start;
      out.add(RecordingSegment(index: index!, startMs: start, endMs: end));
    }
    return out;
  }
}
