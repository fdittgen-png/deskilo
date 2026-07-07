# DesKilo design system

Sibling of Sparkilo's design system — same language, own hue. Spec §14.

## Brand palette (decided 2026-07-07: orange)

Defined once in `lib/app/theme.dart` (`_burntOrange`, a `FlexSchemeColor`); Material 3 via flex_color_scheme.

| Token | Value | Note |
|---|---|---|
| primary | `#C2410C` | muted burnt orange — the brand color |
| primaryContainer | `#F4D8C4` | |
| secondary | `#8A5A33` | warm brown |
| secondaryContainer | `#EBDCC9` | also the app-bar tint |
| tertiary | `#3C6E63` | muted teal — deliberately quotes Sparkilo's tertiary |
| tertiaryContainer | `#CFE3DC` | |
| error | `#B3261E` | |

**Three themes** (`DeskiloTheme`): `light()` (blend 8), `dark()` (`toDark(28)`, blend 22), and the signature orange-forward `warm()` (blend 20, primaryContainer app bar) — the analog of Sparkilo's `eco()`.

## Radius tokens (`AppRadius`, lib/core/theme/app_radius.dart)

sm 4 · md 8 · **lg 12 (canonical card/input/button)** · xl 16 (dialogs, sheets, chips) · xxl 24 (hero). Inline `BorderRadius.circular(n)` is banned (lint test).

## Seat-state palette (`SeatStateColors`, lib/core/theme/seat_state_colors.dart)

The analog of Sparkilo's fuel-color palette. Light / dark:

| State | Light | Dark |
|---|---|---|
| free | `#4F7C44` | `#8BC34A` |
| reserved | `#3B6FA0` | `#7FB2E5` |
| occupied | `#BE7C1E` | `#E8B04E` |
| mine | `#C2410C` | `#FF8A50` |
| blocked | `#6B7280` | `#9CA3AF` |

Hues sit on the blue↔orange axis plus lightness contrast (deuteranopia/protanopia-aware). **State is never conveyed by color alone** — the floor plan pairs every state with an icon/pattern (spec §11).

## Rules

- All colors come from `Theme.of(context).colorScheme` or the token classes above — no inline `Color(0x…)` in feature code.
- Typography: Material 3 defaults (`useMaterial3Typography`), no custom fonts for now.
- SnackBars float; inputs use outline borders (see `_subThemes`).
