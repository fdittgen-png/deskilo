// SPDX-License-Identifier: AGPL-3.0-or-later

/// The wide discovery layout: the loaded list and the map side by side,
/// 53:47, only where each pane keeps at least [minPane] logical pixels.
/// Narrower, one view shows at a time and the list stays the first face.
abstract final class DiscoverySplit {
  static const int listFlex = 53;
  static const int mapFlex = 47;
  static const double minPane = 330;

  /// Whether [width] holds both panes at their share, each at least
  /// [minPane] wide. The map's share is the smaller, so it decides.
  static bool fits(double width) =>
      width * mapFlex / (listFlex + mapFlex) >= minPane;
}
