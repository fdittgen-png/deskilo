# #3179 Quality attempt2: required database gate failed

Source: 3ebe7be220b14d6cc58d6b8a2163df206be5ef12.
Run: https://github.com/fdittgen-png/deskilo/actions/runs/41248620765/attempts/2
Database job: https://github.com/fdittgen-png/deskilo/actions/runs/41248620765/job/124686000380

Outgoing Codex downloaded this completed job's own log through the GitHub API.
The CLI whole-run log command initially returned exit1 because the report
job was still live; that observation failure was not a new test result.
Job-specific log download returned exit0.

Database disciplines ran 319 pgTAP files / 6063 tests and reported FAIL,
480 seconds wall time, container/original command exit1. Nine assertions
failed in four files:

| File | Failed assertions | Actual vs expected |
|---|---|---|
| 17_entitlement_specification.sql | 2 | October2026 half-days: 0 vs22. |
| 53_association_template.sql | 5–7 | First month 0 vs22 (50%) /44 (100%); charges {0,0} vs{5000,10000}. Later tested months retain expected values. |
| 54_pezenas_template.sql | 4,10–11 | Same first-month entitlement and charge pattern; first month0 instead of22/44. |
| 76_mcp_financial_requests.sql | 5,8 | Confirmed invoice request status conflict vs completed; invoice count0 vs1. |

The later MCP evidence check explicitly refuses the failed
76_mcp_financial_requests.sql result (2/8 failures), original command exit1.
The database Gate fails because Database disciplines and MCP evidence did
not succeed. This is propagation, not proof of a second unrelated MCP bug.
Physical-topology rows in the same log report SUCCESS. All four Flutter
test shards and the analysis/l10n/test/coverage aggregate report SUCCESS.
The final quality report was still live at the first failure observation;
no whole-run success is claimed.

## Agreed ownership and correction

At23:34Z e1 independently diagnosed the Paris month rollover and assigned
the test-only correction to incoming a2(claude-night), TOP PRIORITY before
#2488. Current-time fixture starts/periods conflict with fixed October2026
expectations; 76 uses to_char(now(),'YYYY-MM') for its period. e1 requires
consistent fixed fixture dates/periods (or consistently derived expectations),
four rolled-back dev probes and a reviewed test-only PR, no migration.
#3179/#3181 remain blocked pending the repair and fresh required verification.
No third unchanged-source retry was launched by outgoing Codex.

Separately, e1 acknowledged the F-Droid50m timeout at23:32Z. It is not a
required merge context; e1 deferred its CI follow-up unless it repeats on
master, with no action tonight. The earlier split-job proposal is therefore
not an active assignment. The cancelled APK audit remains missing evidence,
not a pass. Claude retains source, CI corrections, migrations and cleanup.
