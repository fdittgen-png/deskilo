// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2558 C2 — what a checked privacy write can answer besides "saved".
import 'visibility.dart';

/// The field is no longer what the write expected: another device or an
/// older app changed it first (`visibility_conflict`), or the reply was
/// lost and the field as read back is not the intended one. Nothing was
/// written by this request; the draft is kept for the person to review.
class VisibilityConflict implements Exception {
  const VisibilityConflict({this.current, this.unconfirmed = false});

  /// The field as the personal home holds it now; null when it could not
  /// be read back either.
  final FieldAudience? current;

  /// The reply was lost (a timeout or a dropped connection) and the field
  /// read back is not the intended one: the outcome is not known, so it is
  /// reviewed, never sent again blindly.
  final bool unconfirmed;

  @override
  String toString() =>
      'VisibilityConflict(unconfirmed: $unconfirmed, current: ${current?.audience})';
}

/// The checked write was sent and no answer of the server came back (a
/// timeout or a dropped connection): it may or may not have been saved.
/// The server's own answers — a refusal, a conflict — are never this.
class VisibilityReplyLost implements Exception {
  const VisibilityReplyLost(this.cause);

  final Object cause;

  @override
  String toString() => 'VisibilityReplyLost($cause)';
}

/// #2558 — the personal home has no checked network writer
/// (`set_visibility_if_unchanged_network_v1` is unknown there: PGRST202 or
/// 42883), an incomplete deployment. Nothing was written, and no weaker
/// writer is tried in its place.
class VisibilityUnsupported implements Exception {
  const VisibilityUnsupported();

  @override
  String toString() => 'VisibilityUnsupported()';
}
