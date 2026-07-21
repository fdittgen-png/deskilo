// SPDX-License-Identifier: 0BSD
import 'package:freezed_annotation/freezed_annotation.dart';

part 'level.freezed.dart';

/// A floor of the workspace (spec §3).
@freezed
sealed class Level with _$Level {
  const Level._();

  const factory Level({
    required String id,
    required String workspaceId,
    required String name,
    required int sortOrder,

    /// Storage object path of the level's background image (a photo or
    /// blueprint of the real space, 0036), or null when none is set.
    String? backgroundPath,
  }) = _Level;

  /// Whether a background image is set for this level.
  bool get hasBackground => backgroundPath != null;
}
