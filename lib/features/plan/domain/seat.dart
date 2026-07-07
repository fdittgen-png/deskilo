// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

import 'grid_geometry.dart';

part 'seat.freezed.dart';

/// Where the sitter faces. Persisted by name — never rename values.
enum SeatOrientation { n, e, s, w }

/// The normative seat footprint (product brief): 6 cells along the sitting
/// edge × 4 cells deep. Pinned by test.
abstract final class SeatFootprint {
  static const int length = 6;
  static const int depth = 4;
}

/// THE bookable unit (spec §3). `x`/`y` is the footprint's top-left cell;
/// the footprint size follows from [orientation].
@freezed
sealed class Seat with _$Seat {
  const Seat._();

  const factory Seat({
    required String id,
    required String workspaceId,
    required String deskId,
    required String name,
    required int x,
    required int y,
    required SeatOrientation orientation,
    required String chair,
    required List<String> amenities,
    DateTime? blockedFrom,
    DateTime? blockedTo,
  }) = _Seat;

  /// 6×4 for n/s (sitting edge horizontal), 4×6 for e/w.
  GridRect get footprint {
    final horizontal = orientation == SeatOrientation.n ||
        orientation == SeatOrientation.s;
    return GridRect(
      x: x,
      y: y,
      w: horizontal ? SeatFootprint.length : SeatFootprint.depth,
      h: horizontal ? SeatFootprint.depth : SeatFootprint.length,
    );
  }

  /// Blocked for maintenance at [at]? Open-ended bounds supported (spec §10).
  bool isBlockedAt(DateTime at) {
    if (blockedFrom == null && blockedTo == null) return false;
    final afterStart = blockedFrom == null || !at.isBefore(blockedFrom!);
    final beforeEnd = blockedTo == null || at.isBefore(blockedTo!);
    return afterStart && beforeEnd;
  }
}
