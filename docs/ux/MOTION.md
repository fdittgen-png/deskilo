<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# Motion

#1304 S3. **The motion vocabulary DesKilo already has, named once, so the
next animation reuses a word instead of inventing a duration.** No new
animation is introduced by this document.

## The one question

Every animated surface asks `motionDuration(context, token)`
(`lib/core/motion/motion.dart`). It answers the token while motion is on and
`Duration.zero` otherwise, where *on* means both:

- the workspace's `uiAnimations` feature (installed above the navigator by
  `MotionSettings`), and
- the platform's reduced-motion setting (`MediaQuery.disableAnimations`).

A surface that decides for itself whether to animate is a defect: it
animates for somebody who asked the whole device to stop.

**When the duration is zero, build no animated wrapper at all.**
`AnimatedSize` with a zero duration re-dirties itself during layout and
asserts; `MotionReveal` returns its child bare for that reason. A
reduced-motion user gets the **same final state**, instantly — never a
different one.

## The tokens

| token | value | curve | for |
|---|---|---|---|
| `MotionTokens.quick` | 150 ms | `ease` | small in-place feedback: a badge count, an icon swap |
| `MotionTokens.standard` | 250 ms | `ease` | the workhorse: state colours, reveals, the success check |
| `MotionTokens.emphasized` | 350 ms | `enter` | larger spatial changes: the month slide, zoom-to-target |
| `AppMotion.viewSwitch` | 200 ms | — | cross-fading a view toggle (plan ↔ list, calendar views) |
| `AppMotion.loadingFadeIn` | 200 ms | — | `LoadingView`'s spinner fades in, so a quick load never flashes one |
| `kShellBarHideDuration` | 220 ms | `ease` | the bottom bar (and the title bar with it, #1322) leaving and returning |

`MotionTokens.ease` is Material 3 standard easing (in-place changes);
`MotionTokens.enter` is emphasized-decelerate (things entering the screen).
Everything is finite, so `pumpAndSettle` always settles — the one looping
exception is the swipe coach mark, which runs a bounded number of nudges.

## The vocabulary

| intent | how, today | where |
|---|---|---|
| **Page transition** | `FadeForwardsPageTransitionsBuilder`, swapped for no transition when motion is off | `lib/app/theme.dart` `_pageTransitions` |
| **Sheet entrance / exit** | Material's own bottom-sheet motion; nothing custom | every `showModalBottomSheet` |
| **Selection / state change** | the seat colour lerps from its previous state (`previousSeatStates` + `seatStateLerp`) over `standard` | `plan_canvas.dart`, `floor_plan_painter.dart` |
| **Content appearing / disappearing** | `MotionReveal`: size eases open, the swap cross-fades | closed-day banner, help hints |
| **View switch** | `AnimatedSwitcher` over `AppMotion.viewSwitchOf(context)` | Reserve hub, calendar |
| **Tab switch** | `FadeInOnChange` — a fade of the kept-alive branch stack, never a rebuild | shell |
| **Month / period change** | `AnimatedSwitcher` over `emphasized`, `enter` in, `ease` out | `calendar_screen.dart` |
| **Loading** | `LoadingView` fades its spinner in over `loadingFadeIn` | `lib/core/ui/loading_view.dart` |
| **Success confirmation** | `AppSnack.success`: the check mark animates over `standard` | `lib/core/ui/app_snack.dart` |
| **List insertion / removal** | not animated today — rows appear and leave with the rebuild | — |

## Rules for the next one

1. **Pick a row above.** A new intent that genuinely fits none is a change
   to this document first, then a token, then the code.
2. **No inline `Duration(milliseconds: …)` at a call site.** Name it here.
3. **Motion explains a change of state or place.** No bouncing, no
   decorative loops, no scale-up entrances competing with availability.
4. **Test the end state with motion off.** A widget test that only passes
   while animating has tested the animation, not the screen.

## Two token homes, and why they are not merged here

`MotionTokens` (#611) and `AppMotion` (#209) predate each other's
reasoning: `AppMotion` names *intents* for the two context-free sites that
need a constant, `MotionTokens` names *magnitudes*. Merging them moves
call sites without changing a single animation, so it is left to the
refactor that next touches both.
