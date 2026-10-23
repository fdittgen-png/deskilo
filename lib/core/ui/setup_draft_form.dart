// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2869 — how a setup step's page lets the guide keep what the owner typed
// and has not saved as a draft on the server. The page says when its
// answers change, what they are, and how to put a set of answers back;
// the frame the guide wraps around the form (the workspace feature's
// `SetupDraftFrame`) restores a draft over the stored values, saves the
// answers as the owner pauses, and offers Discard, Reload or Keep mine.
// Pages of the features above the workspace receive the frame as a
// [SetupDraftFrameBuilder], so none of them imports the workspace feature.
import 'package:flutter/widgets.dart';

/// One step page's form, as its draft sees it.
class SetupDraftForm {
  SetupDraftForm({
    required this.edits,
    required this.answers,
    required this.fill,
  });

  /// Fires on every edit the owner makes.
  final Listenable edits;

  /// The answers the form holds now, as a JSON-ready map.
  final Map<String, Object?> Function() answers;

  /// Puts [answers] back into the form; null puts the stored values back.
  final void Function(Map<String, Object?>? answers) fill;

  Future<void> Function()? _drop;

  /// The frame around the form: [drop] drops its draft. Null detaches.
  void attach(Future<void> Function()? drop) => _drop = drop;

  /// The page's own save applied the answers: they are configuration now,
  /// not a draft.
  Future<void> applied() async {
    await _drop?.call();
  }
}

/// Wraps [child], the step's form, in its draft.
typedef SetupDraftFrameBuilder = Widget Function({
  required SetupDraftForm form,
  required Widget child,
});
