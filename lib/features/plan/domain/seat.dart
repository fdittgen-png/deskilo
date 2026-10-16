// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/data/system_columns.dart';
import 'grid_geometry.dart';

part 'seat.freezed.dart';

/// Where the sitter faces. Persisted by name — never rename values.
enum SeatOrientation { n, e, s, w }

/// What a bookable resource of the plan is (#2631). A room and a parking
/// slot are rows of the same table as a seat, so booking, conflicts and
/// billing are the ones that exist; the kind is fixed at creation and
/// persisted by name — never rename values.
enum ResourceKind { seat, room, parking }

/// The normative seat footprint (product brief): 6 cells along the sitting
/// edge × 4 cells deep. Pinned by test.
abstract final class SeatFootprint {
  static const int length = 6;
  static const int depth = 4;
}

/// THE bookable unit (spec §3). `x`/`y` is the footprint's top-left cell;
/// the footprint size follows from [orientation].
@freezed
sealed class Seat with _$Seat implements SystemStamped {
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
    /// #585 — the chair's physical NFC/RFID tag uid (normalized
    /// lowercase hex); tapping it resolves to this seat like its QR.
    String? nfcUid,
    /// #2631 — this resource's own booking slot in minutes (5, 15, 30, 60
    /// or 1440 for the full day); null = the workspace's granularity.
    int? slotMinutes,
    /// #2631 — seat (default), meeting room or parking slot.
    @Default(ResourceKind.seat) ResourceKind resourceKind,
    /// #2631 — people a meeting room holds; null for everything else.
    int? capacity,
    /// #992 — the server's stamp on this row.
    @Default(SystemColumns.none) SystemColumns system,
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
