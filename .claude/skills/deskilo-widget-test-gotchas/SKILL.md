---
name: deskilo-widget-test-gotchas
description: The recurring reasons a DesKilo widget or lint test fails for a reason that is not the feature — help-dot tiles, lazily built lists, queued snackbars, provider-fed PDF exits needing runAsync, taller columns pushing toolbars off-screen, pinned counts, no_wall_clock, hard-coded Text literals, format churn, background suites. Trigger when a test fails with "No element", a missed tap warning, an unexpected count, or after adding UI to an existing screen.
---
# Widget & lint test gotchas (DesKilo)

| Symptom | Cause | Fix |
|---|---|---|
| tap on a `ListTile` with `HelpDotTitle` navigates to `/help?topic=` | the tile's centre is the help dot | tap the leading icon: `find.descendant(of: byKey(tile), matching: byIcon(...))` |
| `No element` on a key that exists | lazy `ListView`/`Drawer` did not build it | `scrollUntilVisible(finder, ±delta, scrollable: find.byType(Scrollable).first)`; scroll DOWN then UP (see `_reveal` in `shell_drawer_test`) |
| a second `AppSnack` text is never found | snackbars queue behind the visible one | `await tester.pump(const Duration(seconds: 5))` before asserting the next |
| tap on a toolbar toggle silently misses after adding a panel | the column grew taller than the viewport | make the new panel collapsed by default (ExpansionTile) AND `ensureVisible` in the helper |
| PDF download test saves nothing after a layout change | the layout path awaits providers/fonts/images | run the whole exit inside `tester.runAsync(() async { tap; pump; pumpAndSettle })` |
| `Found N widgets` counts off by one | a registry grew (validation cards, features switches, placeholders) | bump the pin with a dated comment; the features-screen test needs a taller `physicalSize` |
| `no_wall_clock` lint | `DateTime.now()` in a fake | `kTestNow` |
| `no_hardcoded_strings` lint | `Text('$x')` literal | hoist into `final count = '$x'; Text(count)` |
| `file_length` lint | a file outgrew its budget | bump with `// YYYY-MM-DD #issue reason` |
| hundreds of changed lines in a file you barely touched | `dart format` on an unformatted legacy file | `git checkout -- file` and re-apply the edit |
| a suite result contradicts the code | a `flutter test` ran in the background across a branch switch | never switch branches while a suite runs; re-run |
| `Crash when compiling … FFI` in a test run | flaky toolchain crash in build hooks | re-run; not the code |
| fixture documents render in German | the test workspace resolves reader language to DE | assert the German title (`Verbrauchsbericht`) or the preview key `report-quick-preview` |
| `tester.widget<FilledButton>` on `FilledButton.icon` | works — it IS a FilledButton | keep |

Quick-view keys: `member-doc-quick` / `-download` / `-share` (one prefix
for every member letter), `vat-report-*`, `proforma-*`.
