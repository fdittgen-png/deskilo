// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the validator half of task_recording_codec.dart: what an
// untrusted recording must satisfy before it becomes a TaskRecording.
part of 'task_recording_codec.dart';

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
  int _schema = 1;

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
    if (schema is int) _schema = schema;
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
}
