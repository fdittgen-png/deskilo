// SPDX-License-Identifier: 0BSD
//
// #1289 — the one contrast check, for the lint and for the runtime.
//
// `test/lint/contrast_test.dart` measured WCAG AA over the three
// compiled-in schemes. Once a workspace may supply its own brand seed
// (#1289), the same measurement has to run against the derived scheme
// at the moment the colour is chosen and refuse it with the failing
// pair named — and it has to be the SAME measurement, not a lint that
// agrees with the validator by coincidence (§6.4). So the pairs and the
// floors live here, once; the lint asserts this list is empty for the
// shipped schemes, the validator asserts it for a candidate.
import 'package:flutter/material.dart';

import 'contrast.dart';
import 'status_colors.dart';

/// One pair that reads below its floor.
class ContrastFailure {
  const ContrastFailure({
    required this.pair,
    required this.ratio,
    required this.floor,
  });

  /// `foreground on background`, in the scheme's own words.
  final String pair;
  final double ratio;
  final double floor;

  @override
  String toString() => '$pair ${ratio.toStringAsFixed(2)}:1 < $floor:1';
}

/// WCAG AA text is 4.5:1; a UI component (outline, fill, icon) is 3:1.
const double contrastTextFloor = 4.5;
const double contrastComponentFloor = 3.0;

/// Every pair the app reads, measured on [theme]; empty when it passes.
///
/// The pairs are the ones the audit of #721 found the app reading most:
/// body and secondary text, primary and error text, the "paid" green,
/// outlines on every surface tint; and text on every filled component.
List<ContrastFailure> auditThemeContrast(ThemeData theme) {
  final cs = theme.colorScheme;
  final b = theme.brightness;
  final failures = <ContrastFailure>[];
  void check(String pair, Color fg, Color bg, double floor) {
    final r = Contrast.ratio(fg, bg);
    if (r < floor) failures.add(ContrastFailure(pair: pair, ratio: r, floor: floor));
  }

  final surfaces = <String, Color>{
    'surface': cs.surface,
    'surfaceContainerLow': cs.surfaceContainerLow,
    'surfaceContainer': cs.surfaceContainer,
    'surfaceContainerHigh': cs.surfaceContainerHigh,
    'surfaceContainerHighest': cs.surfaceContainerHighest,
    'scaffold': theme.scaffoldBackgroundColor,
    'card': theme.cardColor,
  };
  for (final s in surfaces.entries) {
    check('onSurface on ${s.key}', cs.onSurface, s.value, contrastTextFloor);
    check('onSurfaceVariant on ${s.key}', cs.onSurfaceVariant, s.value,
        contrastTextFloor);
    check('primary text on ${s.key}', cs.primary, s.value, contrastTextFloor);
    check('error text on ${s.key}', cs.error, s.value, contrastTextFloor);
    check('success text on ${s.key}', AppStatusColors.successTextOf(b), s.value,
        contrastTextFloor);
    check('success fill on ${s.key}', AppStatusColors.successOf(b), s.value,
        contrastComponentFloor);
    check('outline on ${s.key}', cs.outline, s.value, contrastComponentFloor);
  }
  check('onPrimary on primary', cs.onPrimary, cs.primary, contrastTextFloor);
  check('onSecondaryContainer on secondaryContainer', cs.onSecondaryContainer,
      cs.secondaryContainer, contrastTextFloor);
  check('onPrimaryContainer on primaryContainer', cs.onPrimaryContainer,
      cs.primaryContainer, contrastTextFloor);
  check('onError on error', cs.onError, cs.error, contrastTextFloor);
  check('onErrorContainer on errorContainer', cs.onErrorContainer,
      cs.errorContainer, contrastTextFloor);
  check('onSuccess on success', AppStatusColors.onSuccessOf(b),
      AppStatusColors.successOf(b), contrastTextFloor);
  check('onInverseSurface on inverseSurface', cs.onInverseSurface,
      cs.inverseSurface, contrastTextFloor);
  return failures;
}
