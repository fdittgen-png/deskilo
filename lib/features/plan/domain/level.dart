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

    /// Whether the whole floor can be reserved as one booking (0050),
    /// like an office's bookable-as-whole.
    @Default(false) bool bookableAsWhole,

    /// Price of a whole-level reservation per half-day, in cents (0050);
    /// 0 = the level books free of supplement.
    @Default(0) int priceCents,
  }) = _Level;

  /// Whether a background image is set for this level.
  bool get hasBackground => backgroundPath != null;
}
