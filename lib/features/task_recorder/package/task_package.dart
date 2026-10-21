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
import 'task_package_inflate.dart';

const String _taskPackageFormat = 'deskilo.task-package';

/// The newest package version this build writes and reads. Version 2
/// (#1876) adds the optional reviewed storyboard; a package without one
/// is still written as version 1, so older readers keep reading it.
const int _taskPackageVersion = 2;
const String taskPackageExtension = '.deskilo-task.zip';

const String _manifestPath = 'manifest.json';
const String _recordingPath = 'recording.json';
const String _transcriptPath = 'transcript.md';
const String _storyboardPath = 'storyboard.json';

/// The media a package may carry, by extension.
const Map<String, String> _taskPackageMediaTypes = {
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
      _taskPackageMediaTypes[path.substring(path.lastIndexOf('.') + 1)]!;
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
    'format': _taskPackageFormat,
    'package_version': storyboardBytes == null ? 1 : _taskPackageVersion,
    'product': 'deskilo',
    'recording': {
      ...entry(_recordingPath, recordingBytes),
      'schema_version': schemaVersionOf(recording),
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
  } on Object catch (e, st) {
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
      content = inflateCapped(
        zf.getRawContent(),
        method,
        cap: cap,
        remaining: limits.maxExpandedBytes - expanded,
      );
    } on CapExceeded catch (e, st) {
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
    } on Object catch (e, st) {
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
  try {
    return _ManifestReader(files, limits, recordingLimits).read();
  } on _Refused catch (r, st) {
    TraceLogger.instance.warn(
      'recorder',
      'package refused: ${r.code.name}',
      stackTrace: st,
    );
    return TaskPackageReadResult(null, [r.code]);
  }
}

/// A check of the manifest failed: the whole package is refused with [code].
class _Refused implements Exception {
  const _Refused(this.code);
  final TaskPackageIssueCode code;
}

/// Reads one package's manifest: each section is checked by its own
/// method, the first failure refuses the package.
class _ManifestReader {
  _ManifestReader(this.files, this.limits, this.recordingLimits);

  final Map<String, Uint8List> files;
  final TaskPackageLimits limits;
  final RecordingLimits recordingLimits;
  final Set<String> listed = {_manifestPath};
  late final int version;

  static const _rootKeys = {
    'format',
    'package_version',
    'product',
    'recording',
    'transcript',
    'storyboard',
    'assets',
    'claims',
  };

  TaskPackageReadResult read() {
    final json = _root();
    final recordingEntry = json['recording'];
    _check(recordingEntry, const {
      'schema_version',
      'action_contract_version',
      'kind',
      'completeness',
    }, path: _recordingPath);
    final transcript = _transcript(json);
    final storyboard = _storyboard(json);
    final assets = _assets(json['assets']);
    if (files.keys.any((name) => !listed.contains(name))) {
      throw const _Refused(TaskPackageIssueCode.unlistedFile);
    }
    final claims = _claims(json['claims']);

    final decoded = decodeRecordingText(
      _text(_recordingPath),
      limits: recordingLimits,
    );
    if (!decoded.accepted) {
      return TaskPackageReadResult(null, const [
        TaskPackageIssueCode.badRecording,
      ], recordingIssues: decoded.issues);
    }
    final recording = decoded.recording!;
    final summary = recordingEntry as Map;
    if (summary['schema_version'] != schemaVersionOf(recording) ||
        summary['action_contract_version'] != recording.actionContractVersion ||
        summary['kind'] != recording.kind.wire ||
        summary['completeness'] != recording.completeness.wire) {
      throw const _Refused(TaskPackageIssueCode.inconsistent);
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

  /// The manifest object, its format and its version.
  Map<Object?, Object?> _root() {
    final raw = files[_manifestPath];
    if (raw == null) throw const _Refused(TaskPackageIssueCode.missingManifest);
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(raw));
    } on FormatException {
      throw const _Refused(TaskPackageIssueCode.badManifest);
    }
    if (json is! Map ||
        !json.keys.every(_rootKeys.contains) ||
        json['format'] != _taskPackageFormat) {
      throw const _Refused(TaskPackageIssueCode.badManifest);
    }
    final v = json['package_version'];
    if (v is! int || v < 1 || v > _taskPackageVersion) {
      throw const _Refused(TaskPackageIssueCode.unsupportedVersion);
    }
    version = v;
    return json;
  }

  /// Checks one listed file: present, the declared size, the checksum.
  void _check(
    Object? entry,
    Set<String> extraKeys, {
    String? path,
    bool media = false,
  }) {
    if (entry is! Map) throw const _Refused(TaskPackageIssueCode.badManifest);
    const keys = {'path', 'sha256', 'bytes'};
    if (!entry.keys.every((k) => keys.contains(k) || extraKeys.contains(k))) {
      throw const _Refused(TaskPackageIssueCode.badManifest);
    }
    final p = entry['path'];
    if (p is! String ||
        (path != null && p != path) ||
        (media && !_mediaPath.hasMatch(p))) {
      throw const _Refused(TaskPackageIssueCode.badManifest);
    }
    if (!listed.add(p)) {
      throw const _Refused(TaskPackageIssueCode.duplicateEntry);
    }
    final content = files[p];
    if (content == null) throw const _Refused(TaskPackageIssueCode.missingFile);
    if (entry['bytes'] != content.length ||
        entry['sha256'] != _sha256(content)) {
      throw const _Refused(TaskPackageIssueCode.checksumMismatch);
    }
  }

  String _text(String path) {
    try {
      return utf8.decode(files[path]!);
    } on FormatException {
      throw const _Refused(TaskPackageIssueCode.badText);
    }
  }

  String? _transcript(Map<Object?, Object?> json) {
    if (json['transcript'] == null) return null;
    _check(json['transcript'], const {}, path: _transcriptPath);
    return _text(_transcriptPath);
  }

  StoryboardReview? _storyboard(Map<Object?, Object?> json) {
    if (json['storyboard'] == null) return null;
    // A storyboard needs version 2; a version-1 package never has one.
    if (version < 2) throw const _Refused(TaskPackageIssueCode.badManifest);
    _check(json['storyboard'], const {}, path: _storyboardPath);
    return StoryboardReview.parse(_text(_storyboardPath)) ??
        (throw const _Refused(TaskPackageIssueCode.badManifest));
  }

  List<TaskPackageAsset> _assets(Object? assetList) {
    if (assetList != null && assetList is! List) {
      throw const _Refused(TaskPackageIssueCode.badManifest);
    }
    final assets = <TaskPackageAsset>[];
    for (final a in (assetList as List?) ?? const <Object?>[]) {
      _check(a, const {'media_type'}, media: true);
      final asset = TaskPackageAsset(
        (a as Map)['path'] as String,
        files[a['path']]!,
      );
      if (a['media_type'] != asset.mediaType) {
        throw const _Refused(TaskPackageIssueCode.badManifest);
      }
      assets.add(asset);
    }
    return assets;
  }

  Map<String, String> _claims(Object? raw) {
    final claimsRaw = raw ?? const <String, Object?>{};
    if (claimsRaw is! Map || claimsRaw.length > limits.maxClaims) {
      throw const _Refused(TaskPackageIssueCode.badManifest);
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
        throw const _Refused(TaskPackageIssueCode.badManifest);
      }
      claims[k] = v;
    }
    return claims;
  }
}
