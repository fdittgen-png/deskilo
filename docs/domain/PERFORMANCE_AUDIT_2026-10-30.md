# Performance audit — 2026-10-30 (#2961)

| | |
|---|---|
| Commit | `cccb39623` (origin/master during the audit) |
| Server | dev project `zwzbynivewivvjmripeb`, PostgreSQL 17.6 (aarch64); `pg_stat_statements` accumulated since 2026-07-07 (stats reset). That is the dev workload: owner, testers and agents, mostly demo data. Volumes are small: the largest table is `events` with 785 rows. |
| Server method | read-only catalog/statistics queries; `EXPLAIN (ANALYZE, BUFFERS)` of a SELECT only, impersonating an active owner inside `begin … rollback` |
| Client method | static reading of the boot, realtime, cache, events, reservations and plan paths at the commit above; the key citations are in the summary table (paths under `lib/`), and the full evidence is in each issue. No device trace. |
| CI method | GitHub Actions job timings of the last 10 successful `quality.yml` runs on master |
| Not run | real-device startup, frame timings, memory and energy (no lab device in this audit); production telemetry (none is collected); load tests (not authorized) |

## Summary

The largest cost found is not a slow query or a slow frame. It is **work repeated without a reason**:
- every focus change on web re-reads every table the app maps (PERF-1);
- every event row reloads the inbox in three serial round trips on every client, including on a change in another workspace (PERF-2);
- every booking re-reads place names that cannot have changed (PERF-3);
- deletes and presence heartbeats fan out across tenants and subscribers (PERF-4/5).

The dev statistics agree with the code reading: the most-called statements are exactly those refetches.

The one server hot spot is the RLS helper `event_types_in_view()`. It costs **104 ms of a 135 ms** 100-row events page (EXPLAIN below), and that page is the most frequent heavy statement.

| ID | User impact | Evidence confidence | Finding | Issue |
|---|---|---|---|---|
| PERF-1 | High (web: every alt-tab) | High, code + statistics | resume resync on `inactive → resumed`, ×2 targets, busts the plan cache; heartbeat on every resume (`core/realtime/realtime_providers.dart:55-63,112-115,154-179`; `app/shell/shell_effects.dart:118-119`; `core/presence/presence_heartbeat.dart:63-70`) | #3098 |
| PERF-2 | High (inbox, badge) | High, code + EXPLAIN + statistics | sweep + 100 events + decisions per signal; unfiltered decisions binding; `event_types_in_view()` 104 ms (`features/events/providers/realtime_invalidations.dart:10`; `features/events/data/supabase_event_repository.dart:56`; `core/realtime/realtime_sync.dart:44,92-93`) | #3099 |
| PERF-3 | Medium (every booking) | High for the mapping, medium for the sweep share (statement text not attributable) | `sweep_day_end` before every window read; `targetNames` refetched per booking and stale on rename; serial place reads (`features/reservations/data/supabase_reservation_repository.dart:66,77`; `features/plan/providers/realtime_invalidations.dart:13-15,37`; `features/plan/data/place_index.dart:37`) | #3100 |
| PERF-4/5 | Medium, grows with tenants and online users | Code; scaling argued, not measured | unfiltered DELETE bindings on 18 tables; `touch_last_seen` on the published `profiles` (`core/realtime/realtime_sync.dart:91,93,98-102`; `core/presence/presence_rules.dart:12`) | #3101 |
| PERF-6..9 | Medium (boot, long sessions) | Code | serial warm-up, wasted warm read, 194 KB UI-isolate JSON parse, cache key churn, double fetch after own mutation, 16.5 MB `bundle.json` shipped (`app/boot.dart:65-86`; `main.dart:42`; `features/reservations/providers/reservation_providers.dart:104-113`; `core/cache/cache_store.dart:86-87,237`) | #3102 |
| PERF-10 | Medium on failure paths | Code | hot providers on Riverpod's default 10× retry; fatal events sweep (`features/events/providers/event_providers.dart:30-109`; `main.dart:115-138`) | #3103 |

Every finding is bounded by its issue, which states a counter test (calls counted on the demo fakes) that fails before the change and passes after it. That is the regression control the issue asks for.

## Server measurements (dev)

**Top statements by total time, API roles only.**

