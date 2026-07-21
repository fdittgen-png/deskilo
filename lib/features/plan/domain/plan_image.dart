// SPDX-License-Identifier: 0BSD
import 'package:freezed_annotation/freezed_annotation.dart';

import 'grid_geometry.dart';

part 'plan_image.freezed.dart';

/// A resizable illustration image placed on a level's plan (0037): a
/// photo of the real space positioned and sized over the grid, distinct
/// from the whole-level background (0036). Free to overlap anything —
/// it's decor, not a bookable element.
@freezed
sealed class PlanImage with _$PlanImage {
  const factory PlanImage({
    required String id,
    required String levelId,
    required GridRect rect,
    required String storagePath,
  }) = _PlanImage;
}
