// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

part 'grid_geometry.freezed.dart';

/// Axis-aligned rectangle in grid cells (ADR 0005). `x`/`y` is the top-left
/// cell; `w`/`h` are strictly positive cell counts.
@freezed
sealed class GridRect with _$GridRect {
  const GridRect._();

  const factory GridRect({
    required int x,
    required int y,
    required int w,
    required int h,
  }) = _GridRect;

  int get right => x + w;
  int get bottom => y + h;

  bool overlaps(GridRect other) =>
      x < other.right && other.x < right && y < other.bottom && other.y < bottom;

  bool containsRect(GridRect other) =>
      other.x >= x && other.y >= y && other.right <= right && other.bottom <= bottom;

  bool containsCell(int cx, int cy) =>
      cx >= x && cx < right && cy >= y && cy < bottom;
}
