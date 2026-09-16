#!/usr/bin/env bash
# SPDX-License-Identifier: 0BSD
#
# #1310 S1 — the restore nobody had ever run.
#
# OPERATIONS.md has documented the dump and the `psql -v ON_ERROR_STOP=1`
# restore since the day it was written, and nothing ever executed it. A
# backup procedure that has never been restored is a hope, not a recovery
# plan.
#
# Seed → dump → restore into a fresh database → prove the copy:
#
#   * every seeded table has the same number of rows;
#   * `reconcile_workspace` is clean for BOTH workspaces in the copy —
#     invoice, ledger and match still agree after the round trip;
#   * the two workspaces are still two, and each still owns its own
#     rows (a restore that merged tenants passes a row count and fails
#     this).
#
# And then, because a check that has only ever passed is indistinguishable
# from a check that does not look (#1338): the copy is deliberately
# damaged — one row deleted, one match broken — and BOTH have to be
# caught. The drill fails if its own failure cannot be provoked.
#
# Why everything runs through `docker exec` into the stack's own
# postgres container: the runner's client is older than the stack's
# server, and pg_dump refuses a server newer than itself. Dumping from
# inside the container makes the version question disappear, and lets
# the dump carry `auth` as well as `public` — a public-only dump cannot
# restore, because members reference auth.users.
set -uo pipefail

COPY_DB="deskilo_restore_check"
DUMP="$(mktemp -t deskilo-restore-XXXXXX)"

fail() { echo "::error::restore drill: $*"; exit 1; }

C="$(docker ps --format '{{.Names}}' | grep -E '^supabase_db' | head -1)"
[ -n "$C" ] || fail "the local stack's database container is not running"

src() { docker exec -i "$C" psql -U postgres -d postgres "$@"; }
copy() { docker exec -i "$C" psql -U postgres -d "$COPY_DB" "$@"; }

echo "--- seeding the fixture"
src -v ON_ERROR_STOP=1 -q < supabase/restore/seed.sql \
  || fail "the seed did not apply"

TABLES="workspaces members levels offices desks seats reservations invoices ledger_entries invoice_matches"
counts() {
  local q="select ''"
  for t in $TABLES; do
    q="$q || ' $t=' || (select count(*) from public.$t)"
  done
  "$1" -At -v ON_ERROR_STOP=1 -c "$q"
}

