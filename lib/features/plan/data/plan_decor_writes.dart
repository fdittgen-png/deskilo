// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3074 — the server side of the plan's drawn symbols: a symbol is a
// `plan_images` row with a `kind` and no storage object (0607), so it
// follows the photos' rect, RLS and cleanup unchanged.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/system_columns.dart';
import '../../../core/ids/request_id.dart';
import '../domain/grid_geometry.dart';
import '../domain/plan_image.dart';

mixin PlanDecorWrites {
  SupabaseClient get decorClient;

  /// Drops the cached plan after a write.
  Future<void> bustPlanCache();

  Future<PlanImage> createPlanDecor({
    required String workspaceId,
    required String levelId,
    required GridRect rect,
    required PlanDecorKind kind,
    String? imageId,
  }) async {
    final id = imageId ?? newRequestId();
    await decorClient.from('plan_images').upsert(
      {
        'id': id,
        'workspace_id': workspaceId,
        'level_id': levelId,
        'x': rect.x,
        'y': rect.y,
        'w': rect.w,
        'h': rect.h,
        'kind': kind.name,
      },
      onConflict: 'id',
      ignoreDuplicates: true,
    );
    await bustPlanCache();
    final row =
        await decorClient.from('plan_images').select().eq('id', id).single();
    return planImageFromRow(row);
  }

  Future<void> setPlanDecorTurns(String imageId, int quarterTurns) async {
    await decorClient
        .from('plan_images')
        .update({'quarter_turns': quarterTurns})
        .eq('id', imageId);
    await bustPlanCache();
  }

  /// A `plan_images` row as a photo or a symbol.
  PlanImage planImageFromRow(Map<String, dynamic> row) => PlanImage(
    system: SystemColumns.fromRow(row),
    id: row['id'] as String,
    levelId: row['level_id'] as String,
    rect: GridRect(
      x: row['x'] as int,
      y: row['y'] as int,
      w: row['w'] as int,
      h: row['h'] as int,
    ),
    storagePath: row['storage_path'] as String?,
    kind: PlanDecorKind.fromWire(row['kind'] as String?),
    quarterTurns: (row['quarter_turns'] as num?)?.toInt() ?? 0,
  );
}
