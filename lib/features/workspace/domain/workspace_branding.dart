// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1289 — a workspace's colours, as stored and as the app reads them.
//
// The map is the server's (`workspaces.branding`, validated by
// `branding_clean` in 0246): a seed colour the themes derive from, an
// office fill palette, the key of a curated seat palette. This is the
// one reader of that map; nothing else parses a hex string. Pure Dart:
// colours are ARGB integers here, `Color` is the presentation's.

import 'workspace.dart';
import 'workspace_feature.dart';

/// #2313 — whether [space] itself has branding on: ITS flags, not the
/// active space's — the Me list and the entry show several at once.
bool brandingOn(Workspace space) =>
    effectiveFeatures(resolveEnabledFeatures(space.featureFlags))
        .contains(WorkspaceFeature.workspaceBranding);

/// The keys of `workspaces.branding` — the three the server accepts.
abstract final class BrandingKeys {
  static const seedColor = 'seed_color';
  static const officePalette = 'office_palette';
  static const seatPalette = 'seat_palette';
  static const symbolText = 'symbol_text';
  static const symbolColor = 'symbol_color';

  /// #2313 (0397) — how the colour is drawn where the space is told apart.
  static const pattern = 'pattern';
}

/// #2313 — the curated patterns a space's colour is drawn in on its card,
/// its chip and the entry transition (the server's list, 0397).
enum BrandPattern {
  solid,
  stripes,
  dots,
  grid,
  waves;

  /// The stored value, or null for anything else.
  static BrandPattern? fromWire(Object? raw) =>
      values.where((p) => p.name == raw).firstOrNull;
}

/// The curated colours a workspace symbol may wear (the server's list, 0378).
const List<String> symbolColours = [
  '#C2410C', '#B45309', '#4D7C0F', '#15803D', '#0F766E', '#0369A1',
  '#1D4ED8', '#6D28D9', '#A21CAF', '#BE185D', '#B91C1C', '#475569',
];

/// One or two letters on a colour — a workspace's mark when it has no photo.
/// The pair is unique across workspaces (0378).
class WorkspaceSymbol {
  const WorkspaceSymbol(this.text, this.colourHex);
  final String text;
  final String colourHex;

  /// The stored symbol, or null when the workspace has none.
  static WorkspaceSymbol? of(Map<String, dynamic> branding) {
    final t = branding[BrandingKeys.symbolText];
    final c = parseHexColor(branding[BrandingKeys.symbolColor]);
    if (t is! String || t.isEmpty || c == null) return null;
    return WorkspaceSymbol(t, branding[BrandingKeys.symbolColor] as String);
  }

  int get argb => parseHexColor(colourHex)!;
}

/// Another workspace already wears this letters-and-colour pair.
class WorkspaceSymbolTaken implements Exception {
  const WorkspaceSymbolTaken();
  @override
  String toString() => 'WorkspaceSymbolTaken';
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
    this.pattern,
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
      pattern: BrandPattern.fromWire(json[BrandingKeys.pattern]),
    );
  }

  /// The brand seed as opaque ARGB, null for the product's own palette.
  final int? seedArgb;

  /// Office fills, in order; empty for the product's palette.
  final List<int> officePalette;

  /// The curated seat palette key; null for the product's.
  final String? seatPalette;

  /// #2313 — how the colour is drawn on the space's card, chip and entry;
  /// null when the owner chose none (a plain fill).
  final BrandPattern? pattern;

  bool get isEmpty =>
      seedArgb == null &&
      officePalette.isEmpty &&
      seatPalette == null &&
      pattern == null;
}

/// True when another of [others] (id → branding) already wears [mine].
bool symbolClashes(
  WorkspaceSymbol mine,
  Iterable<Map<String, dynamic>> others,
) =>
    others.any((b) {
      final o = WorkspaceSymbol.of(b);
      return o?.text == mine.text && o?.colourHex == mine.colourHex;
    });