# No rows means the three legs agree. `reconcile_workspace` refuses
# anyone who may not see the finances, so each workspace is reconciled as
# its own owner, the way 22_reconciliation.sql does it.
reconcile() {
  copy -v ON_ERROR_STOP=1 -q -c "
do \$check\$
declare w record; v_detail text;
begin
  for w in select id, name, created_by from public.workspaces loop
    perform set_config('request.jwt.claims',
      json_build_object('sub', w.created_by::text, 'role', 'authenticated')::text, true);
    select string_agg(r.\"check\" || ' ' || r.detail, '; ')
      into v_detail from public.reconcile_workspace(w.id) r;
    if v_detail is not null then
      raise exception '% does not reconcile: %', w.name, v_detail;
    end if;
  end loop;
end
\$check\$;"
}

BEFORE="$(counts src)" || fail "could not count the source"
echo "source:$BEFORE"

echo "--- dump"
docker exec "$C" pg_dump -U postgres -d postgres \
  --schema public --schema auth --no-owner --no-privileges > "$DUMP" \
  || fail "the dump failed"
[ -s "$DUMP" ] || fail "the dump is empty"

echo "--- restore into a fresh database"
src -q -c "drop database if exists $COPY_DB" -c "create database $COPY_DB" \
  || fail "could not create the copy"

# Whatever the source has installed, and where — asked rather than
# guessed, so a new extension never silently breaks the drill.
#
# The output is READ. It used to go to /dev/null as a best-effort step,
# and when one of these failed the only symptom was a pgTAP function
# that would not resolve, four steps later, with the cause nowhere in
# the log. A step that cannot report its own failure is the defect this
# whole drill exists to rule out.
replicate() {
  local out
  out="$(src -At -c "$1" | copy -At -v ON_ERROR_STOP=1 2>&1)" \
    || fail "$2 failed on the copy: $out"
}
replicate "select distinct 'create schema if not exists ' || quote_ident(n.nspname) || ';'
             from pg_extension e join pg_namespace n on n.oid = e.extnamespace
            where e.extname <> 'plpgsql'" "creating the extension schemas"
replicate "select 'create extension if not exists ' || quote_ident(e.extname)
               || ' with schema ' || quote_ident(n.nspname) || ';'
             from pg_extension e join pg_namespace n on n.oid = e.extnamespace
            where e.extname <> 'plpgsql'" "installing the extensions"

# A brand-new database already has a `public` schema, and pg_dump emits
# `CREATE SCHEMA public;` for it — which stops the restore on its very
# first statement under ON_ERROR_STOP. Dropping `public` in the copy
# instead would be worse: an extension that lives there has to be created
# before the restore, and re-dropping the schema would take it along. So
# the one statement is filtered, and everything else stays strict.
grep -vx 'CREATE SCHEMA public;' "$DUMP" > "$DUMP.load" \
  || fail "could not prepare the dump for loading"

copy -v ON_ERROR_STOP=1 -q < "$DUMP.load" || fail "the restore failed"

AFTER="$(counts copy)" || fail "could not count the copy"
echo "copy:  $AFTER"
[ "$BEFORE" = "$AFTER" ] || fail "row counts differ — source [$BEFORE] copy [$AFTER]"

echo "--- the copy still reconciles, per workspace"
reconcile || fail "the copy does not reconcile"

TENANTS="$(copy -At -c "select count(*) from public.workspaces where name like 'Restore %'")"
[ "$TENANTS" = "2" ] || fail "expected the two seeded workspaces in the copy, found $TENANTS"
CROSSED="$(copy -At -c "
  select count(*) from public.reservations r
    join public.members m on m.id = r.member_id
   where m.workspace_id <> r.workspace_id")"
[ "$CROSSED" = "0" ] || fail "$CROSSED reservations belong to another tenant's member"

# ------------------------------------------------------------ #1310 S1
# The suites, re-executed against the COPY.
#
# Equal counts and a clean reconciliation say the rows arrived. They say
# nothing about whether the restored database still ENFORCES what the
# original enforced — a restore that lost the policies would pass every
# check above and hand an operator a database where one workspace can
# read another. So the tenancy and money suites run again, here, against
# the copy. They roll back, so they leave it as they found it, and they
# run before the damage below.
#
# pgTAP reports a failure as `not ok` in its output, not as a non-zero
# exit status, so the output is what gets read. `plan()` and friends are
# called unqualified, which is why search_path is set first — outside
# the transaction each file opens.
echo "--- the suites still hold on the copy"
# pgTAP has to be in the copy for any of this to mean anything, and a
# missing extension should say so in one line rather than surface as an
# unresolvable `is()` several files later.
HAS_PGTAP="$(copy -At -c \
  "select count(*) from pg_extension where extname = 'pgtap'" 2>&1)"
[ "$HAS_PGTAP" = "1" ] \
  || fail "pgtap is not installed in the copy (got '$HAS_PGTAP'), so the suites cannot run there"

for f in 10_tenancy_isolation 11_tenancy_matrix 20_money_invariants \
         21_ledger_append_only 23_domain_invariants; do
  out="$( { echo 'set search_path to public, extensions, pg_catalog;'; \
            cat "supabase/tests/database/$f.sql"; } \
          | copy -At -v ON_ERROR_STOP=1 2>&1 )" \
    || fail "$f could not run on the copy: $(echo "$out" | grep -E '^(ERROR|psql)' | head -3)"
  if echo "$out" | grep -qE '^not ok'; then
    echo "$out" | grep -E '^not ok' | head -5
    fail "$f failed on the restored copy"
  fi
  echo "  $f: $(echo "$out" | grep -cE '^ok') assertions hold on the copy"
done

# ---------------------------------------------------------------- #1338
# The drill made to fail, on the copy that is about to be dropped.
echo "--- and the drill detects damage"

copy -q -c "delete from public.reservations
             where id = (select id from public.reservations order by starts_at limit 1)" \
  >/dev/null || fail "could not delete a row for the loss check"
DAMAGED="$(counts copy)" || fail "could not count the damaged copy"
[ "$DAMAGED" != "$BEFORE" ] \
  || fail "a deliberately deleted row left the counts unchanged — the count check proves nothing"
echo "row loss detected: [$DAMAGED] differs from [$BEFORE]"

copy -q -c "update public.invoice_matches set paid_cents = paid_cents + 100" \
  >/dev/null || fail "could not break a match for the reconciliation check"
if reconcile >/dev/null 2>&1; then
  fail "a match that disagrees with its ledger credit still reconciled clean — the reconciliation check proves nothing"
fi
echo "broken match detected: reconciliation refused it"

src -q -c "drop database if exists $COPY_DB" >/dev/null 2>&1
rm -f "$DUMP" "$DUMP.load"
echo "restore drill:$AFTER, reconciled clean, suites hold, tenants intact, damage detected"
