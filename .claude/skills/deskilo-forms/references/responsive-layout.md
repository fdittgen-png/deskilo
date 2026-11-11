# Responsive layout diagnosis

## Reproduce the consumer

Record the screen, route, fixture state, logical viewport, text scale, locale,
theme and keyboard inset. Reproduce the first layout exception, including its
parent constraints; later render failures can be consequences of that error.
Use the screen's existing pump helper and fixtures before inventing a harness.
`test/helpers/pump_app.dart` accepts logical size, pixel ratio, locale, text
scale and explicit provider overrides; it does not supply an authenticated user.

For the experience matrix, reuse `guardWidths` and `guardScales` from
`test/ux/experience_guards.dart` (320/390/1280 dp; 1.0/1.3). Exercise the
affected surface in EN/FR/DE/ES/IT, light/dark and its relevant loading, empty,
error and saving states. Preserve broader accessibility checks already owned
by `test/a11y/responsive_matrix_test.dart`, including 2x text. This is a focused
consumer check, not an instruction to run every screen locally.

## Repair the constraint that fails

| Observation | Inspect and repair |
|---|---|
| A field has no finite width | Inspect its enclosing Row and give the field a bounded share with Flexible/Expanded. Check that the Flex itself has bounded width. |
| A scrollable has no finite height | Inspect the enclosing Column and scroll owner. Use the kit's bounded body; Expanded requires a finite remaining height and cannot repair an unbounded ancestor. |
| Actions or translated labels exceed a row | Use the existing adaptive scaffold, a Wrap for independent controls, or flex for wrapping text. Choose from the space the parent actually offers, not an OS/device label. |
| A sheet action disappears with the keyboard | Keep AppFormSheet's pinned footer and scrollable body. Reproduce the keyboard inset and validation errors; do not make the test viewport taller to hide the defect. |
| The wrong responsive branch survives resize | Check whether a helper resets the size, then resize the mounted surface and pump again. Verify both the initial narrow layout and a wide-to-narrow transition. |

Use `LayoutBuilder` for the component's available constraints; use `MediaQuery`
for the view's text scaling and insets. Keep shared tokens and the existing
form kit. Avoid fixed heights that only fit the current translation, truncating
an essential action label or shrinking text to make a failed case disappear.

## Prove the repair

Use `guardProblems` with semantics enabled for overflow, named controls and
target-size checks. Add the assertion that expresses the actual defect:
reachable confirm action, correct adaptive controls, visible field error or
preserved form input after resize. Tap the action and verify its outcome; a
matching Text widget alone cannot prove that its full label is visible.

`pumpApp` restores its size and pixel ratio. Restore any additional dispatcher
or view overrides with `addTearDown`; dispose semantics handles. Model keyboard
insets as `test/helpers/screens/onboarding_layout.dart` does. Pump after a
scroll/resize before reading geometry. Use structural assertions, never
platform-baselined golden PNGs. Service fixtures remain fakes; Mocktail is only
for widget-level callbacks.

For a running app, inspect the connected server's actual tool list and selected
app before using inspector/runtime-error or reload capabilities. Do not assume
upstream examples' tool names exist. Use scoped CLI test paths for execution.
Follow `deskilo-ship-feature` for preflight and local gates: no full local suite,
no `dart fix`, and no formatting existing files or directories.

Visual evidence uses Demo data and the existing `tool/guide_shots` or
`tool/media.dart` workflow. A screenshot is a review artifact; it does not prove
a tap, native permission dialog or platform behavior. Record unexecuted device
checks as NOT RUN, with the exact platform and scenario.

## Source provenance

Original Deskilo guidance, checked against repository helpers and rules for
#3755 on 2026-11-11. Technical references: Flutter's
[layout diagnosis](https://github.com/flutter/agent-plugins/blob/main/skills/flutter-fix-layout-issues/SKILL.md),
[responsive layout](https://github.com/flutter/agent-plugins/blob/main/skills/flutter-build-responsive-layout/SKILL.md)
and Dart's [static analysis](https://github.com/dart-lang/skills/blob/main/skills/dart-run-static-analysis/SKILL.md).
Those upstream repositories use BSD-3-Clause; no upstream skill or code is
vendored here. Their generic setup/fix commands do not replace Deskilo's rules.
