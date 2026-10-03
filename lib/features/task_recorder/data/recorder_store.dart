// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the private, local, account-scoped store of task recordings.
//
// ## Shape on disk
//
// One append-only JSON-lines log per recording, named
// `tr1.<account namespace>.<random id>`:
//
//   {"t":"h", ...}   header: format version, creation time (for the
//                    retention purge), the scope DIGEST, title, contract
//   {"t":"g", ...}   a segment opened or closed
//   {"t":"s", ...}   a step, already minimized by the controller
//   {"t":"c", ...}   a checkpoint: how many steps, the last seq
//   {"t":"e", ...}   the end: why, and how complete
//
// Each append is one write of whole lines. Reading it back goes through
// the canonical validator (task_recording_codec.dart), the same one an
// import uses, so a file edited on disk earns no more trust than a file
// received by e-mail.
//
// ## Recovery
//
// A crash mid-write leaves a truncated last line: it is dropped. A line
// that does not parse ends the read there. A checkpoint that disagrees
// with the steps before it rolls back to the previous good checkpoint.
// A log without an end line was interrupted, and says so — it is never
// "complete". Resuming one is a new recording; [finalizeInterrupted]
// closes it as interrupted.
//
// ## What is NOT here
//
// No upload, no telemetry, no backup hook. The account namespace and the
// scope are digests (cache_scope.dart `cacheDigest`), so neither the
// instance host, the user id nor the workspace id is legible in a file
// name or a header. Android excludes app data from backup
// (`allowBackup="false"`); on iOS the application-support directory is
// part of the device backup, which holds only this minimized content.
//
// Storage choice (#1865 "keep/adapt/replace"): the plan named Hive, but
// Hive is declared and never initialised in lib/, and a box of values
// gives no truncated-tail semantics. A line log on the existing
// path_provider directory (FileCacheStore's) or, on the web,
// shared_preferences does, with no new dependency.

import 'dart:convert';

import '../../../core/time/clock.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/recording_sink.dart';
import '../domain/stored_recording.dart';

export '../domain/stored_recording.dart';
import '../domain/task_recording.dart';
import '../domain/task_recording_codec.dart';

/// Byte-level persistence the store appends to.
abstract interface class RecorderLogBackend {
  /// Appends [text] to [key], creating it. Throws on failure.
  Future<void> append(String key, String text);

  /// The whole log, or null when there is none.
  Future<String?> read(String key);

  Future<List<String>> keys(String prefix);

  Future<void> delete(String key);
}

/// Logs in memory: tests, and a device with no usable storage.
class MemoryRecorderLogBackend implements RecorderLogBackend {
  final Map<String, StringBuffer> logs = {};

  @override
  Future<void> append(String key, String text) async =>
      (logs[key] ??= StringBuffer()).write(text);

  @override
  Future<String?> read(String key) async => logs[key]?.toString();

  @override
  Future<List<String>> keys(String prefix) async =>
      logs.keys.where((k) => k.startsWith(prefix)).toList()..sort();

  @override
  Future<void> delete(String key) async => logs.remove(key);
}

/// The log line format version.
const int recorderLogVersion = 1;

/// Store keys only ever contain these characters.
final RegExp recorderKeyPattern = RegExp(r'^tr1\.[0-9a-f]{32}\.[0-9a-f]{32}$');

/// Thrown by a writer whose recording outgrew the store's bound.
class RecorderStoreFull implements Exception {
  const RecorderStoreFull();
}

