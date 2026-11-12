// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3773 — the tab indices, apart from the widgets that draw them, so the
// route table (route_classes.dart) can name a tab by its constant.

/// Branch indices of the stateful shell (order = bottom-bar order).
///
/// The integers never move: `StatefulShellRoute` keeps each branch's state
/// by index, so renumbering would hand one destination another's history.
/// #1306 — the names say what the branches ARE today; `plan` rendered the
/// Messages destination since #687 moved the plan to the Reserve hub.
abstract final class ShellBranch {
  /// The messaging centre (#687). Core: never feature-gated.
  static const int messages = 0;
  static const int calendar = 1;

  /// The member directory (#230).
  static const int directory = 2;
  static const int money = 3;

  /// The raised centre button's branch — not a bar destination, but a
  /// branch so the bar stays visible and functional on the hub. Core
  /// like Messages: never feature-gated, active by default.
  static const int reserve = 4;
}
