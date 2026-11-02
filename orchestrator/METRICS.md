# Orchestration efficiency measurements

Baseline token window: **2026-11-02 08:32:00 to 09:39:00 UTC**, 67 minutes, four existing sessions. CI metadata sampled around 09:41 UTC. [Machine-readable snapshot](metrics/2026-11-02T093900Z.json).

This is an observed baseline, not a controlled before/after experiment. Work complexity, session startup, cache warm-up and unfinished checkpoints differ. No percentage improvement in delivery efficiency or monetary savings is established yet.

## Time and delivery

| Indicator | Observation |
| --- | --- |
| Completed checkpoint | #2519 reasons/enforcement through #3250; one merged PR in this window |
| #3250 PR creation to merge | 09:02:39 to 09:19:50, **17m 11s** |
| #3250 Quality run | Attempt 1 SUCCESS, **16m 32s** from start to final metadata update |
| #3250 completed job wall sum | **92m 55s** across parallel jobs; not CPU usage or billed runner time |
| #3250 longest job / test shard | Database 14m 46s; longest test shard 14m 45s |
| #3251 proof Quality run | Attempt 1, **16m 15s**, overall failure on known pending contract; database correctness/races passed |
| #3251 proof completed job wall sum | **92m 45s** |
| #3251 Quality executions | Two source-head runs: proof and final combined follow-up; final run still incomplete at sampling |
| Final candidate turnaround | Proof run completed 09:23:36; combined follow-up committed 09:26:05 and run started 09:26:15; **2m 29s** to commit |
| Open PR load at late sample | One open PR (#3251); #3070 local work, no PR |
| Rebase/conflict count | No conflict reported in inspected receipts; independently instrumented count UNKNOWN |
| Review waiting / lock waiting | Not yet measured reliably; timestamps required at next handoff |

GitHub workflow duration uses run_started_at → final updated_at because workflow metadata has no separate completion field in this sample. Job durations use started_at → completed_at. Pending jobs/runs are not treated as completed durations. The two completed Quality runs were under 20 minutes, but that does not establish improvement against comparable earlier work.

## Recorded token use

Values come from local `token_usage_record` entries, filtered by UTC window and deduplicated by response_id. They sum per-response usage fields, not cumulative thread counters. Repeated cached context is included in recorded input.

| Role | Responses | Uncached input | Cached input | Output |
| --- | ---: | ---: | ---: | ---: |
| orchestrator | 127 | 396,677 | 16,839,936 | 56,414 |
| reviewer | 138 | 336,825 | 18,366,080 | 44,676 |
| engineer1 | 363 | 1,125,557 | 90,568,064 | 83,264 |
| engineer2 | 381 | 353,029 | 67,471,616 | 79,968 |
| **Total** | **1,009** | **2,212,088** | **193,245,696** | **264,322** |

Total recorded input: **195,457,784**, of which **98.87% cached**. Recorded output: **264,322**. These are usage counters, not unique source words or billed cost. Reasoning counters are retained separately in the raw snapshot and are not added again to output. No provider pricing or invoice reconciliation has been performed. Do not attribute each session's total to a single issue: the orchestrator/reviewer span tasks and E2 started #3070.

## Observed evolution within the window

| Indicator | 08:32–09:00, 28 min | 09:00–09:39, 39 min |
| --- | ---: | ---: |
| Responses per minute | 17.54 | 13.28 |
| Uncached input per minute | 40,963 | 27,311 |
| Output tokens per minute | 5,118 | 3,103 |
| Average input context per response, including cache | 129,662 | 254,428 |
| Recorded input per minute, including cache | 2.27M | 3.38M |

Later windows show fewer responses and less uncached input/output per minute, while context per response nearly doubles and cached-input processing rises. Cache warm-up and task mix can explain part of this. **Net time/token efficiency improvement is not proven.** Context growth and stale coordination messages are measurable concerns, not reasons to claim an arbitrary percentage saving.

## Quality and rework

- #3250 passed its first Quality run and reached the zero-unjustified-default ratchet without runtime changes.
- One material HMRC UI defect was reproduced after the proof push and fixed before approval: failed refresh could resurrect a stale acknowledgement. Final corrected-head CI remains necessary.
- HMRC proof includes 6,449 pgTAP assertions and real first/delayed/rollback races. Assertion counts alone do not establish complete correctness.
- One documented product-scope reversal caused uncommitted runtime edits to be reconciled: six proposed OFF changes were based on incorrect creation semantics. R3 and source tracing prevented that change from shipping.
- One overbroad localization lock was removed after exact source comparison proved no overlap. Saved time is not yet measured.
- Post-merge escaped-defect rate and comparable completed-feature throughput: **UNKNOWN** at this baseline.

## How to measure the next snapshot

At a normal handoff, failure or merge, capture the same four role IDs and nonoverlapping time interval. If roles/sessions change, record the boundary. Sum only new unique response records; do not add cumulative counters or double-count overlapping windows. Keep model/effort/runner/cache conditions where available; missing values stay UNKNOWN.

Track claim→first commit→PR→approval→merge timestamps, active blocked intervals with reason/owner, actual head/run/attempt counts, intentional proof runs versus defect-driven reruns, overwritten decisions, conflicts, authored files, review findings and escaped defects. Compare equivalent task classes, not a documentation PR with a financial concurrency feature. CI aggregates should distinguish elapsed critical path from parallel job wall sum.

Use targeted metadata and current summaries. Do not repeatedly read full session histories, run full tests or create CI executions solely to measure them. No recurring job/watcher is created. The next report should say what improved, regressed or remains unmeasured and name one concrete orchestration correction.

## Post-baseline completion update — 09:53 UTC

The fixed 67-minute baseline above is unchanged. After its cutoff, #3251 merged at 09:42:40 UTC: PR creation to merge **35m 23s**. Final Quality run 41420626290 attempt 1 succeeded, start 09:26:15 → final update 09:42:28, **16m 13s**, ten jobs successful. Both measured checkpoints are now merged, but only #3250 merged inside the token window. Do not divide both completions by that window or imply all issue acceptance is done.

Merge was reconciled in orchestration around 09:48 UTC, approximately six minutes after the actual merge; this is an observed coordination lag, not proof the engineer was idle for the entire interval. Reviewer then released the lane, reserved 0653 and applied reviewed #3070 bytes at 09:51:38. Improvement: check and publish actual merge at dependency handoff, release only overlapping locks promptly, and distinguish queued notification from current ownership. No extra monitoring job is introduced.