| statement (shape) | calls | mean | max |
|---|---|---|---|
| `events` by workspace, ordered by `created_at` (one variant) | 3,340 | 723 ms | 6,159 ms |
| `events` by workspace, ordered by `created_at` (another select list) | 3,841 | 369 ms | 2,250 ms |
| `SELECT name FROM pg_timezone_names` | 3,541 | 618 ms | 4,579 ms |
| `event_decisions` where `event_id = ANY($1)` | 4,441 | 206 ms | 3,897 ms |
| PostgREST schema-cache type introspection | 3,542 | 146 ms | 2,722 ms |
| RPC taking `p_workspace_id` only (most called) | 20,499 | 17 ms | 1,579 ms |
| `mcp_pre_request()` (pre-request hook, every API call) | 226,701 | 1.2 ms | 815 ms |
| `touch_last_seen()` | 21,863 | 12 ms | 1,018 ms |

- **Timezone and introspection rows.** `pg_timezone_names` and the type introspection come from PostgREST's schema-cache load. They are called the same number of times (3,541 / 3,542), once per `notify pgrst, 'reload schema'`, and dev reloads on every migration apply. They are dev noise, not a user path. A production project pays them only on a deploy.
- **Events-page plan.** `limit 100`, as the owner of the busiest workspace:
  ```
  Limit (actual 104.3..134.8 ms, rows=100)
    Index Scan using events_workspace_created_idx (rows=100)
      Filter: NOT mcp_is_delegated() AND (hashed SubPlan 1 OR EXISTS(SubPlan 3) OR may_validate_event_type(...))
      SubPlan 1 -> Function Scan on event_types_in_view (actual 104.0 ms, rows=108, shared hit=1677)
  Execution Time: 134.9 ms
  ```
  The index is used. The time is the RLS helper, paid once per statement, and every reload in PERF-2 pays it again.
- **Indexes.** 199 foreign keys have no index leading with their column. No statement in the statistics shows a sequential-scan problem at dev volume (`seq_tup_read` > 100 × `idx_scan` on no table above 500 rows). Following the issue's rule (no speculative index), **no index is recommended** until a measured plan shows a need. The existing `30_query_budgets.sql` stays the gate, and #3099 adds an events-page budget to it.
- **Unused indexes.** The largest is `mcp_usage_pkey` at 432 kB. Dev usage doesn't represent production, so none is dropped.

## Existing gates (current state)

| gate | kind | state |
|---|---|---|
| `test/perf/floor_plan_painter_test.dart` | draw calls (held) + a loose 120 ms wall-clock ceiling | held. The ceiling failed once on #3083 at 129 ms on a shared runner, then passed on rerun; that is the expected noise of a wall clock on CI, and the draw-call count is the real guard |
| `supabase/tests/database/30_query_budgets.sql` | planner at 5,000 rows | held in CI's database job |
| `android-boot.yml` | emulator ceiling 12 s | a deadlock alarm, not a device startup figure |
| `tool/bench/` journeys | shape: frames, elements, round trips | held. It counts the work of a journey, not the refetch storms above, because they come from realtime and lifecycle signals the bench does not emit. #3098–#3101 add the signal-driven counters |

## CI (quality.yml on master, last 10 successful runs)

- **End to end:** 25 to 50 minutes (median about 30: 24 25 26 27 27 32 33 38 47 50).
- **Slowest jobs (latest run):** `quality · test · money and workspace` 24 min, `quality · test · gates` 22 min, `quality · database` 21 min, `quality · test · other features` 20 min. They run in parallel, so the critical path is about 24 min plus queue and setup.
- No correctness or security job should leave the PR gate to make this faster. The suite-cost work belongs to #2599 (one screen harness, files cost what they prove), which is already in the implementer's queue.

## Not run (with the recipe)

| area | status | recipe |
|---|---|---|
| cold start and first usable hub on a device | **NOT RUN**: no physical device in this audit | `flutter run --profile --trace-startup` on a named low/mid Android device (e.g. a 4 GB Android 12 phone), 10 cold starts after `adb shell am force-stop`; report median and p90 of `timeToFirstFrameMicros`, plus the time to the hub's first plan frame from `--trace-startup` |
| frame timings on the plan | **NOT RUN** | DevTools performance overlay in profile mode on the same device, at the bench workload (20 rooms / 200 desks / 800 seats / 2,000 reservations) |
| memory over repeated journeys | **NOT RUN** | DevTools memory: 20 × open/close plan and switch workspace; heap after a forced GC should be flat |
| app size per platform | **NOT RUN** (no release build in this audit) | `flutter build apk --analyze-size` / `flutter build web --release`, before and after #3102's bundle move |
| production latency p95 | **NOT RUN** | no telemetry by design (THREAT_MODEL T15) |
