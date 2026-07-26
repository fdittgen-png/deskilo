// SPDX-License-Identifier: 0BSD
import 'package:freezed_annotation/freezed_annotation.dart';

import 'grid_geometry.dart';

part 'desk.freezed.dart';

/// A piece of furniture inside an office, drawn on the grid (spec §3).
/// `bookableAsWhole` + `priceCents` make the desk itself a reservable
/// unit (0059, the 0050/0057 shape).
@freezed
sealed class Desk with _$Desk {
  const factory Desk({
    required String id,
    required String workspaceId,
    required String officeId,
    required String name,
    @Default(false) bool bookableAsWhole,
    @Default(0) int priceCents,
    required GridRect rect,
  }) = _Desk;
}