class RecorderStore implements RecordingSink {
  RecorderStore({
    required this._backend,
    required String namespace,
    this._clock = const SystemClock(),
    this.limits = const RecordingLimits(),
    this.checkpointEvery = 20,
  }) : _namespace = namespace {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(namespace)) {
      throw ArgumentError.value(namespace, 'namespace', 'not a digest');
    }
  }

  final RecorderLogBackend _backend;
  final String _namespace;
  final Clock _clock;
  final RecordingLimits limits;
  final int checkpointEvery;

  String get _prefix => 'tr1.$_namespace.';

  String _key(String id) {
    final key = '$_prefix$id';
    if (!recorderKeyPattern.hasMatch(key)) {
      throw ArgumentError.value(id, 'id', 'not a recording id');
    }
    return key;
  }

  @override
  Future<RecordingWriter> begin(RecordingHeader header) async {
    final key = _key(header.id);
    final line = jsonEncode({
      't': 'h',
      'v': recorderLogVersion,
      'id': header.id,
      'created': _clock.now().millisecondsSinceEpoch,
      'scope': header.scopeDigest,
      'contract': header.contractVersion,
      'platform': header.platform.wire,
      if (header.title != null) 'title': header.title,
      'prerequisites': [
        for (final p in header.prerequisites)
          {'id': p.id, if (p.value != null) 'value': p.value},
      ],
    });
    await _backend.append(key, '$line\n');
    return _StoreWriter(this, key, line.length + 1);
  }

  /// The recordings of this account, newest first.
  Future<List<StoredRecording>> list() async {
    final out = <StoredRecording>[];
    for (final key in await _backend.keys(_prefix)) {
      if (!recorderKeyPattern.hasMatch(key)) continue;
      out.add(await _readKey(key));
    }
    out.sort(
      (a, b) => (b.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
        a.createdAt?.millisecondsSinceEpoch ?? 0,
      ),
    );
    return out;
  }

  Future<StoredRecording?> read(String id) async {
    final key = _key(id);
    if (await _backend.read(key) == null) return null;
    return _readKey(key);
  }

  /// Deletes one private recording. Exported copies are out of reach.
  Future<void> delete(String id) => _backend.delete(_key(id));

  /// Closes an interrupted recording as interrupted, so it stops asking.
  Future<void> finalizeInterrupted(String id) async {
    final stored = await read(id);
    if (stored == null || stored.status != StoredStatus.interrupted) return;
    final steps = stored.recording?.steps.length ?? 0;
    final lastSeq = steps == 0 ? 0 : stored.recording!.steps.last.seq;
    await _backend.append(
      _key(id),
      '${jsonEncode({'t': 'c', 'n': steps, 'last': lastSeq})}\n'
      '${jsonEncode({'t': 'e', 'reason': RecordingEndReason.interrupted.wire, 'completeness': Completeness.interrupted.wire})}\n',
    );
  }

  /// Deletes recordings older than the retention period. Returns how
  /// many went.
  Future<int> purgeExpired() async {
    final cutoff = _clock.now().subtract(limits.retention);
    var purged = 0;
    for (final stored in await list()) {
      final created = stored.createdAt;
      if (created == null || created.isBefore(cutoff)) {
        await _backend.delete(_key(stored.id));
        purged++;
      }
    }
    return purged;
  }

  Future<StoredRecording> _readKey(String key) async {
    final id = key.substring(_prefix.length);
    final String? text;
    try {
      text = await _backend.read(key);
    } catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'could not read a recording (${e.runtimeType})',
        stackTrace: st,
      );
      return StoredRecording(id: id, status: StoredStatus.unreadable);
    }
    return recoverRecordingLog(id, text ?? '', limits: limits);
  }
}

