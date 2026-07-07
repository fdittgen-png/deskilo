// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

part 'level.freezed.dart';

/// A floor of the workspace (spec §3).
@freezed
sealed class Level with _$Level {
  const factory Level({
    required String id,
    required String workspaceId,
    required String name,
    required int sortOrder,
  }) = _Level;
}
