// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- the dimensions of the shared kit, one place. Colours come from
// the ambient Theme (its ColorScheme), type from its text theme, never from
// here: the same part renders under the workspace and the personal theme.

/// The kit's dimensions.
abstract final class KitMetrics {
  /// The inside of a card.
  static const double cardPadding = 14;

  /// The leading tile of a row.
  static const double tile = 38;

  /// The smallest tap target.
  static const double minTarget = 48;

  /// The gap between the parts of a row.
  static const double gap = 10;

  /// The space between a button's progress mark and its label.
  static const double buttonGap = 8;

  /// The widest a dropdown grows on a wide line (#3545).
  // content-fit: a dropdown never stretches past the length of its longest choice
  static const double dropdownMaxWidth = 240;

  /// The size of the progress mark inside a busy button.
  static const double progressMark = 18;

  /// The height of a split bar.
  static const double barHeight = 12;

  /// The narrowest a part of a split bar is drawn, so a small share shows.
  static const double barMinPart = 6;

  /// The widest a task opened at the desk grows (a centred dialog), so a form
  /// keeps its line length on a wide window (`showTaskSurface`, #3608).
  static const double taskDialogMaxWidth = 560;

  /// #3627 — the narrowest a door card is laid out on a desk grid.
  // content-fit: a door card holds its icon, a title of two or three words and its chevron
  static const double doorMinWidth = 240;

  /// The dot of a legend line.
  static const double dot = 12;

  /// #3628 — a list of choices beside the one shown at the desk (the roles
  /// of the space, the sections of a settings page).
  static const double choiceListWidth = 280;
}
