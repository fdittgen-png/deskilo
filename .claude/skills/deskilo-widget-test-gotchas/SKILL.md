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
| a narrow-width test still sees the wide layout | the pump helper pins the view — `pumpInvoices` sets 800×1400 and `addTearDown(reset)` | set the size AFTER the helper, then `pumpAndSettle()`; it is also the honest sequence (a window dragged narrow must fold too) |
| `find.text('Report editor')` passes on a title that reads "Rep…" | an ellipsised `Text` still holds the full string in the tree | assert the STRUCTURE that makes room — the overflow menu present, the icon buttons absent — never the string |
| a new width surfaces an overflow in an unrelated widget | it was always too wide; nothing had rendered it that narrow before | fix it in the same PR — shipping the bar while the body clips is half a fix (#1056: the app bar, then a 194 px Row in the designer's own toolbar) |
| a `Row` of chips/buttons overflows on a phone | `Flex` answers "too wide" by clipping | `Wrap` with `WrapAlignment.spaceBetween`; on a wide screen it lays out exactly as the Row did, and there is no breakpoint to guess at |
| a rect read after `scrollUntilVisible` puts a widget off-screen | its final `ensureVisible` jump is not pumped: `getRect` reads the OLD layout | `await tester.pumpAndSettle()` before any geometry assertion; and measure master before "fixing" a layout (#1660: a stale rect faked a 40 px results viewport) |
| a provider-error test never shows the error state | Riverpod 3 RETRIES a failed provider automatically | `ProviderScope(retry: (_, _) => null, …)` / `ProviderContainer(retry: …)` in failure tests |
| `tester.hasRunningAnimations` is true with reduced motion on | the tap's ink ripple is an animation too | assert position instead: the first frame's `getRect` equals the settled one; reduced motion via `platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: true)` |
| a "green" test also passes on master | it asserts a default or a stale reading | red-first against master (`git show origin/master:<file> > <file>`), then restore; if it stays green, the test proves nothing |
| an HTTP-fixture MFA test sees aal1 after a successful verify, or an unexpected `/auth/v1/token` call | gotrue's `mfa.listFactors()` calls `refreshSession()` first, and `getAuthenticatorAssuranceLevel()` reads the `aal` claim of the (refreshed) JWT | answer `grant_type=refresh_token` with a session at the level the refresh token was issued for (encode it in the token, as `mcp_target_second_factor_test` does); a parameterless `rpc()` posts the body `null`, not `{}` |
| a full-app test opens on `/me` instead of `/reserve` | #1823: a space is ENTERED, never assumed — with no space of this person's to return to the app opens on Me | `FakeWorkspaceRepository.withWorkspace()` seeds `serverDefaultWorkspaceId = 'ws-1'`; a hand-built fixture sets `serverDefaultWorkspaceId` itself (or seeds `InMemoryActiveWorkspaceStore` AND clears the server default when the test is about the device's memory) |
| a My-account tile (photo, language, theme, WhatsApp, linked accounts, hints) is not found under `/settings` | #1823 moved them into Me › Me; Settings keeps `settings-open-me` and the per-space exception | `openMyAccount(tester)` / `openMyPrivacy(tester)` from `test/helpers/open_my_account.dart` |
| `setState() or markNeedsBuild() called during build` from a listener on `router.routerDelegate` | the delegate notifies while the Router itself builds (`setInitialRoutePath`) | re-read in a post-frame callback (`LayerChrome`), and keep the tree above the navigator the SAME shape in every state — swapping widget types there rebuilds the Router and the splash |
| a widget test asserts a toggle that a `finally` never resets | `_busy` stuck after a hang | bound platform calls with `.timeout` so a hang becomes an error |
| a long press on a message bubble shows a tooltip, and its delete dialog never opens | an `IconButton` with a `tooltip:` INSIDE the long-pressable area wins the long-press arena at the bubble's centre | put the button BESIDE the bubble (a `Row` around it), never inside (#1824) |
| a tap that needs "signed in" pushes `/auth` in a bare `MaterialApp` test | `ref.read(authStateProvider)` on a stream nobody watches is still loading | watch it in a `Consumer` around `home` — in the app the router keeps it alive (#1824) |
| the second `pumpWidget` of the same screen with other arguments still shows the first one's data | same widget type at the same place REUSES its `State` (`late` fields keep the old id) | `pumpWidget(const SizedBox.shrink())` in between, or key the screen |
| a platform-channel feature needs a test | no device in `flutter test` | mock the channel (`setMockMethodCallHandler`) for Dart→native, and `handlePlatformMessage` with `StandardMethodCodec().encodeMethodCall` for native→Dart; the native half stays a manual device check, say so (#1824 `deskilo/capture`) |
| re-reading an autoDispose family provider in one test returns the FIRST answer | a kept listener keeps the element (and its cached value) alive | `container.invalidate(provider(arg))` before each fresh read (a pull to refresh), as `mcp_multi_target_journey_test` does |
| an awaited provider error is ALSO reported as an uncaught test failure | the `listen` subscription was closed right after the failing `read(.future)` | keep provider listeners until `addTearDown`; never close them in a `finally` next to the await |

Quick-view keys: `member-doc-quick` / `-download` / `-share` (one prefix
for every member letter), `vat-report-*`, `proforma-*`.
