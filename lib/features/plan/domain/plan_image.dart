// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/data/system_columns.dart';
import 'grid_geometry.dart';

part 'plan_image.freezed.dart';

/// The drawn symbols a plan can carry besides photos (0607): the walls,
/// doors and furniture of the real room. The wire name is the server's.
enum PlanDecorKind {
  wall,
  door,
  window,
  pillar,
  table,
  couch,
  wc,
  kitchen;

  static PlanDecorKind? fromWire(String? wire) {
    for (final k in values) {
      if (k.name == wire) return k;
    }
    return null;
  }

  /// The footprint a fresh symbol takes, in grid cells.
  ({int w, int h}) get defaultSize => switch (this) {
    wall => (w: 12, h: 1),
    door => (w: 3, h: 3),
    window => (w: 6, h: 1),
    pillar => (w: 2, h: 2),
    table => (w: 8, h: 4),
    couch => (w: 6, h: 3),
    wc => (w: 3, h: 3),
    kitchen => (w: 6, h: 3),
  };
}

/// A resizable illustration image placed on a level's plan (0037): a
/// photo of the real space positioned and sized over the grid, distinct
/// from the whole-level background (0036). Free to overlap anything —
/// it's decor, not a bookable element. A drawn symbol ([kind]) has no
/// photo: no [storagePath], turned in quarter turns.
@freezed
sealed class PlanImage with _$PlanImage implements SystemStamped {
  const factory PlanImage({
    required String id,
    required String levelId,
    required GridRect rect,
    String? storagePath,

    /// 0607 — the symbol this draws instead of a photo.
    PlanDecorKind? kind,

    /// 0607 — clockwise quarter turns of a symbol, 0..3.
    @Default(0) int quarterTurns,
    /// #992 — the server's stamp on this row.
    @Default(SystemColumns.none) SystemColumns system,
  }) = _PlanImage;
}
