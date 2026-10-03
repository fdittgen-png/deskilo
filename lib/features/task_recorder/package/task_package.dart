// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1872 — the portable task package: `<name>.deskilo-task.zip`.
//
// ## What is inside
//
//   manifest.json    format, package version, what the recording is
//                    (schema, contract, source or edited, completeness),
//                    and the size and SHA-256 of every other file
//   recording.json   the canonical recording (task_recording_codec.dart)
//   transcript.md    optional: the steps as readable text
//   media/<name>     optional: approved images, video, captions
//
// The recording inside IS the plain-JSON export; the package adds an
// inventory, a transcript and media, never a second format. A checksum
// says a file is the one the manifest listed — not who made it, not that
// it is true, not that anybody may use it. `claims` keep what the maker
// said about the package (a title, "reviewed") as claims: they grant
// nothing, and every import is an untrusted private draft.
//
// ## What reading refuses (OWASP file-upload rules, fail closed)
//
// Too large before parsing; not a zip; more entries than allowed; any
// path outside the fixed allow-list (so no traversal, absolute, drive or
// UNC path, no backslash, no upper case, no Unicode look-alike, no
// nested archive, no script); a duplicate entry; a symbolic link; an
// encrypted entry; a compression other than stored or deflate; an entry
// whose inflated bytes pass its cap — counted WHILE inflating, so a
// forged size or a zip bomb stops at the cap, never in memory; inflated
// bytes that differ from the declared size; a file the manifest does not
// list, or a listed file that is missing or whose checksum differs; and
// a recording the canonical validator refuses. Error details are fixed
// codes, never an imported name or text.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/task_recording.dart';
import '../domain/task_recording_codec.dart';
import 'storyboard_review.dart';

const String taskPackageFormat = 'deskilo.task-package';

/// The newest package version this build writes and reads. Version 2
/// (#1876) adds the optional reviewed storyboard; a package without one
/// is still written as version 1, so older readers keep reading it.
const int taskPackageVersion = 2;
const String taskPackageExtension = '.deskilo-task.zip';

const String _manifestPath = 'manifest.json';
const String _recordingPath = 'recording.json';
const String _transcriptPath = 'transcript.md';
const String _storyboardPath = 'storyboard.json';

/// The media a package may carry, by extension.
const Map<String, String> taskPackageMediaTypes = {
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
  'mp4': 'video/mp4',
  'webm': 'video/webm',
  'vtt': 'text/vtt',
};

final RegExp _mediaPath = RegExp(
  r'^media/[a-z0-9][a-z0-9_-]{0,60}\.(png|jpg|jpeg|webp|mp4|webm|vtt)$',
);

/// The bounds a package is read within.
class TaskPackageLimits {
  const TaskPackageLimits({
    this.maxPackageBytes = 64 * 1024 * 1024,
    this.maxEntries = 64,
    this.maxTextBytes = 1024 * 1024,
    this.maxMediaBytes = 48 * 1024 * 1024,
    this.maxExpandedBytes = 96 * 1024 * 1024,
    this.maxClaims = 8,
    this.maxClaimLength = 200,
  });

  final int maxPackageBytes;
  final int maxEntries;

  /// manifest, recording and transcript, each.
  final int maxTextBytes;

  /// One media file.
  final int maxMediaBytes;

  /// Everything inflated together.
  final int maxExpandedBytes;
  final int maxClaims;
  final int maxClaimLength;
}

/// One media file in a package.
class TaskPackageAsset {
  const TaskPackageAsset(this.path, this.bytes);

  /// `media/<name>.<ext>`, from the allow-list.
  final String path;
  final Uint8List bytes;

  String get mediaType =>
      taskPackageMediaTypes[path.substring(path.lastIndexOf('.') + 1)]!;
}

/// A package read back. Always an untrusted private draft.
class TaskPackage {
  const TaskPackage({
    required this.recording,
    required this.runnable,
    this.transcript,
    this.assets = const [],
    this.claims = const {},
    this.storyboard,
  });

  final TaskRecording recording;

  /// #1876 — what the maker decided about the storyboard, if they kept
  /// one: replayed on a storyboard derived again (storyboard_review.dart).
  final StoryboardReview? storyboard;

  /// False when a step names an action this build does not know: a
  /// transcript may be shown, a guide may not run.
  final bool runnable;
  final String? transcript;
  final List<TaskPackageAsset> assets;

  /// What the maker said, kept as claims. Grants nothing.
  final Map<String, String> claims;
}

enum TaskPackageIssueCode {
  tooLarge,
  notAZip,
  tooManyEntries,
  unsafePath,
  unexpectedEntry,
  duplicateEntry,
  symbolicLink,
  encrypted,
  unsupportedCompression,
  entryTooLarge,
  expandedTooLarge,
  sizeMismatch,
  missingManifest,
  badManifest,
  unsupportedVersion,
  missingFile,
  unlistedFile,
  checksumMismatch,
  badText,
  badRecording,
  inconsistent,
}

