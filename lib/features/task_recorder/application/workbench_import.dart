// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1872 — opening a task file in the local workbench.
//
// The file is the person's own choice, read on this device, and never
// trusted: a package goes through the package reader, a plain recording
// through the canonical validator, anything else is refused by its
// first bytes, not its name. What comes out is a private draft: the
// file's own claims stay claims, and nothing in it selects a server,
// signs anybody in or is sent anywhere.

import 'dart:convert';
import 'dart:typed_data';

import '../domain/task_recording.dart';
import '../domain/task_recording_codec.dart';
import '../package/storyboard_review.dart';
import '../package/task_package.dart';

/// The largest file the workbench reads at all; checked before reading.
/// The package reader's own bound (TaskPackageLimits.maxPackageBytes).
const int workbenchMaxBytes = 64 * 1024 * 1024;

/// The extensions the picker offers.
const List<String> workbenchExtensions = ['json', 'zip'];

/// Why a file was refused, in categories the screen can say.
enum WorkbenchRefusal {
  /// Larger than the workbench reads.
  tooLarge,

  /// Neither a task package nor a task recording.
  unsupported,

  /// Built to escape or to exhaust: unsafe paths, links, encryption,
  /// bombs, duplicates.
  unsafe,

  /// Damaged or altered: checksums, sizes, missing or extra files.
  damaged,

  /// Made by a newer version of the app.
  newer,

  /// Readable, but what it says is not a valid task.
  invalid,
}

/// The outcome of opening a file.
sealed class WorkbenchImport {
  const WorkbenchImport();
}

final class WorkbenchOpened extends WorkbenchImport {
  const WorkbenchOpened({
    required this.recording,
    required this.runnable,
    required this.fromPackage,
    this.transcript,
    this.assets = const [],
    this.claims = const {},
    this.storyboard,
  });

  final TaskRecording recording;

  /// #1876 — the reviewed storyboard's decisions the package kept.
  final StoryboardReview? storyboard;

  /// False: a transcript only, with steps this build does not know.
  final bool runnable;
  final bool fromPackage;
  final String? transcript;
  final List<TaskPackageAsset> assets;

  /// What the file says about itself. Grants nothing.
  final Map<String, String> claims;
}

final class WorkbenchRefused extends WorkbenchImport {
  const WorkbenchRefused(this.reason);
  final WorkbenchRefusal reason;
}

/// Opens [bytes]. Decides by content: a zip's first bytes, or JSON.
WorkbenchImport openTaskFile(Uint8List bytes) {
  if (bytes.length > workbenchMaxBytes) {
    return const WorkbenchRefused(WorkbenchRefusal.tooLarge);
  }
  final isZip =
      bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4b &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04;
  if (isZip) {
    final read = readTaskPackage(bytes);
    final package = read.package;
    if (package == null) {
      return WorkbenchRefused(
        _packageRefusal(
          read.issues.firstOrNull ?? TaskPackageIssueCode.notAZip,
          read.recordingIssues,
        ),
      );
    }
    return WorkbenchOpened(
      recording: package.recording,
      runnable: package.runnable,
      fromPackage: true,
      transcript: package.transcript,
      assets: package.assets,
      claims: package.claims,
      storyboard: package.storyboard,
    );
  }
  final first = bytes.firstWhere((b) => b > 0x20, orElse: () => 0);
  if (first != 0x7b) {
    return const WorkbenchRefused(WorkbenchRefusal.unsupported);
  }
  final text = _utf8(bytes);
  if (text == null) return const WorkbenchRefused(WorkbenchRefusal.unsupported);
  final decoded = decodeRecordingText(text);
  final recording = decoded.recording;
  if (recording == null) {
    return WorkbenchRefused(_recordingRefusal(decoded.issues));
  }
  return WorkbenchOpened(
    recording: recording,
    runnable: decoded.runnable,
    fromPackage: false,
  );
}

String? _utf8(Uint8List bytes) {
  try {
    return const Utf8Decoder().convert(bytes);
  } on FormatException {
    return null;
  }
}

WorkbenchRefusal _recordingRefusal(List<RecordingIssue> issues) {
  final codes = issues.map((i) => i.code).toSet();
  if (codes.contains(RecordingIssueCode.tooLarge)) {
    return WorkbenchRefusal.tooLarge;
  }
  if (codes.contains(RecordingIssueCode.notJson) ||
      codes.contains(RecordingIssueCode.wrongFormat) ||
      codes.contains(RecordingIssueCode.notAnObject)) {
    return WorkbenchRefusal.unsupported;
  }
  if (codes.contains(RecordingIssueCode.unsupportedSchema)) {
    return WorkbenchRefusal.newer;
  }
  return WorkbenchRefusal.invalid;
}

WorkbenchRefusal _packageRefusal(
  TaskPackageIssueCode code,
  List<RecordingIssue> recordingIssues,
) {
  switch (code) {
    case TaskPackageIssueCode.tooLarge:
    case TaskPackageIssueCode.entryTooLarge:
    case TaskPackageIssueCode.expandedTooLarge:
    case TaskPackageIssueCode.tooManyEntries:
      return WorkbenchRefusal.tooLarge;
    case TaskPackageIssueCode.notAZip:
    case TaskPackageIssueCode.missingManifest:
      return WorkbenchRefusal.unsupported;
    case TaskPackageIssueCode.unsafePath:
    case TaskPackageIssueCode.unexpectedEntry:
    case TaskPackageIssueCode.duplicateEntry:
    case TaskPackageIssueCode.symbolicLink:
    case TaskPackageIssueCode.encrypted:
    case TaskPackageIssueCode.unsupportedCompression:
      return WorkbenchRefusal.unsafe;
    case TaskPackageIssueCode.sizeMismatch:
    case TaskPackageIssueCode.missingFile:
    case TaskPackageIssueCode.unlistedFile:
    case TaskPackageIssueCode.checksumMismatch:
    case TaskPackageIssueCode.badText:
      return WorkbenchRefusal.damaged;
    case TaskPackageIssueCode.unsupportedVersion:
      return WorkbenchRefusal.newer;
    case TaskPackageIssueCode.badRecording:
      return _recordingRefusal(recordingIssues);
    case TaskPackageIssueCode.badManifest:
    case TaskPackageIssueCode.inconsistent:
      return WorkbenchRefusal.invalid;
  }
}
