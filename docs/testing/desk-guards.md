# Desk guards

The experience guards (`test/ux/experience_guards.dart`) check a page as a person meets it. Since #3605 they also run at desk sizes, through the app's builder (frame, desk and shell in the tree).

## Sizes
- Phones: `guardWidths` (320, 390) and a wide window (1280).
- Desk: `deskGuardSizes`: 1024 × 768, 1440 × 900, 1920 × 1080.

## The rules
`deskGuardProblems(tester, kind:, size:, policy:, rowTypes:, tableTypes:)` names every rule the page on screen breaks:
- **No exception and no overflow.**
- **Text.** No body text runs wider than `bodyTextMaxWidth` (760) outside a table row.
- **Records pages.** At 1440, the table takes `recordsTableMinShare` (60 %) of the window at least.
- **Targets** are measured on hit regions (semantics), by policy:
  - `TargetPolicy.desk`: a table row may be `deskRowMinHeight` (36) high, since every row action is also reached by the keyboard and the row menu. Every other control is 48 × 48.
  - `TargetPolicy.touch`: everything is 48, rows included. Use it where the device reports touch in the desk posture.
- **Names.** Every tappable control has a name.

`keyboardProblems(tester)` checks the keyboard contract:
- Tab reaches every Tab stop exactly once in a cycle.
- A control that Tab skips (a row inside a composite) is reached by an arrow key from a Tab stop.
- Nothing is left that no key reaches.

`escapeProblems(tester, surfaces:, dirty:)` checks Escape on the top surface: a clean one closes, and a dirty one asks before discarding (one more surface on top, the first still there).

- **A switch inside a tile that is the tap target** (a `SwitchListTile`: the whole row toggles and the tile carries the name) is measured by the tile (#3860). Flutter keeps the switch's own 60 × 40 node as a child of the tile's; it is the same action, not a second target. A switch, checkbox or radio that stands alone is still measured and named; a button inside a tappable tile is still its own target.

The page kinds (`PageKind.records`, `task`, `dashboard`, `document`, `recordBesideTable`) decide which rules apply.

`PageKind.recordBesideTable` (#3860) is a record open in the pane beside its records table (`ListDetailScaffold`). The 60 % rule does not hold it (the table cannot and should not take it); its own measures do: the table keeps at least `besideTableMinWidth` (400), the pane is at most `besidePaneMaxWidth` (640), table, grip and pane fill the work area without a gap, no word of a table row is cut, and rows keep their height. Below a large window the record is a page of its own: guard it as `document`. The table gets there by priority: a `RecordColumn` declares `staysBeside`; with the pane open the table shows its staying columns (and the ones that may not be hidden), closing the pane brings the rest back, and the person's hidden columns hold. Each rule has a self-test that fails a planted page (`test/ux/desk_guards_test.dart`).

## Where they run
`test/ux/desk_guard_pages_test.dart`: `/invoices` (records) and the Me overview, and the records pages with a record open beside them (`/money/suppliers/<id>`, `/money/purchases/doc/<id>`), at the three desk sizes. A page joins by adding its line to `_pages`.

## Sheets
```
SHEET=1 ~/.claude/hooks/guarded-flutter-test.sh test/ux/desk_guard_pages_test.dart
```
This writes `build/sheets/<module>/<screen>--<width>--<light|dark>.png` at 390 and 1440, in light and dark, with Roboto and the icon font loaded. Attach the sheets to the pull request; they are never committed.
