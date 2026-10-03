// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — a private recording as the store reads it back: the recording,
// or why there is none, and whether a crash left its mark.

import 'task_recording.dart';
import 'task_recording_codec.dart';

/// How a stored recording reads back.
enum StoredStatus {
  /// It has an end line.
  ended,

  /// The app stopped while recording; it ends as interrupted.
  interrupted,

  /// The header is from another version, or the content did not pass
  /// the validator. Listed so it can be deleted; never shown as steps.
  unreadable,
}

/// One recording read back from the store.
class StoredRecording {
  const StoredRecording({
    required this.id,
    required this.status,
    this.createdAt,
    this.recording,
    this.truncatedTail = false,
    this.issues = const [],
  });

  final String id;
  final StoredStatus status;
  final DateTime? createdAt;
  final TaskRecording? recording;

  /// A partial last line was dropped, or a bad checkpoint rolled back.
  final bool truncatedTail;
  final List<RecordingIssue> issues;
}
