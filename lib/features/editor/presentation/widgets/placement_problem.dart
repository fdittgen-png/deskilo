// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../plan/domain/floor_plan_rules.dart';

/// Why a placement was refused, in the reader's words.
///
/// Shared by the canvas and the seat sheet (#1216): both can land a
/// seat somewhere illegal, and a rule explained two different ways is
/// two rules as far as the reader is concerned.
void showPlacementProblem(BuildContext context, PlacementProblem problem) {
  final l10n = context.l10n;
  final message = switch (problem) {
    PlacementProblem.overlapsSibling =>
      l10n.editorPlacementOverlap,
    PlacementProblem.outsideParent =>
      l10n.editorPlacementOutside,
  };
  AppSnack.error(context, message, replace: true);
}
