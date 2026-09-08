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
| `No element` from `scrollUntilVisible` | `find.byType(Scrollable).first` picked another scrollable (a banner, a carousel) | key the ListView (`deploy-list`) and pass `find.descendant(of: byKey, matching: byType(Scrollable)).first` |
| a sheet's confirm button is off-screen on a phone | the bottom sheet is a plain Column | `showModalBottomSheet(isScrollControlled: true, constraints: maxHeight 85%)` + `Flexible(child: ListView(shrinkWrap: true))`, buttons outside the list; assert `tester.getRect(confirm).bottom <= height` at 400×560 |
| the system bar covers a button in a test | no inset simulated | `tester.view.viewPadding = tester.view.padding = const FakeViewPadding(bottom: 100)`; the root `SystemInsetsGuard` (#1008) keeps content above it |
| a pair test finds no DEV side | the fake workspace's default `environment` is `'prod'` (environment_banner_test) | `copyWith(environment: 'dev')` explicitly |
| `find.text('Subscription 50%')` fails | the line now names its month (#1000) | `find.textContaining(RegExp(r'^Subscription \w+ 50%$'))` |
| a test appended at EOF lands inside a trailing class | the file ends with a helper class after `main` | insert before `main`'s closing brace, not at EOF |
| the settings list grew and a tile tap misses | Advanced/Administration gained rows | viewport 3100 → 3300, or `scrollUntilVisible` on the settings list |
| `expect(find.text('Sign out'))` finds nothing | same growth | same fix |
| a widget test asserts a toggle that a `finally` never resets | `_busy` stuck after a hang | bound platform calls with `.timeout` so a hang becomes an error |

Quick-view keys: `member-doc-quick` / `-download` / `-share` (one prefix
for every member letter), `vat-report-*`, `proforma-*`.