/// What reading a package produced.
class TaskPackageReadResult {
  const TaskPackageReadResult(
    this.package,
    this.issues, {
    this.recordingIssues = const [],
  });

  final TaskPackage? package;
  final List<TaskPackageIssueCode> issues;

  /// The canonical validator's findings on recording.json.
  final List<RecordingIssue> recordingIssues;

  bool get accepted => package != null;
}

String _sha256(List<int> bytes) => sha256.convert(bytes).toString();

/// Builds a package. [transcript] is the readable text the caller made
/// in the person's language; [claims] are informative only.
Uint8List writeTaskPackage(
  TaskRecording recording, {
  String? transcript,
  List<TaskPackageAsset> assets = const [],
  Map<String, String> claims = const {},
  StoryboardReview? storyboard,
}) {
  final storyboardBytes = storyboard == null
      ? null
      : utf8.encode(storyboard.toText());
  final recordingBytes = utf8.encode('${encodeRecordingText(recording)}\n');
  final transcriptBytes = transcript == null ? null : utf8.encode(transcript);
  for (final a in assets) {
    if (!_mediaPath.hasMatch(a.path)) {
      throw ArgumentError.value(a.path, 'assets', 'not a package media path');
    }
  }
  Map<String, Object?> entry(String path, List<int> bytes) => {
    'path': path,
    'sha256': _sha256(bytes),
    'bytes': bytes.length,
  };
  final manifest = {
    'format': taskPackageFormat,
    'package_version': storyboardBytes == null ? 1 : taskPackageVersion,
    'product': 'deskilo',
    'recording': {
      ...entry(_recordingPath, recordingBytes),
      'schema_version': taskRecordingSchemaVersion,
      'action_contract_version': recording.actionContractVersion,
      'kind': recording.kind.wire,
      'completeness': recording.completeness.wire,
    },
    if (transcriptBytes != null)
      'transcript': entry(_transcriptPath, transcriptBytes),
    if (storyboardBytes != null)
      'storyboard': entry(_storyboardPath, storyboardBytes),
    'assets': [
      for (final a in assets)
        {...entry(a.path, a.bytes), 'media_type': a.mediaType},
    ],
    'claims': {for (final c in claims.entries) c.key: c.value},
  };
  final archive = Archive();
  void add(String name, List<int> bytes) {
    final file = ArchiveFile.bytes(name, bytes)
      // A fixed time: the same recording always packs to the same bytes.
      ..lastModTime = 0x21000000;
    archive.add(file);
  }

  add(
    _manifestPath,
    utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest)),
  );
  add(_recordingPath, recordingBytes);
  if (transcriptBytes != null) add(_transcriptPath, transcriptBytes);
  if (storyboardBytes != null) add(_storyboardPath, storyboardBytes);
  for (final a in assets) {
    add(a.path, a.bytes);
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// Reads and validates [bytes] as a package.
TaskPackageReadResult readTaskPackage(
  Uint8List bytes, {
  TaskPackageLimits limits = const TaskPackageLimits(),
  RecordingLimits recordingLimits = const RecordingLimits(),
}) {
  TaskPackageReadResult refuse(TaskPackageIssueCode code) =>
      TaskPackageReadResult(null, [code]);

  if (bytes.length > limits.maxPackageBytes) {
    return refuse(TaskPackageIssueCode.tooLarge);
  }
  final ZipDirectory directory;
  try {
    directory = ZipDirectory()..read(InputMemoryStream(bytes));
  } catch (e, st) {
    // A malformed archive is a refusal; only the error's type is traced,
    // never its message, which may quote the untrusted file.
    TraceLogger.instance.warn(
      'recorder',
      'package refused: not a zip (${e.runtimeType})',
      stackTrace: st,
    );
    return refuse(TaskPackageIssueCode.notAZip);
  }
  final headers = directory.fileHeaders;
  if (headers.isEmpty) return refuse(TaskPackageIssueCode.notAZip);
  if (headers.length > limits.maxEntries) {
    return refuse(TaskPackageIssueCode.tooManyEntries);
  }

  final files = <String, Uint8List>{};
  var expanded = 0;
  for (final header in headers) {
    final name = header.filename;
    final pathIssue = _pathIssue(name);
    if (pathIssue != null) return refuse(pathIssue);
    if (files.containsKey(name)) {
      return refuse(TaskPackageIssueCode.duplicateEntry);
    }
    final fileType = (header.externalFileAttributes >> 16) & 0xf000;
    if (fileType == 0xa000) return refuse(TaskPackageIssueCode.symbolicLink);
    if (header.generalPurposeBitFlag & 0x1 != 0) {
      return refuse(TaskPackageIssueCode.encrypted);
    }
    final method = header.compressionMethod;
    if (method != ZipFile.zipCompressionStore &&
        method != ZipFile.zipCompressionDeflate) {
      return refuse(TaskPackageIssueCode.unsupportedCompression);
    }
    final zf = header.file;
    if (zf == null || zf.filename != name) {
      return refuse(TaskPackageIssueCode.notAZip);
    }
    final cap = name.startsWith('media/')
        ? limits.maxMediaBytes
        : limits.maxTextBytes;
    if (header.uncompressedSize > cap) {
      return refuse(TaskPackageIssueCode.entryTooLarge);
    }
    final Uint8List content;
    try {
      content = _inflate(
        zf.getRawContent(),
        method,
        cap: cap,
        remaining: limits.maxExpandedBytes - expanded,
      );
    } on _CapExceeded catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'package refused: entry over its cap',
        stackTrace: st,
      );
      return refuse(
        e.total
            ? TaskPackageIssueCode.expandedTooLarge
            : TaskPackageIssueCode.entryTooLarge,
      );
    } catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'package refused: bad entry (${e.runtimeType})',
        stackTrace: st,
      );
      return refuse(TaskPackageIssueCode.notAZip);
    }
    if (content.length != header.uncompressedSize) {
      return refuse(TaskPackageIssueCode.sizeMismatch);
    }
    expanded += content.length;
    files[name] = content;
  }
  return _readManifest(files, limits, recordingLimits);
}

