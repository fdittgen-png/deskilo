#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Exercise actual overlapping claims and delayed lock acquisition on CI's
# disposable database. Each contender is a separate psql connection.
set -euo pipefail
url=${1:?usage: hmrc_recovery_race.sh DATABASE_URL}
ws=00000000-0000-4000-8000-000000006521
owner=00000000-0000-4000-8000-000000006522
d1=00000000-0000-4000-8000-000000006523
d2=00000000-0000-4000-8000-000000006524
d3=00000000-0000-4000-8000-000000006525
scratch=$(mktemp -d)
cleanup() {
  local original_status=$? cleanup_status=0
  psql "$url" -X -q -v ON_ERROR_STOP=1 >/dev/null 2>&1 <<SQL || cleanup_status=$?
delete from public.hmrc_submissions where workspace_id = '$ws';
delete from public.vat_declarations where workspace_id = '$ws';
delete from public.workspaces where id = '$ws';
delete from auth.users where id = '$owner';
SQL
  rm -rf "$scratch"
  if (( cleanup_status != 0 )); then
    echo "::error::HMRC race fixture cleanup failed" >&2
    exit 1
  fi
  exit "$original_status"
}
trap cleanup EXIT
psql "$url" -X -q -v ON_ERROR_STOP=1 <<SQL
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('$owner','00000000-0000-0000-0000-000000000000','authenticated','authenticated','hmrc-race@deskilo.test','',now(),now(),now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by)
values ('$ws','HMRC race','GB','GBP','Europe/London','$owner');
insert into public.vat_declarations (id, workspace_id, period_start, period_end, lines, total_net_cents, total_vat_cents)
values ('$d1','$ws','2031-01-01','2031-03-31','[]',0,0),
       ('$d2','$ws','2031-04-01','2031-06-30','[]',0,0),
       ('$d3','$ws','2031-07-01','2031-09-30','[]',0,0);
SQL
wait_marker() {
  local i=0
  while (( i < 100 )); do
    [[ -e "$1" ]] && return 0
    sleep 0.1
    ((i+=1))
  done
  echo "::error::holder did not acquire its lock" >&2; return 1
}
wait_lock() {
  local i=0 result
  while (( i < 100 )); do
    result=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 -c "select count(*) from pg_stat_activity where application_name = '$1' and wait_event_type = 'Lock'")
    [[ "$result" != 0 ]] && return 0
    sleep 0.1
    ((i+=1))
  done
  echo "::error::contender did not wait on a lock: $1" >&2; return 1
}
# A holds a newly inserted first claim. B must wait, then see an active lease.
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/first-holder" 2>&1 <<SQL &
begin;
select public.claim_hmrc_submission_v2('$d1','holder-001',10,repeat('a',64),null)->>'claimed';
\! touch '$scratch/first-ready'
select pg_sleep(6);
commit;
SQL
a=$!
wait_marker "$scratch/first-ready"
PGAPPNAME=hmrc-race-first psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/first-contender" 2>&1 <<SQL &
select public.claim_hmrc_submission_v2('$d1','holder-002',10,repeat('a',64),null)->>'state';
SQL
b=$!
wait_lock hmrc-race-first
wait "$a"; wait "$b"
grep -qx true "$scratch/first-holder"
grep -qx in_flight "$scratch/first-contender"
# A locks an existing active claim. B waits past expiry and then recovers
# with the prior attempt's token; its lease begins after the wait.
psql "$url" -X -q -v ON_ERROR_STOP=1 <<SQL
insert into public.hmrc_submissions(declaration_id, workspace_id, boxes_sha256, state, holder, claim_until)
values ('$d2','$ws',repeat('a',64),'in_flight','holder-001',clock_timestamp() + interval '3 seconds');
SQL
marker=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 -c "select encode(sha256(convert_to('hmrc-recovery-v1|' || declaration_id::text || '|' || holder || '|' || recovery_marker::text,'UTF8')),'hex') from public.hmrc_submissions where declaration_id='$d2'")
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/locked-holder" 2>&1 <<SQL &
begin;
select declaration_id from public.hmrc_submissions where declaration_id='$d2' for update;
\! touch '$scratch/locked-ready'
select pg_sleep(6);
commit;
SQL
a=$!
wait_marker "$scratch/locked-ready"
PGAPPNAME=hmrc-race-locked psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/locked-contender" 2>&1 <<SQL &
select public.claim_hmrc_submission_v2('$d2','holder-002',10,repeat('a',64),'$marker')->>'claimed';
select (claim_until > clock_timestamp() + interval '7 seconds')::text from public.hmrc_submissions where declaration_id='$d2';
SQL
b=$!
wait_lock hmrc-race-locked
wait "$a"; wait "$b"
[[ $(grep -c '^true$' "$scratch/locked-contender") == 2 ]]
psql "$url" -X -q -v ON_ERROR_STOP=1 <<SQL
select public.release_hmrc_submission('$d2','holder-001',false);
do \$check\$
begin
  if not exists (select 1 from public.hmrc_submissions where declaration_id='$d2' and holder='holder-002') then
    raise exception 'old holder removed the new claim';
  end if;
  begin
    perform public.record_hmrc_acceptance('$d2','holder-001','receipt','','');
    raise exception 'old holder recorded a receipt';
  exception when sqlstate '55P03' then null; end;
end \$check\$;
update public.hmrc_submissions set claim_until=clock_timestamp() where declaration_id='$d2';
do \$check\$
begin
  if public.claim_hmrc_submission_v2('$d2','holder-003',10,repeat('a',64),'$marker')->>'state' is distinct from 'unconfirmed' then
    raise exception 'old confirmation authorized a later attempt';
  end if;
end \$check\$;
SQL
# A inserts then rolls back. B's INSERT waits, wins, and gets a fresh lease.
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/rollback-holder" 2>&1 <<SQL &
begin;
select public.claim_hmrc_submission_v2('$d3','holder-001',10,repeat('a',64),null)->>'claimed';
\! touch '$scratch/rollback-ready'
select pg_sleep(6);
rollback;
SQL
a=$!
wait_marker "$scratch/rollback-ready"
PGAPPNAME=hmrc-race-rollback psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/rollback-contender" 2>&1 <<SQL &
select public.claim_hmrc_submission_v2('$d3','holder-002',10,repeat('a',64),null)->>'claimed';
select (claim_until > clock_timestamp() + interval '7 seconds')::text from public.hmrc_submissions where declaration_id='$d3';
SQL
b=$!
wait_lock hmrc-race-rollback
wait "$a"; wait "$b"
[[ $(grep -c '^true$' "$scratch/rollback-contender") == 2 ]]
echo 'HMRC claim races: first claimant, delayed recovery and rollback winner passed'
