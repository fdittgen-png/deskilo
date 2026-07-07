// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

import 'grid_geometry.dart';

part 'desk.freezed.dart';

/// A piece of furniture inside an office, drawn on the grid (spec §3).
@freezed
sealed class Desk with _$Desk {
  const factory Desk({
    required String id,
    required String workspaceId,
    required String officeId,
    required String name,
    required GridRect rect,
  }) = _Desk;
}
