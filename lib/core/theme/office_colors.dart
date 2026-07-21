// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

/// Muted office fill palette (spec §10: offices carry a color). Indexed by
/// the office's persisted `color` int; index wraps.
abstract final class OfficeColors {
  static const List<Color> palette = [
    Color(0xFFEBDCC9), // warm sand (brand secondaryContainer)
    Color(0xFFCFE3DC), // muted teal
    Color(0xFFD6DEEB), // muted blue
    Color(0xFFE3D6E8), // muted mauve
    Color(0xFFDCE8CF), // muted green
    Color(0xFFF4D8C4), // brand primaryContainer
    Color(0xFFE8E4D4), // stone
    Color(0xFFD9E4E8), // mist
  ];

  static Color of(int index) => palette[index % palette.length];
}
