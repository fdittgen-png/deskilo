// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2012 — the order every plan-media write follows. Storage and the
// database are two separate calls, never one transaction, so the order is
// what keeps the committed plan usable when either fails half-way:
//
//   * a replacement is uploaded to a NEW path; the reference moves only
//     after the upload, and the previous object is removed only after the
//     reference moved. A failure before that leaves the old image live.
//   * a failed or lost reference update never deletes the candidate: the
//     update may have committed, and a reference to a removed object is
//     the one state that must not exist. The candidate is an orphan at
//     worst, which cleanup can remove.
//   * a removal clears the reference first, then the object.
//   * removing an old or abandoned object is best effort: its failure is
//     reported to [onLeftover], never a failed operation.
import '../../../core/trace/trace_logger.dart';

/// The steps, with every Storage/database call handed in.
class PlanMediaSteps {
  const PlanMediaSteps({
    required this.upload,
    required this.publish,
    required this.remove,
    this.onLeftover,
  });

  /// Uploads the new bytes to [path].
  final Future<void> Function(String path) upload;

  /// Points the database reference at [path] (null: no image).
  final Future<void> Function(String? path) publish;

  /// Removes the Storage object at [path].
  final Future<void> Function(String path) remove;

  /// Told about an object that could not be removed (for cleanup).
  final void Function(String path, Object error)? onLeftover;

  /// Uploads to [candidate], publishes it, then retires [previous].
  Future<void> replace({required String candidate, String? previous}) async {
    await upload(candidate);
    await publish(candidate);
    if (previous != null && previous != candidate) await _bestEffort(previous);
  }

  /// Clears the reference, then removes [previous].
  Future<void> clear({String? previous}) async {
    await publish(null);
    if (previous != null) await _bestEffort(previous);
  }

  Future<void> _bestEffort(String path) async {
    try {
      await remove(path);
    } catch (e, st) {
      TraceLogger.instance.warn(
        'plan',
        'media object left for cleanup',
        error: e,
        stackTrace: st,
      );
      onLeftover?.call(path, e);
    }
  }
}
