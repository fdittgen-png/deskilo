// SPDX-License-Identifier: 0BSD
import 'package:freezed_annotation/freezed_annotation.dart';

part 'accessory.freezed.dart';

/// A seat accessory of the workspace catalog (#166, epic #163) — monitor,
/// standing desk, ... Owner/admin-priced; deactivated, never deleted.
/// [supplementCents] is the per-half-day supplement (0.5 day = the billing
/// unit), summed per accessory on a seat; whether it is invoiced is a
/// later feature toggle (#170).
@freezed
sealed class Accessory with _$Accessory {
  const factory Accessory({
    required String id,
    required String workspaceId,
    required String name,
    required int supplementCents,
    required bool active,
    required int sortOrder,
  }) = _Accessory;
}