TaskPackageIssueCode? _pathIssue(String name) {
  if (name == _manifestPath ||
      name == _recordingPath ||
      name == _transcriptPath ||
      name == _storyboardPath ||
      _mediaPath.hasMatch(name)) {
    return null;
  }
  final unsafe =
      name.isEmpty ||
      name.startsWith('/') ||
      name.contains('\\') ||
      name.contains(':') ||
      name.split('/').any((s) => s == '..' || s == '.' || s.isEmpty) ||
      name.runes.any((r) => r < 0x20 || r == 0x7f);
  return unsafe
      ? TaskPackageIssueCode.unsafePath
      : TaskPackageIssueCode.unexpectedEntry;
}

TaskPackageReadResult _readManifest(
  Map<String, Uint8List> files,
  TaskPackageLimits limits,
  RecordingLimits recordingLimits,
) {
  TaskPackageReadResult refuse(TaskPackageIssueCode code) =>
      TaskPackageReadResult(null, [code]);

  final raw = files[_manifestPath];
  if (raw == null) return refuse(TaskPackageIssueCode.missingManifest);
  final Object? json;
  try {
    json = jsonDecode(utf8.decode(raw));
  } on FormatException {
    return refuse(TaskPackageIssueCode.badManifest);
  }
  const rootKeys = {
    'format',
    'package_version',
    'product',
    'recording',
    'transcript',
    'storyboard',
    'assets',
    'claims',
  };
  if (json is! Map || !json.keys.every(rootKeys.contains)) {
    return refuse(TaskPackageIssueCode.badManifest);
  }
  if (json['format'] != taskPackageFormat) {
    return refuse(TaskPackageIssueCode.badManifest);
  }
  final version = json['package_version'];
  if (version is! int || version < 1 || version > taskPackageVersion) {
    return refuse(TaskPackageIssueCode.unsupportedVersion);
  }

  final listed = <String>{_manifestPath};
  // Checks one listed file: present, the declared size, the checksum.
  TaskPackageIssueCode? check(
    Object? entry,
    Set<String> extraKeys, {
    String? path,
    bool media = false,
  }) {
    if (entry is! Map) return TaskPackageIssueCode.badManifest;
    const keys = {'path', 'sha256', 'bytes'};
    if (!entry.keys.every((k) => keys.contains(k) || extraKeys.contains(k))) {
      return TaskPackageIssueCode.badManifest;
    }
    final p = entry['path'];
    if (p is! String ||
        (path != null && p != path) ||
        (media && !_mediaPath.hasMatch(p))) {
      return TaskPackageIssueCode.badManifest;
    }
    if (!listed.add(p)) return TaskPackageIssueCode.duplicateEntry;
    final content = files[p];
    if (content == null) return TaskPackageIssueCode.missingFile;
    if (entry['bytes'] != content.length ||
        entry['sha256'] != _sha256(content)) {
      return TaskPackageIssueCode.checksumMismatch;
    }
    return null;
  }

  final recordingEntry = json['recording'];
  final recordingIssue = check(recordingEntry, const {
    'schema_version',
    'action_contract_version',
    'kind',
    'completeness',
  }, path: _recordingPath);
  if (recordingIssue != null) return refuse(recordingIssue);

  String? transcript;
  if (json['transcript'] != null) {
    final issue = check(json['transcript'], const {}, path: _transcriptPath);
    if (issue != null) return refuse(issue);
    try {
      transcript = utf8.decode(files[_transcriptPath]!);
    } on FormatException {
      return refuse(TaskPackageIssueCode.badText);
    }
  }

  StoryboardReview? storyboard;
  if (json['storyboard'] != null) {
    // A storyboard needs version 2; a version-1 package never has one.
    if (version < 2) return refuse(TaskPackageIssueCode.badManifest);
    final issue = check(json['storyboard'], const {}, path: _storyboardPath);
    if (issue != null) return refuse(issue);
    final String text;
    try {
      text = utf8.decode(files[_storyboardPath]!);
    } on FormatException {
      return refuse(TaskPackageIssueCode.badText);
    }
    storyboard = StoryboardReview.parse(text);
    if (storyboard == null) return refuse(TaskPackageIssueCode.badManifest);
  }

  final assets = <TaskPackageAsset>[];
  final assetList = json['assets'];
  if (assetList != null && assetList is! List) {
    return refuse(TaskPackageIssueCode.badManifest);
  }
  for (final a in (assetList as List?) ?? const <Object?>[]) {
    final issue = check(a, const {'media_type'}, media: true);
    if (issue != null) return refuse(issue);
    final asset = TaskPackageAsset(
      (a as Map)['path'] as String,
      files[a['path']]!,
    );
    if (a['media_type'] != asset.mediaType) {
      return refuse(TaskPackageIssueCode.badManifest);
    }
    assets.add(asset);
  }
  if (files.keys.any((name) => !listed.contains(name))) {
    return refuse(TaskPackageIssueCode.unlistedFile);
  }

  final claimsRaw = json['claims'] ?? const <String, Object?>{};
  if (claimsRaw is! Map || claimsRaw.length > limits.maxClaims) {
    return refuse(TaskPackageIssueCode.badManifest);
  }
  final claims = <String, String>{};
  for (final c in claimsRaw.entries) {
    final k = c.key;
    final v = c.value;
    if (k is! String ||
        v is! String ||
        !RegExp(r'^[a-z][a-z0-9_]{0,31}$').hasMatch(k) ||
        v.length > limits.maxClaimLength ||
        v.runes.any((r) => r < 0x20 || r == 0x7f)) {
      return refuse(TaskPackageIssueCode.badManifest);
    }
    claims[k] = v;
  }

  final String recordingText;
  try {
    recordingText = utf8.decode(files[_recordingPath]!);
  } on FormatException {
    return refuse(TaskPackageIssueCode.badText);
  }
  final decoded = decodeRecordingText(recordingText, limits: recordingLimits);
  if (!decoded.accepted) {
    return TaskPackageReadResult(null, const [
      TaskPackageIssueCode.badRecording,
    ], recordingIssues: decoded.issues);
  }
  final recording = decoded.recording!;
  final summary = recordingEntry as Map;
  if (summary['schema_version'] != taskRecordingSchemaVersion ||
      summary['action_contract_version'] != recording.actionContractVersion ||
      summary['kind'] != recording.kind.wire ||
      summary['completeness'] != recording.completeness.wire) {
    return refuse(TaskPackageIssueCode.inconsistent);
  }
  return TaskPackageReadResult(
    TaskPackage(
      recording: recording,
      runnable: decoded.runnable,
      transcript: transcript,
      assets: assets,
      claims: claims,
      storyboard: storyboard,
    ),
    const [],
    recordingIssues: decoded.issues,
  );
}

class _CapExceeded implements Exception {
  const _CapExceeded({required this.total});
  final bool total;
}

/// Inflates [raw] while counting: the cap is enforced as bytes come out.
Uint8List _inflate(
  Uint8List raw,
  int method, {
  required int cap,
  required int remaining,
}) {
  if (method == ZipFile.zipCompressionStore) {
    if (raw.length > cap) throw const _CapExceeded(total: false);
    if (raw.length > remaining) throw const _CapExceeded(total: true);
    return raw;
  }
  final out = _CappedOutput(cap: cap, remaining: remaining);
  Inflate.stream(InputMemoryStream(raw), output: out);
  return out.getBytes();
}

class _CappedOutput extends OutputMemoryStream {
  _CappedOutput({required this.cap, required this.remaining});

  final int cap;
  final int remaining;
  int _written = 0;

  void _count(int n) {
    _written += n;
    if (_written > cap) throw const _CapExceeded(total: false);
    if (_written > remaining) throw const _CapExceeded(total: true);
  }

  @override
  void writeByte(int value) {
    _count(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _count(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _count(stream.length);
    super.writeStream(stream);
  }
}
