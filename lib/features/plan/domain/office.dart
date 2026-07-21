// SPDX-License-Identifier: 0BSD
import 'package:freezed_annotation/freezed_annotation.dart';

import 'grid_geometry.dart';

part 'office.freezed.dart';

/// A room on a level (spec §3). `bookableAsWhole` makes the office itself
/// the reservable unit (meeting-room style).
@freezed
sealed class Office with _$Office {
  const factory Office({
    required String id,
    required String workspaceId,
    required String levelId,
    required String name,
    required int color,
    required bool bookableAsWhole,
    required GridRect rect,
  }) = _Office;
}