/// Reads a log back, recovering what a crash left. Pure: tests feed it
/// truncated and corrupted logs directly.
StoredRecording recoverRecordingLog(
  String id,
  String text, {
  RecordingLimits limits = const RecordingLimits(),
}) {
  final unreadable = StoredRecording(id: id, status: StoredStatus.unreadable);
  final lines = text.split('\n');
  // A log always ends with a newline; anything after the last one is a
  // write the app did not finish.
  final tailDropped = lines.last.isNotEmpty;
  lines.removeLast();
  if (lines.isEmpty) return unreadable;

  final Object? head;
  try {
    head = jsonDecode(lines.first);
  } on FormatException {
    return unreadable;
  }
  if (head is! Map ||
      head['t'] != 'h' ||
      head['v'] != recorderLogVersion ||
      head['id'] != id ||
      head['created'] is! int) {
    return unreadable;
  }
  final created = DateTime.fromMillisecondsSinceEpoch(head['created'] as int);

  var truncated = false;
  final segments = <Object?>[];
  final steps = <Object?>[];
  var goodSteps = 0;
  var goodSegments = 0;
  Map<Object?, Object?>? end;
  for (final line in lines.skip(1)) {
    final Object? entry;
    try {
      entry = jsonDecode(line);
    } on FormatException {
      truncated = true;
      break;
    }
    if (entry is! Map || end != null) {
      truncated = true;
      break;
    }
    switch (entry['t']) {
      case 'g':
        final seg = entry['seg'];
        if (seg is! Map) {
          truncated = true;
          break;
        }
        if (segments.isNotEmpty &&
            segments.last is Map &&
            (segments.last as Map)['index'] == seg['index']) {
          segments[segments.length - 1] = seg;
        } else {
          segments.add(seg);
        }
      case 's':
        steps.add(entry['step']);
      case 'c':
        final last = steps.isEmpty ? 0 : (steps.last as Map?)?['seq'];
        if (entry['n'] != steps.length || entry['last'] != last) {
          // The steps disagree with the checkpoint: keep what the last
          // good checkpoint vouched for.
          steps.removeRange(goodSteps, steps.length);
          segments.removeRange(goodSegments, segments.length);
          truncated = true;
          break;
        }
        goodSteps = steps.length;
        goodSegments = segments.length;
      case 'e':
        end = entry;
      default:
        truncated = true;
    }
    if (truncated) break;
  }

  final reason = end == null ? null : end['reason'];
  if (end == null && segments.isNotEmpty) {
    // Interrupted: close the open segment at the last thing it saw.
    final last = segments.last;
    if (last is Map && last['end_ms'] == null) {
      final lastMs = steps.isEmpty
          ? last['start_ms']
          : (steps.last as Map?)?['elapsed_ms'] ?? last['start_ms'];
      segments[segments.length - 1] = {...last, 'end_ms': lastMs};
    }
  }
  final json = {
    'format': taskRecordingFormat,
    'schema_version': taskRecordingSchemaVersion,
    'action_contract_version': head['contract'],
    'platform': head['platform'],
    'kind': RecordingKind.source.wire,
    if (head['title'] != null) 'title': head['title'],
    'prerequisites': head['prerequisites'],
    'segments': segments,
    'steps': steps,
    'end_reason': ?reason,
    'completeness': end == null
        ? Completeness.interrupted.wire
        : end['completeness'],
  };
  final decoded = decodeRecording(json, limits: limits);
  if (!decoded.accepted) {
    return StoredRecording(
      id: id,
      status: StoredStatus.unreadable,
      createdAt: created,
      issues: decoded.issues,
    );
  }
  return StoredRecording(
    id: id,
    status: end == null ? StoredStatus.interrupted : StoredStatus.ended,
    createdAt: created,
    recording: decoded.recording,
    truncatedTail: tailDropped || truncated,
    issues: decoded.issues,
  );
}

class _StoreWriter implements RecordingWriter {
  _StoreWriter(this._store, this._key, this._written);

  final RecorderStore _store;
  final String _key;
  int _written;
  int _steps = 0;
  int _lastSeq = 0;

  /// The log carries line framing beside the steps; twice the export
  /// bound is the most a recording within its limits can need.
  int get _bound => _store.limits.maxBytes * 2;

  Future<void> _append(List<Map<String, Object?>> entries) async {
    final text = entries.map((e) => '${jsonEncode(e)}\n').join();
    if (_written + text.length > _bound) throw const RecorderStoreFull();
    await _store._backend.append(_key, text);
    _written += text.length;
  }

  Map<String, Object?> get _checkpoint => {
    't': 'c',
    'n': _steps,
    'last': _lastSeq,
  };

  @override
  Future<void> segment(RecordingSegment segment) => _append([
    {'t': 'g', 'seg': encodeSegment(segment)},
  ]);

  @override
  Future<void> step(RecordedStep step) async {
    final entries = <Map<String, Object?>>[
      {'t': 's', 'step': encodeStep(step)},
    ];
    _steps++;
    _lastSeq = step.seq;
    if (_steps % _store.checkpointEvery == 0) entries.add(_checkpoint);
    try {
      await _append(entries);
    } on Object {
      _steps--;
      rethrow;
    }
  }

  @override
  Future<void> end(RecordingEndReason reason, Completeness completeness) =>
      _append([
        _checkpoint,
        {'t': 'e', 'reason': reason.wire, 'completeness': completeness.wire},
      ]);

  @override
  Future<void> discard() => _store._backend.delete(_key);
}
