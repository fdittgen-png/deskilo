<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
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
| floor-plan render at 60 fps | **not held.** An ALGORITHMIC draw-call budget is held — `test/perf/floor_plan_painter_test.dart`. A call count is not a frame rate |
| critical DB query < 200 ms | **held**, against a real planner at 5 000 rows — `supabase/tests/database/30_query_budgets.sql` |
| cold start < 2.5 s | **not held.** An EMULATOR ceiling of 12 000 ms is held — `android-boot.yml`. An emulator is not a device |
| screen transition < 300 ms | **not held in milliseconds.** Its SHAPE is — frames, elements and round trips, `tool/bench/` |
| booking interaction < 500 ms | **not held in milliseconds.** Its SHAPE is, and its retry component is — `tool/bench/`, `test/core/data/retry_test.dart` |
| API p95 < 500 ms | not held — needs production telemetry this project does not collect |

Four different kinds of evidence appear in that table and they are **not
interchangeable**: a draw-call count is algorithmic, a query budget is a
clock against a real planner, an emulator ceiling is a deadlock alarm,
and a journey's shape is a count of work. None of them is a millisecond
a member waited on a phone. #1456 added the fourth and rewrote the
wording of the first three, which had been drifting towards reading as
the third column of a device report.

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

## The journeys: their shape is held, their milliseconds are not (#1456)

Screen transition and booking interaction are user-perceived times, and
both are dominated by two things no harness here has: a compositor with
a real frame schedule, and a network. So the benchmark measures what is
exact — the **shape** of each journey — and reports the clock beside it
without gating on it.

### The recipe

```
flutter test tool/bench                    # take the measurements
bash scripts/perf_gate.sh report/perf.psv  # turn them into a verdict
```

Nightly and on demand as `Nightly · Journey latency benchmark`, never on
the pull-request path: a PR run is already 1 466 s p50
(`docs/ci/CI_BASELINE.md`) and these numbers are a trend, not a merge
decision. The record, `report/perf.psv`, carries its own conditions —
source SHA, build mode, host, dataset, backend, sample count — because a
latency number whose hardware and dataset are unknown cannot be compared
with anything.

### The workload

`tool/bench/workload.dart`, deterministic, three sizes. The journeys run
at the largest: **20 rooms, 200 desks, 800 seats, 2 000 reservations**.
The suite's own fixture is one office, one desk, one seat, where an N+1
read is invisible. The ledger is deliberately not re-seeded here —
twelve months of it against a real planner is `30_query_budgets.sql`.

### The three costs, kept apart

A single "booking took 480 ms" hides which half regressed, so nothing is
added up:

| cost | how it is measured | gated |
|---|---|---|
| network | backend **round trips**, counted at the repository seam | yes |
| UI | **elements** built and **frames** pumped | yes |
| UI | wall clock, p50 and slowest of nine samples | **no** — it measures the host |
| retries | `kRetryDelays` — attempts and the worst-case wait | yes |

Round trips rather than server milliseconds: this backend is in memory,
and a per-trip latency constant would be an assumption dressed as a
measurement. The count is exact on every machine, and it is the thing
that turns a 200 ms network into a two-second wait.

### The readings, 2026-09-20, large scale

| journey | trips | elements | frames | wall p50 / slowest |
|---|---|---|---|---|
| boot → usable Reserve hub | 7 | 1 737 | 17 | 376 / 1 883 ms |
| plan → month transition | 1 | 2 844 | 6 | 134 / 293 ms |
| tap → committed booking | 4 (sheet: **0**) | 1 842 | 4 + 5 | 107 / 246 ms |

Read the clock column as this laptop, headless, no compositor, nine
samples. The slowest sample of each is the first one, which also pays
the VM's warm-up; that spread is the reason the clock is reported rather
than gated.

The booking row splits where the issue asks it to: the sheet is the
member's **immediate feedback** and costs **zero** round trips, and the
four trips are what it takes to reach an **authoritative** answer — the
write itself plus the reads the hub refreshes with. The benchmark
asserts the booking row exists afterwards, because a journey whose tap
hits nothing measures nothing (#1339/#1446).

The retry component is not simulated: it is read out of `kRetryDelays`,
so the worst case a member waits before being told they are offline —
3 attempts, 700 ms of backoff — moves when that policy moves and never
otherwise.

### Why a missing measurement is a failure

`scripts/coverage_gate.sh` used to warn and return for a layer with no
measured lines, so two of three floors passed by never being measured
(#1446 R2). `perf_gate.sh` therefore fails on an absent row exactly as
loudly as on a number over budget — and on a missing condition, and on a
record that has stopped declaring what it does not measure.
`test/lint/perf_gate_test.dart` drives the real script over every one of
those, including an injected regression: an N+1 over 800 seats takes the
first journey from 7 trips to 807, which the benchmark itself proves in
`the trip count catches an N+1 the frame count cannot`.

## What is still NOT held, and needs a device

Plainly, so that nothing above is read as more than it is:

- **cold start on real hardware.** Unmeasured. `android-boot.yml`'s
  12 000 ms is an emulator ceiling for a startup deadlock; the 7 528 ms
  baseline is a shared runner. Neither is a device number, and 2.5 s
  remains a target nobody has measured against.
- **frame timing and jank.** Unmeasured. There is no compositor in
  `flutter test`; the draw-call budget is an algorithmic control and the
  frame counts above are pump counts, not 16.7 ms deadlines.
- **transition and booking milliseconds as a member feels them.**
  Unmeasured. Frames and trips are counted; milliseconds are not.
- **server time.** Unmeasured. The benchmark's backend is in memory.
- **API p95.** Unmeasured, by a privacy decision — see below.

Each of those five is declared in `report/perf.psv` itself, as an
`unheld|` row with its reason, and the gate fails if one disappears:
dropping the honest "not measured" is exactly how a 2.5 s target nobody
holds gets written down as if it were held. Closing them needs named
physical hardware and a staged backend, which is a lab question, not a
CI one.

## API p95

Needs request timing collected in production. This project collects none:
there is no analytics, by design (`PRIVACY.md`), and the trace log is
local to the device and redacted (#1240). Measuring a p95 would mean
adding telemetry, which is a privacy decision and not a performance one.
It is listed here so the absence is a decision rather than an oversight.
