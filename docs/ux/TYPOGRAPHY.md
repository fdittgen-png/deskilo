# Typography — roles, not sizes

*#1304 S2.* A screen says what a piece of text **is**; the theme decides what
it looks like. Every role is a Material `TextTheme` style, so it follows the
reader's text-size setting and the dark theme and is seen by `contrast_test`.
The code is `lib/core/theme/app_typography.dart`; weights are tuned once in
`lib/app/theme.dart`.

| role | `TextTheme` style | use it for |
|---|---|---|
| `pageTitle` | `titleLarge` (w700, tighter tracking) | the one title of a page; the app bar |
| `sectionTitle` | `titleSmall`, w700 | a heading inside a page or sheet |
| `primaryValue` | `titleMedium` (w600) | the value the reader came for: a seat, an amount, a period |
| `metadata` | `bodySmall` | supporting facts beside a value: dates, counts |
| `actionLabel` | `labelLarge` (w600) | words on buttons and chips |
| `helper` | `bodySmall` | help under a field, and the error that replaces it |

Two named weights replace a `FontWeight` picked per widget:

| weight | value | use it for |
|---|---|---|
| `.emphasised` | w600 | stands out within its role: a selected label, an initial on a tile |
| `.strong` | w700 | the strongest a role may take: today's column, a heading |

## Enforced

`test/lint/visual_tokens_test.dart` ratchets three literals per presentation
file — `fontSize:`, `Color(0x` and `fontWeight: FontWeight` — which may only
go down. A painter's canvas and the report designer's print-size page keep
theirs honestly, with no `TextTheme` to ask.

## Not a second design system

No role introduces a size the `TextTheme` does not already have. If a screen
seems to need one, the hierarchy of that screen is the problem, not the
scale.
