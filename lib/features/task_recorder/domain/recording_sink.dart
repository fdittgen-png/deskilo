// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — where a live recording is written, as the controller sees it.
//
// The controller never touches a file. It hands minimized steps to a
// [RecordingWriter], one at a time and in order; the store
// (data/recorder_store.dart) appends them with checkpoints, and a fake
// in the tests can fail, stall or fill up on demand.

import 'action_registry.dart';
import 'task_recording.dart';

/// What a new recording starts with. [scopeDigest] binds it, privately,
/// to the account, workspace and installation it was made in; it is a
/// digest, never an id, and never leaves the store.
class RecordingHeader {
  const RecordingHeader({
    required this.id,
    required this.scopeDigest,
    required this.platform,
    this.contractVersion = actionContractVersion,
    this.title,
    this.prerequisites = const [],
  });

  /// A random local identifier, used for the file name only.
  final String id;
  final String scopeDigest;
  final RecordingPlatform platform;
  final int contractVersion;
  final String? title;
  final List<Prerequisite> prerequisites;
}

/// Appends to one recording. Every call may throw (a full disk); the
/// controller turns a throw into a partial recording, never into an
/// error the person's task sees.
abstract interface class RecordingWriter {
  /// A segment opened, or (with an end) closed.
  Future<void> segment(RecordingSegment segment);

  Future<void> step(RecordedStep step);

  /// The recording ended. Nothing is written after this.
  Future<void> end(RecordingEndReason reason, Completeness completeness);

  /// Removes everything written so far.
  Future<void> discard();
}

/// Opens new recordings.
abstract interface class RecordingSink {
  Future<RecordingWriter> begin(RecordingHeader header);
}
