// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/floor_plan_rules.dart';

/// Why a placement was refused, in the reader's words.
///
/// Shared by the canvas and the seat sheet (#1216): both can land a
/// seat somewhere illegal, and a rule explained two different ways is
/// two rules as far as the reader is concerned.
void showPlacementProblem(BuildContext context, PlacementProblem problem) {
  final l10n = AppLocalizations.of(context);
  final message = switch (problem) {
    PlacementProblem.overlapsSibling =>
      l10n?.editorPlacementOverlap ?? 'Overlaps an existing element.',
    PlacementProblem.outsideParent =>
      l10n?.editorPlacementOutside ?? 'Must be fully inside an office.',
  };
  AppSnack.error(context, message, replace: true);
}
