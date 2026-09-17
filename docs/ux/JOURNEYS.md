# Journeys — what a person came to do, and what it costs

*#1247, absorbing #1300's journey map.* A member's path should be five
steps and an administrator's a list of decisions. This table is what the
app costs today, measured in `test/ux/tap_budget_test.dart`. Every budget
there asserts the journey **arrived**, since a tap count over a path that
does not finish measures nothing. A budget may only go down; raising one
needs a sentence in the pull request saying what the person got in
exchange.

Taps are deliberate touches. Scrolling and typing are not counted: they
are costs, but not decisions. A redesign should not "win" by replacing
three taps with one long scroll.

| journey | entry | primary decision | primary CTA | secondary actions | exit state | taps |
|---|---|---|---|---|---|---|
| app open → booking confirmed | Reserve hub (launch) | which seat, for the default window | **Reserve** on the booking sheet | change window, repeat, book for someone | reservation made | **2** |
| app open → pending decision resolved | alerts face via the bell | accept or decline | **Accept** on the pinned request | decline, open the request | request confirmed | **1** |
| … with the events bell off (association) | launch | accept or decline | Calendar badge → **Accept** | — | request confirmed | **2** |
| app open → invoice explained | launch | which invoice | the invoice row | pay, download, share | lines and total on screen | **3** |
| app open → a workspace setting changed | launch | which setting | Settings → Availability → the day | hours, granularity, closures | opening days saved | **3** |
| onboarding → usable workspace | onboarding | the space's name | **Create workspace** | country, currency, template, dev/prod pair | shell with a bookable room | **1** (+ the name) |

## What the numbers do not show yet

The decision budget measures the path **once you know where to look**.
ADR 0023 (proposed) is the administrator's real cost: finding out that
something needs deciding. When the decision surface exists, that budget
is re-measured from launch *without* the bell's hint and ratcheted from
there.

## How to add a journey

1. Add a `testWidgets` to `tap_budget_test.dart` that boots the app, counts
   with `Taps`, and asserts the exit state.
2. Add the row above with its measured number.
3. Keep the budget at what it costs today; lower it in the PR that makes
   the path shorter.
