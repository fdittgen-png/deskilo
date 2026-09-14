<!-- SPDX-License-Identifier: 0BSD -->
# Performance budgets: what is measured, what is not, and why

#1236. Before this, everything that measured anything in this repository
was one line of `android-boot.yml`, and its own comment says the number
was chosen to stop a flake. `grep -rniE "Stopwatch|elapsedMilliseconds|
benchmark"` over `test/`, `integration_test/` and `lib/` returned
nothing. "Feels fast on my phone" was the standard.

The table the issue proposed is a good list of *targets*. What follows is
each one against what this project can honestly measure, because a budget
nobody can measure is a number in a document, and this programme is about
replacing exactly that.

| target | status |
|---|---|
| floor-plan render at 60 fps | **held**, as a draw-call budget — `test/perf/floor_plan_painter_test.dart` |
| critical DB query < 200 ms | **held** — `supabase/tests/database/30_query_budgets.sql` |
| cold start < 2.5 s | **reported, not held** — see below |
| screen transition < 300 ms | not held — see below |
| booking interaction < 500 ms | not held — see below |
| API p95 < 500 ms | not held — needs production telemetry this project does not collect |

## The floor plan: draw calls, not milliseconds

The canvas paints every office, desk, seat, image and avatar on every
frame, so its cost must be linear in what is on the plan. A
`seatsOf(desk.id)` inside the desk loop turns that quadratic, and the
fixture every other test uses — one office, one desk, one seat — cannot
tell the difference.

A scaling *ratio* was tried first, and measured. At 200 vs 800 desks the
real painter grew **3.1×**; the same painter with a deliberate
`plan.desks.where(...)` injected inside the seat loop grew **4.6×**. Both
sit under any threshold that would survive a shared runner, because the
quadratic term is a string compare and the constant term is Skia. **A
ratio test between those two numbers would look like a guard and catch
nothing**, so it is not in the suite.

What is in the suite counts the calls the painter makes to the canvas,
via a `CountingCanvas implements Canvas` — the same shape
`flutter_test`'s own `paints` matcher uses. That count is exactly the work
asked of the GPU, it is identical on every machine, and it is asserted per
element: four times the seats must issue about four times the calls, never
sixteen.

Proven to bite: injecting a per-seat loop over every seat takes
`drawRect` from 160 020 to 2 560 080, and the test names the call, both
numbers, and the usual cause.

A loose wall-clock ceiling sits beside it — 120 ms for a 100-desk floor,
about an order of magnitude above what it costs — to catch something
becoming slow *without* the call count changing: a shader compiled in the
loop, an image decoded per seat.

## The database: the index, then the clock

`30_query_budgets.sql` asserts, in this order:

1. **the indexes exist** — deterministic, and the thing that actually
   decides whether a query is fast. A table added without one fails here
   rather than on somebody's phone eighteen months later.
2. **the planner uses them at realistic scale** — 5 000 reservations in
   one workspace, `ANALYZE`d, then `EXPLAIN`. Postgres will seq scan a
   fixture-sized table and be right to, so a plan assertion means nothing
   until the planner has a choice.
3. **one clock**: `member_statement` over twelve months of ledger. It
   measures **73 ms** on the dev project; the budget is 400. Its job is to
   catch a 5× regression on a shared runner, not to measure the runner.

## Cold start: reported, not held at 2.5 s

`android-boot.yml` measures `am start -W` `TotalTime` and fails over
12 000 ms. The baseline reading is 7 528 ms, and run #99 flaked at 8 002
against a then-8 000 budget — two milliseconds of scheduler jitter.

**That 7.5 s is an emulator on a shared runner, not a phone.** Tightening
it to the issue's 2.5 s would fail every run; keeping 2.5 s as a written
target while gating at 12 000 would be a fiction. So the number is
reported each run and the gate stays where it is, catching the
order-of-magnitude regression it was built for — a startup deadlock —
which is what it honestly can catch.

Holding 2.5 s needs a real device. That is a physical-lab question, not a
CI one, and pretending otherwise is how the 12 000 got written in the
first place.

## Screen transition and booking interaction

Both are user-perceived times, and both are dominated by something the
test harness does not have: a compositor with a real frame schedule, and a
network.

- A **transition** can be proxied by a rebuild count, which is
  deterministic and worth having. It is not written yet.
- A **booking** is one RPC. The honest number for it is the retry budget
  of #1241 — three attempts over about 1.5 s before the member is told
  they are offline — and that *is* asserted, in
  `test/core/data/retry_test.dart`.

Neither is claimed in the table above.

## API p95

Needs request timing collected in production. This project collects none:
there is no analytics, by design (`PRIVACY.md`), and the trace log is
local to the device and redacted (#1240). Measuring a p95 would mean
adding telemetry, which is a privacy decision and not a performance one.
It is listed here so the absence is a decision rather than an oversight.
