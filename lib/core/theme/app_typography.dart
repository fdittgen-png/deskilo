// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

/// #1304 S2 — typography by ROLE, mapped onto the Material [TextTheme].
///
/// A screen asks for what a piece of text IS — a page title, a section
/// title, a value somebody came to read, the metadata beside it — and the
/// theme decides what that looks like. No role is a new size: each is a
/// [TextTheme] style (so it follows the reader's text scale and the dark
/// theme), and `lib/app/theme.dart` is where their weights are tuned.
/// `docs/ux/TYPOGRAPHY.md` is the table a designer reads.
extension AppTypography on TextTheme {
  /// The one title of a page. The app bar uses it.
  TextStyle? get pageTitle => titleLarge;

  /// A heading inside a page or sheet: "Support this project", a group.
  TextStyle? get sectionTitle =>
      titleSmall?.copyWith(fontWeight: FontWeight.w700);

  /// The value a reader came for: a seat name, an amount, a period.
  TextStyle? get primaryValue => titleMedium;

  /// Supporting facts beside a value: dates, counts, a hint of state.
  TextStyle? get metadata => bodySmall;

  /// The words on a button or chip.
  TextStyle? get actionLabel => labelLarge;

  /// Help under a field, and the error that replaces it.
  TextStyle? get helper => bodySmall;
}

/// Two weights, named, instead of a `FontWeight` chosen per widget.
extension AppTextEmphasis on TextStyle {
  /// Stands out within its role: a selected label, an initial on a tile.
  TextStyle get emphasised => copyWith(fontWeight: FontWeight.w600);

  /// The strongest weight a role may take: today's column, a heading.
  TextStyle get strong => copyWith(fontWeight: FontWeight.w700);
}
