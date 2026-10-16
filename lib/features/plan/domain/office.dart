// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/data/system_columns.dart';
import 'grid_geometry.dart';

part 'office.freezed.dart';

/// #2631 — what an office is for, persisted by name — never rename. A
/// parking area holds parking slots and no seat.
enum AreaKind { workspace, parking }

/// A room on a level (spec §3). `bookableAsWhole` makes the office itself
/// the reservable unit (meeting-room style); `priceCents` charges each
/// half-day of a whole-office reservation on the bill (0057, the 0050
/// level shape).
@freezed
sealed class Office with _$Office implements SystemStamped {
  const factory Office({
    required String id,
    required String workspaceId,
    required String levelId,
    required String name,
    required int color,
    required bool bookableAsWhole,
    @Default(0) int priceCents,
    required GridRect rect,
    /// #2631 — a parking area holds parking slots, never seats.
    @Default(AreaKind.workspace) AreaKind areaKind,
    /// #992 — the server's stamp on this row.
    @Default(SystemColumns.none) SystemColumns system,
  }) = _Office;
}
