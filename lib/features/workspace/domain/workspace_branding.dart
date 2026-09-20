// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1289 — a workspace's colours, as stored and as the app reads them.
//
// The map is the server's (`workspaces.branding`, validated by
// `branding_clean` in 0246): a seed colour the themes derive from, an
// office fill palette, the key of a curated seat palette. This is the
// one reader of that map; nothing else parses a hex string. Pure Dart:
// colours are ARGB integers here, `Color` is the presentation's.

/// The keys of `workspaces.branding` — the three the server accepts.
abstract final class BrandingKeys {
  static const seedColor = 'seed_color';
  static const officePalette = 'office_palette';
  static const seatPalette = 'seat_palette';
}

/// `#RRGGBB` → opaque ARGB, or null for anything else. Case-insensitive,
/// the way the server stores it upper-case.
int? parseHexColor(Object? raw) {
  if (raw is! String) return null;
  final m = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(raw.trim());
  if (m == null) return null;
  return 0xFF000000 | int.parse(m.group(1)!, radix: 16);
}

/// ARGB → `#RRGGBB`, upper-case, the alpha dropped.
String hexOfColor(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

class WorkspaceBranding {
  const WorkspaceBranding({
    this.seedArgb,
    this.officePalette = const [],
    this.seatPalette,
  });

  /// Reads the stored map; a malformed value reads as absent, never as a
  /// crash — the server validated what it stored, an older client may
  /// still meet a newer key.
  factory WorkspaceBranding.fromJson(Map<String, dynamic> json) {
    final palette = json[BrandingKeys.officePalette];
    return WorkspaceBranding(
      seedArgb: parseHexColor(json[BrandingKeys.seedColor]),
      officePalette: [
        if (palette is List)
          for (final c in palette) ?parseHexColor(c),
      ],
      seatPalette: json[BrandingKeys.seatPalette] is String
          ? json[BrandingKeys.seatPalette] as String
          : null,
    );
  }

  /// The brand seed as opaque ARGB, null for the product's own palette.
  final int? seedArgb;

  /// Office fills, in order; empty for the product's palette.
  final List<int> officePalette;

  /// The curated seat palette key; null for the product's.
  final String? seatPalette;

  bool get isEmpty =>
      seedArgb == null && officePalette.isEmpty && seatPalette == null;
}
