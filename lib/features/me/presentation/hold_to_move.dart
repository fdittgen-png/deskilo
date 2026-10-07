// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// How long a finger rests on a space before it lifts and can be moved.
const Duration kHoldToMove = Duration(seconds: 1);

/// Starts the reorder drag of the list it sits in after [kHoldToMove] — a
/// real hold, not the half second a scroll can brush against.
class HoldToMove extends ReorderableDragStartListener {
  const HoldToMove({
    super.key,
    required super.index,
    required super.child,
    super.enabled,
  });

  @override
  MultiDragGestureRecognizer createRecognizer() =>
      DelayedMultiDragGestureRecognizer(delay: kHoldToMove, debugOwner: this);
}
