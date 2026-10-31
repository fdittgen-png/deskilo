# Verification receipt — 2026-10-31

Application candidate: dce8100fa20290d30d6ed70ecd5da9734429d022, PR3178.
Local commands ran on the final source tree before the commit; committing changed no source.
The SQL-only ACL correction followed analysis/Deno; it invalidated affected migration metadata tests, which were regenerated and rerun.

| Command / observation | Original result |
|---|---|
| deno test --allow-env supabase/functions/send-push | exit 0; 28 passed |
| env PATH=/Users/floriandittgen/development/flutter/bin:/opt/homebrew/bin:/usr/bin:/bin dart analyze --fatal-infos | exit 0; no issues |
| ~/.deskilo-exchange/tools/guarded-flutter-test.sh --no-pub test/lint test/core/help --reporter expanded | initial exit 1, 700 pass / one missing-revokes failure; final complete run exit 0, 701 pass |
| python3 scripts/worktree_prepare.py --database-ci | sandbox attempt exit 2, nested flutter exit 1; approved outside-sandbox retry exit 0, READY, DB PENDING_CI_EVIDENCE |
| dart run tool/preflight.dart --base origin/master --list | exit 0; selected help, APPLIED, instance, l10n audit, capability evidence |
| dart run tool/contract_predict.dart apply supabase/migrations/0631_push_trigger_authentication.sql /private/tmp/3092-contract-result.json | exit 0; five complete routine entries spliced |
| dart run tool/record_applied_migrations.dart --through 0631 | exit 0; APPLIED through 631 |
| dart run tool/build_instance.dart | exit 0; bundle through 631 |
| dart run tool/l10n_audit.dart | exit 0; no retained diff |
| dart run tool/capability_evidence.dart | exit 0; no retained diff |
| git diff --check | exit 0 |
| exact committed 0631 applied to dev through migration connector | success=true; no shell exit code |
| rolled-back new 321 pgTAP probe on applied dev | PUSH_PROBE total=13 failed=0 details=none; intentional RAISE means connector isError=true, not exit 0 |
| rolled-back existing 120 reminder-evidence probe on applied dev | PUSH_PROBE total=20 failed=0 details=none; intentional RAISE means connector isError=true, not exit 0 |
| dev metadata observation | schema_version 631, push_secret_present false, anon_helper false, member_helper false |

Final lint log retained on Mac at /private/tmp/3092-final-lint-help.log; private raw logs were not exported.
Guide/wiki/help/site generation occurred sequentially; original exit records for that earlier invocation UNKNOWN in this snapshot. Final lint drift checks passed; required CI owns clean replay and complete evidence.

## Earlier merged candidates

PR3175 reviewed head 7d402e3db18b28c2d03b4078c6d2266ae4b3ab00:
- Full analysis exit 0; final guarded lint/recorder 679 pass exit 0; setup import contract 13 pass exit 0; Deno badge guard 3 pass exit 0.
- Exact historical guard command arguments for those older runs: UNKNOWN in the preserved PR receipt; do not invent them. Folder coverage and counts are recorded in the PR Tests section.
- Dev pgTAP 320=30, 104=53, 13=15, 311=10 passing assertions; probes deliberately rolled back, connector errors not shell exits.
- Clean replay and all required checks: https://github.com/fdittgen-png/deskilo/actions/runs/41242506464 .
- Initial failed run 41239861573 is superseded; it supplied existing-table constraint digests once. Four whole routines prediction returned exit 2 because constraints could not be predicted; complete 0630 mapper prediction exit 0. Final required CI supersedes prediction assumptions.
- Review: ../reviews/3175.md .

PR3177 reviewed head 428daf2576ecc816ce3d127201bd2f6085960c0c:
- Guarded lint/help 723 pass exit 0; exact historical command flags UNKNOWN in the preserved PR receipt.
- https://github.com/fdittgen-png/deskilo/actions/runs/41242625613 .
- Review: ../reviews/3177.md .

## CI currently pending for PR3178

https://github.com/fdittgen-png/deskilo/actions/runs/41246398626
No final artifacts or clean replay result exists at this snapshot; numeric artifact IDs UNKNOWN.
Required contexts are analyze · l10n gate · test · coverage, quality · database, quality · report.
A later source change requires fresh affected verification and a new SHA-bound review.
No production deployment or real FCM device delivery result is claimed.

Update 2026-10-31T22:09:59Z: Edge run 41246398606 completed SUCCESS at dce8100fa20290d30d6ed70ecd5da9734429d022. Typecheck every function and Test every function that has tests both passed; Are the deploy secrets there and Deploy were SKIPPED on this pull request. Quality41246398626 remains running. e1 APPROVED that exact source head; reviews/3178.md is exported. No later source change has occurred.

