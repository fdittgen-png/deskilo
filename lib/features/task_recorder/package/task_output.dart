// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1872 — the generator hook: how a rendered output (Word #1866, the
// storyboard #1876, video #1879) plugs into the local workbench.
//
// A generator is pure over the canonical, already validated recording:
// no network, no provider, no workspace. Whether it can run here is
// decided by what the platform can do — never by a workspace feature,
// and never with a dummy workspace. What it produces is bytes and a
// suggested name; saving them is the workbench's job, through the typed
// file saver, so every output tells a saved file from a browser request
// from a failure the same way. Reasons are a finite enum the workbench
// words, never prose or raw errors, and no private canary may survive
// into the bytes.

import 'dart:typed_data';
import 'dart:ui' show Brightness;

import '../domain/task_recording.dart';
import '../storyboard/storyboard.dart';

/// What an output is, so the workbench can name it in five languages.
enum TaskOutputKind { document, storyboard, video, captions }

/// Why an output is not available or was not made. A finite set the
/// workbench words itself; never prose or a raw error from a generator.
enum TaskOutputReason {
  /// The recording cannot be made into this output.
  refused,

  /// The storyboard given was reviewed for another revision.
  stale,

  /// Nothing to show (no step a video can illustrate).
  empty,
  tooLong,

  /// Another job of this output is running.
  busy,
  unsupportedPlatform,
  failed,
}

/// Whether a generator can run on this platform and build.
sealed class TaskOutputAvailability {
  const TaskOutputAvailability();
}

final class TaskOutputAvailable extends TaskOutputAvailability {
  const TaskOutputAvailable();
}

/// Not here, for [reason].
final class TaskOutputUnsupported extends TaskOutputAvailability {
  const TaskOutputUnsupported(this.reason);
  final TaskOutputReason reason;
}

/// What a generator is given.
class TaskOutputRequest {
  const TaskOutputRequest({
    required this.recording,
    required this.languageCode,
    this.assets = const {},
    this.storyboard,
    this.brightness = Brightness.light,
  });

  /// Already accepted by the canonical validator; source or edited.
  final TaskRecording recording;
  final String languageCode;

  /// Package-relative media path → bytes, already bounded and checked by
  /// the package reader.
  final Map<String, Uint8List> assets;

  /// The reviewed storyboard (#1876), when the person reviewed one. A
  /// generator refuses one reviewed for another revision ([TaskOutputReason.stale]).
  final Storyboard? storyboard;

  /// The theme the illustrations are drawn in.
  final Brightness brightness;
}

/// Cooperative cancellation.
class TaskOutputCancel {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// What a generator produced.
sealed class TaskOutputResult {
  const TaskOutputResult();
}

final class TaskOutputProduced extends TaskOutputResult {
  const TaskOutputProduced(this.bytes, this.suggestedName);
  final Uint8List bytes;
  final String suggestedName;
}

final class TaskOutputNotProduced extends TaskOutputResult {
  const TaskOutputNotProduced(this.reason);
  final TaskOutputReason reason;
}

final class TaskOutputFailed extends TaskOutputResult {
  const TaskOutputFailed(this.reason);
  final TaskOutputReason reason;
}

final class TaskOutputCancelled extends TaskOutputResult {
  const TaskOutputCancelled();
}

/// One output the workbench can make from a recording.
abstract interface class TaskOutputGenerator {
  /// 'docx', 'storyboard', 'mp4', 'webm', 'vtt'.
  String get id;

  TaskOutputKind get kind;

  /// Without a dot; its MIME type is in core/files/file_types.dart.
  String get fileExtension;

  Future<TaskOutputAvailability> availability();

  Future<TaskOutputResult> generate(
    TaskOutputRequest request, {
    void Function(double fraction)? onProgress,
    TaskOutputCancel? cancel,
  });
}
