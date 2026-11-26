#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #4492 row 6 -- an upgrade equals a fresh install, and a patch whose anchor
# is gone says so.
#
# An installation is built and upgraded the same way: the bundle's migration
# files, one transaction each, in order (`InstanceBuilder.installSchema`; an
# upgrade runs the files above the marker). The replay proves they run from
# empty, the lifecycle check that an upgrade runs each once, the populated
# upgrade that an archive survives. None of them compares what the two
# installations ARE afterwards. This does, on databases of its own:
#
#   fresh      the empty project, every migration.
#   upgraded   the empty project at 0226 with the archive of
#              supabase/restore/archive_seed.sql, carried to 0689 with the
#              in-flight e-invoice work of archive_seed_0689.sql, carried to
#              0747 with the goods of archive_seed_0747.sql, then every later
#              migration over those rows.
#   the stack  the job's own replay (the local-stack action), the database
#              assets/instance/contract.txt is read from.
#
# scripts/upgrade_equivalence.sql prints each as one line per fact (columns,
# constraints, indexes, policies, grants, triggers, whole function
# definitions, views, sequences, types, extensions, publications, buckets,
# jobs). fresh and upgraded must be the same text: a difference is the
# report, with the two definitions of each function that differs. fresh and
# the stack are compared for what the migrations build in `public` and
# `storage`; what only the stack has by construction (its bookkeeping schema,
# the scheduler's jobs, which a database beside the stack's own cannot hold)
# is listed, not failed.
#
# The second question: about 280 migrations rewrite a live function body by
# text (`pg_get_functiondef`, replace at an anchor, execute). Does such a
# file stop when its anchor is not there? A third database answers by
# execution. Before each such file is applied, the file is run once, rolled
# back, to learn which existing bodies it rewrites in place; then, for each
# of those, the body is replaced by one that holds no anchor at all, the file
# is run again, rolled back, and what it did is recorded:
#
#   LOUD          the file raised: the missing anchor stopped the upgrade.
#   RESTATED      the file defines the function whole; no anchor is involved.
#   SILENT        the file completed and left the anchorless body as it was:
#                 the patch did nothing and said nothing.
#   PATCHED_STUB  the file completed and wrote into the anchorless body (an
#                 append or a pattern, not an anchor).
#   CALLED        the file raised because it CALLS the function it patches;
#                 the trial says nothing about the anchor.
#
# A SILENT or PATCHED_STUB pair is settled when a LATER migration, met with the
# same anchorless body, leaves the function with the body the replay has: that
# file states the function whole, so an installation holds the replay's body
# after it whatever it held before. Tried on the replayed database, rolled back.
#
# SILENT and PATCHED_STUB that nothing settles are the findings. Those known today are listed in
# scripts/upgrade_equivalence_known.txt with what each is; a pair that is not
# in that list fails the check, and a listed pair that no longer occurs is
# reported so the list shrinks.
#
#   scripts/upgrade_equivalence_check.sh [<db url>]
#
# The address is accepted so the database preview can run this by name
# (`gh workflow run db-preview.yml --ref <branch> -f race=upgrade_equivalence_check.sh`);
# the work goes through `docker exec`, as the lifecycle and archive drills do.
# Every database it creates is dropped on exit; the empty project too when
# this run prepared it.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEMPLATE="${TEMPLATE:-deskilo_lifecycle_empty}"
FRESH=deskilo_equiv_fresh
UPGRADED=deskilo_equiv_upgraded
PROBE=deskilo_equiv_probe
BASELINE="${BASELINE:-0226}"
STAGE_AT="${STAGE_AT:-0689}"
SEED=supabase/restore/archive_seed.sql
STAGE_SEED=supabase/restore/archive_seed_0689.sql
STOCK_AT="${STOCK_AT:-0747}"
STOCK_SEED=supabase/restore/archive_seed_0747.sql
KNOWN="$HERE/upgrade_equivalence_known.txt"
OUT="${EQUIV_OUT:-}"
if [ -z "$OUT" ]; then
  if [ -d preview ]; then OUT=preview/upgrade-equivalence; else OUT=report/upgrade-equivalence; fi
fi

fail() { echo "::error::upgrade equivalence: $*"; exit 1; }
say() { printf '  %s\n' "$*"; }

C="$(docker ps --format '{{.Names}}' | grep -E '^supabase_db' | head -1)"
[ -n "$C" ] || fail "the local stack's database container is not running"

admin() { docker exec -i -e PGPASSWORD=postgres "$C" "$@"; }
asql() { admin psql -X -h 127.0.0.1 -U supabase_admin "$@"; }
# Migrations run as `postgres`, the role the replay and the installer use.
psq() { local db=$1; shift; admin psql -X -h 127.0.0.1 -U postgres -d "$db" "$@"; }

made_template=0
cleanup() {
  for db in "$FRESH" "$UPGRADED" "$PROBE"; do
    asql -d postgres -q -c "drop database if exists $db with (force)" >/dev/null 2>&1
  done
  if [ "$made_template" = 1 ]; then
    asql -d postgres -q -c "drop database if exists $TEMPLATE with (force)" >/dev/null 2>&1
  fi
}
trap cleanup EXIT

started=$SECONDS
mkdir -p "$OUT"

echo "--- the empty project"
if [ "$(asql -d postgres -At -c "select count(*) from pg_database where datname = '$TEMPLATE'")" != 1 ]; then
  made_template=1
  KEEP_EMPTY=1 PREPARE_ONLY=1 bash "$HERE/instance_lifecycle_check.sh" > "$OUT/empty-project.log" 2>&1 \
    || { tail -20 "$OUT/empty-project.log"; fail "could not prepare the empty project"; }
  say "prepared: $(grep -E '^empty project:' "$OUT/empty-project.log" | head -1)"
else
  say "found $TEMPLATE"
fi
OWNER="$(asql -d postgres -At -c "select pg_get_userbyid(datdba) from pg_database where datname = 'postgres'")"
cleanup_dbs() {
  for db in "$FRESH" "$UPGRADED" "$PROBE"; do
    asql -d postgres -q -c "drop database if exists $db with (force)" >/dev/null 2>&1
  done
}
cleanup_dbs
for db in "$FRESH" "$UPGRADED" "$PROBE"; do
  asql -d postgres -q -v ON_ERROR_STOP=1 -c "create database $db template $TEMPLATE owner $OWNER" \
    || fail "could not copy the empty project into $db"
done

version_of() { local n; n="${1##*/}"; n="${n%%_*}"; echo "$((10#$n))"; }
latest=0
for f in supabase/migrations/*.sql; do v="$(version_of "$f")"; [ "$v" -gt "$latest" ] && latest=$v; done
count="$(ls supabase/migrations/*.sql | wc -l | tr -d ' ')"

# One file, one transaction, a session of its own: what the installer sends.
emit() { printf '\\connect\nbegin;\n'; cat "$1"; printf '\n;\ncommit;\n'; }
marker() { psq "$1" -At -c "select version from public.deskilo_schema_version" 2>/dev/null; }
run_stream() { # <db> <label>: stdin is the stream
  local db=$1 label=$2
  if ! psq "$db" -q -v ON_ERROR_STOP=1 > "$OUT/$label.log" 2>&1; then
    tail -15 "$OUT/$label.log"
    fail "$label: a migration did not apply"
  fi
}

echo "--- fresh: every migration onto the empty project"
t=$SECONDS
for f in supabase/migrations/*.sql; do emit "$f"; done | run_stream "$FRESH" fresh
[ "$(marker "$FRESH")" = "$latest" ] || fail "fresh: the marker reads '$(marker "$FRESH")', not $latest"
say "$count migrations, marker $latest ($((SECONDS - t))s)"

echo "--- upgraded: an archive at $BASELINE, in-flight work at $STAGE_AT, goods at $STOCK_AT, then the rest over them"
t=$SECONDS
{
  for f in supabase/migrations/*.sql; do
    [ "$(version_of "$f")" -le "$((10#$BASELINE))" ] && emit "$f"
  done
  emit "$SEED"
  for f in supabase/migrations/*.sql; do
    v="$(version_of "$f")"
    [ "$v" -gt "$((10#$BASELINE))" ] && [ "$v" -le "$((10#$STAGE_AT))" ] && emit "$f"
  done
  emit "$STAGE_SEED"
  for f in supabase/migrations/*.sql; do
    v="$(version_of "$f")"
    [ "$v" -gt "$((10#$STAGE_AT))" ] && [ "$v" -le "$((10#$STOCK_AT))" ] && emit "$f"
  done
  emit "$STOCK_SEED"
  for f in supabase/migrations/*.sql; do
    [ "$(version_of "$f")" -gt "$((10#$STOCK_AT))" ] && emit "$f"
  done
  true
} | run_stream "$UPGRADED" upgraded
[ "$(marker "$UPGRADED")" = "$latest" ] || fail "upgraded: the marker reads '$(marker "$UPGRADED")', not $latest"
rows="$(psq "$UPGRADED" -At -c "select (select count(*) from public.invoices) || ' invoices, '
  || (select count(*) from public.ledger_entries) || ' postings, '
  || (select count(*) from public.payment_intents) || ' intents, '
  || (select count(*) from public.invoice_transmissions) || ' transmissions, '
  || (select count(*) from public.stock_movements) || ' stock movements'")"
say "the same $count migrations, over $rows; marker $latest ($((SECONDS - t))s)"

echo "--- what each installation is"
print_of() { # <db> <file>
  asql -d "$1" -At -q -v ON_ERROR_STOP=1 < "$HERE/upgrade_equivalence.sql" > "$2.raw" 2> "$2.err" \
    || { cat "$2.err"; fail "could not read $1"; }
  LC_ALL=C grep -vE '^data ' "$2.raw" | LC_ALL=C sort > "$2"
  LC_ALL=C grep -E '^data ' "$2.raw" | LC_ALL=C sort > "$2.data"
  rm -f "$2.raw" "$2.err"
  [ "$(grep -c '' "$2")" -gt 1000 ] || fail "$1 printed only $(grep -c '' "$2") facts"
}
print_of "$FRESH" "$OUT/fresh.txt"
print_of "$UPGRADED" "$OUT/upgraded.txt"
print_of postgres "$OUT/stack.txt"
kinds() { cut -d' ' -f1 "$1" | sort | uniq -c | awk '{printf "%s %s, ", $2, $1}' | sed 's/, $//'; }
say "fresh:    $(grep -c '' "$OUT/fresh.txt") facts ($(kinds "$OUT/fresh.txt"))"
say "upgraded: $(grep -c '' "$OUT/upgraded.txt") facts"
say "stack:    $(grep -c '' "$OUT/stack.txt") facts"

status=0

# The definitions of the functions whose digests differ, side by side.
function_diff() { # <db a> <db b> <diff file>
  local a=$1 b=$2 n=0 sig
  grep -E '^[+-]function ' "$3" | sed -E 's/^[+-]function (.*\)) kind=.*/\1/' | sort -u | while read -r sig; do
    n=$((n + 1)); [ "$n" -gt 8 ] && break
    echo "::group::$sig"
    diff -u <(asql -d "$a" -At -c "set search_path = ''; select pg_get_functiondef(to_regprocedure('$sig'))" 2>&1) \
            <(asql -d "$b" -At -c "set search_path = ''; select pg_get_functiondef(to_regprocedure('$sig'))" 2>&1) | head -80
    echo "::endgroup::"
  done
}

echo "--- an upgraded installation equals a fresh one"
if diff -u "$OUT/fresh.txt" "$OUT/upgraded.txt" > "$OUT/fresh-vs-upgraded.diff"; then
  say "equal: $(grep -c '' "$OUT/fresh.txt") facts, line for line"
else
  n="$(grep -cE '^[+-][a-z]' "$OUT/fresh-vs-upgraded.diff")"
  echo "::error::upgrade equivalence: the upgraded installation differs from the fresh one in $n lines (- fresh, + upgraded)"
  grep -E '^[+-][a-z]' "$OUT/fresh-vs-upgraded.diff" | cut -c1-400 | head -60
  function_diff "$FRESH" "$UPGRADED" "$OUT/fresh-vs-upgraded.diff"
  status=1
fi
# Advice: the rows the migrations seed. The archive's own rows (its people,
# its accounts) are in the upgraded one by construction.
if ! diff -u "$OUT/fresh.txt.data" "$OUT/upgraded.txt.data" > "$OUT/fresh-vs-upgraded.data.diff"; then
  say "seeded rows that differ (advice; the archive adds its own): $(grep -E '^[+-]data ' "$OUT/fresh-vs-upgraded.data.diff" | cut -d' ' -f2 | sort -u | tr '\n' ' ')"
else
  say "seeded rows: equal in $(grep -c '' "$OUT/fresh.txt.data") tables"
fi

echo "--- the installer's path equals the replay the contract is read from"
# What the stack has that a database beside it cannot: its migration
# bookkeeping, the scheduler (pg_cron lives in one database of a cluster)
# and what the earlier steps of the job installed for themselves.
stack_only='^(schema (supabase_migrations|cron|tests|pgtap) |extension (pg_cron|pgtap) |cron |default_acl .* schema=cron )'
LC_ALL=C grep -vE "$stack_only" "$OUT/stack.txt" > "$OUT/stack.comparable.txt"
LC_ALL=C grep -vE "$stack_only" "$OUT/fresh.txt" > "$OUT/fresh.comparable.txt"
if diff -u "$OUT/stack.comparable.txt" "$OUT/fresh.comparable.txt" > "$OUT/stack-vs-fresh.diff"; then
  say "equal: $(grep -c '' "$OUT/fresh.comparable.txt") facts, line for line"
else
  n="$(grep -cE '^[+-][a-z]' "$OUT/stack-vs-fresh.diff")"
  echo "the replay and the installer's path differ in $n lines (- the stack, + fresh):"
  grep -E '^[+-][a-z]' "$OUT/stack-vs-fresh.diff" | cut -d' ' -f1 | sort | uniq -c | sed 's/^/    /'
  grep -E '^[+-][a-z]' "$OUT/stack-vs-fresh.diff" | cut -c1-300 | head -40
  function_diff postgres "$FRESH" "$OUT/stack-vs-fresh.diff"
  if [ "${STACK_ADVISORY:-}" = 1 ]; then
    say "(advisory: STACK_ADVISORY=1)"
  else
    echo "::error::upgrade equivalence: the installer's path does not build what the replay builds"
    status=1
  fi
fi
say "only in the stack, by construction: $(LC_ALL=C grep -cE "$stack_only" "$OUT/stack.txt") facts ($(LC_ALL=C grep -E "$stack_only" "$OUT/stack.txt" | cut -d' ' -f1 | sort | uniq -c | awk '{printf "%s %s, ", $2, $1}' | sed 's/, $//'))"

echo "--- a patch whose anchor is gone"
t=$SECONDS
psq "$PROBE" -q -v ON_ERROR_STOP=1 > "$OUT/probe-setup.log" 2>&1 <<'SQL' || { cat "$OUT/probe-setup.log"; fail "could not set the probe up"; }
create schema zz_probe;
create table zz_probe.files (name text primary key, body text not null);
create table zz_probe.results (migration text not null, fn text not null, verdict text not null, detail text);
create function zz_probe.trial(p_name text) returns void language plpgsql as $probe$
declare
  v_body text;
  v_changed oid[];
  v_oid oid;
  v_sig text;
  v_def text;
  v_pos int;
  v_src text;
  v_verdict text;
  v_detail text;
  c_stub constant text := ' begin raise exception ''zz-probe-stub''; end ';
begin
  select body into strict v_body from zz_probe.files where name = p_name;
  create temp table if not exists zz_before (oid oid primary key, src text);
  truncate zz_before;
  insert into zz_before
  select p.oid, p.prosrc from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.prokind in ('f', 'p');
  -- the dry run: which existing bodies this file rewrites in place
  begin
    execute v_body;
    select array_agg(p.oid order by p.oid) into v_changed
      from zz_before b join pg_proc p on p.oid = b.oid
     where p.prosrc is distinct from b.src;
    raise exception 'zz-rollback' using errcode = 'ZZ000';
  exception
    when sqlstate 'ZZ000' then null;
    when others then
      insert into zz_probe.results values (p_name, '', 'DRY_RUN_FAILED', sqlstate || ' ' || sqlerrm);
      return;
  end;
  foreach v_oid in array coalesce(v_changed, '{}'::oid[]) loop
    v_sig := v_oid::regprocedure::text;
    v_verdict := null;
    v_detail := null;
    begin
      v_def := pg_get_functiondef(v_oid);
      v_pos := position(E'\nAS $' in v_def);
      if v_pos = 0 then
        v_verdict := 'UNSUPPORTED';
      else
        -- the same function, a body with no anchor in it
        execute regexp_replace(left(v_def, v_pos - 1), E'\\n LANGUAGE \\w+', E'\n LANGUAGE plpgsql')
          || E'\nAS $zzstub$' || c_stub || '$zzstub$';
        execute v_body;
        select p.prosrc into v_src from pg_proc p where p.oid = v_oid;
        v_verdict := case when not found then 'RESTATED'
                          when v_src = c_stub then 'SILENT'
                          when position('zz-probe-stub' in v_src) > 0 then 'PATCHED_STUB'
                          else 'RESTATED' end;
      end if;
      raise exception 'zz-rollback' using errcode = 'ZZ000';
    exception
      when sqlstate 'ZZ000' then null;
      when others then
        v_verdict := case when sqlerrm like '%zz-probe-stub%' then 'CALLED' else 'LOUD' end;
        v_detail := sqlstate || ' ' || sqlerrm;
    end;
    insert into zz_probe.results values (p_name, v_sig, v_verdict, v_detail);
  end loop;
end
$probe$;
create function zz_probe.stub(p_oid oid) returns void language plpgsql as $probe$
declare
  v_def text := pg_get_functiondef(p_oid);
  v_pos int := position(E'\nAS $' in v_def);
begin
  if v_pos = 0 then
    raise exception 'zz-probe: % has no body to replace', p_oid::regprocedure;
  end if;
  execute regexp_replace(left(v_def, v_pos - 1), E'\\n LANGUAGE \\w+', E'\n LANGUAGE plpgsql')
    || E'\nAS $zzstub$ begin raise exception ''zz-probe-stub''; end $zzstub$';
end
$probe$;
SQL
patching="$(grep -l 'pg_get_functiondef' supabase/migrations/*.sql | wc -l | tr -d ' ')"
grep -l 'zzq4492' supabase/migrations/*.sql >/dev/null 2>&1 && fail "a migration holds the probe's own quoting tag"
for f in supabase/migrations/*.sql; do
  if grep -q 'pg_get_functiondef' "$f"; then
    n="$(basename "$f" .sql)"
    printf '\\connect\ninsert into zz_probe.files (name, body) values (%s, $zzq4492$' "'$n'"
    cat "$f"
    printf '\n$zzq4492$);\nselect zz_probe.trial(%s);\n' "'$n'"
  fi
  emit "$f"
done | run_stream "$PROBE" probe
[ "$(marker "$PROBE")" = "$latest" ] || fail "probe: the marker reads '$(marker "$PROBE")', not $latest"
psq "$PROBE" -At -F $'\t' -c "select migration, fn, verdict, regexp_replace(coalesce(detail, ''), '\s+', ' ', 'g')
                                from zz_probe.results order by 1, 2" > "$OUT/anchor-trials.tsv" \
  || fail "could not read the trials"
trials="$(grep -c '' "$OUT/anchor-trials.tsv")"
say "$patching migrations read a live body; $(cut -f1 "$OUT/anchor-trials.tsv" | sort -u | grep -c '') of them rewrite $trials existing bodies in place, each tried without its anchor ($((SECONDS - t))s)"
cut -f3 "$OUT/anchor-trials.tsv" | sort | uniq -c | sed 's/^/    /'
# How a loud one speaks: by its own message, or only because EXECUTE was handed nothing.
say "of the loud ones: $(awk -F'\t' '$3 == "LOUD" && $4 ~ /EXECUTE.*null|null.*EXECUTE/' "$OUT/anchor-trials.tsv" | grep -c '') stop on a null EXECUTE (no message of their own), $(awk -F'\t' '$3 == "LOUD" && $4 !~ /EXECUTE.*null|null.*EXECUTE/' "$OUT/anchor-trials.tsv" | grep -c '') name what is missing"

# Settled by a later file that states the function whole: the anchorless body
# again, on the replayed database, then that file; the body must be the replay's.
: > "$OUT/anchor-settled.txt"
while IFS=$'\t' read -r mig fn verdict _; do
  case "$verdict" in SILENT|PATCHED_STUB) ;; *) continue ;; esac
  name="${fn%%(*}"
  for f in supabase/migrations/*.sql; do
    [ "$(version_of "$f")" -gt "$(version_of "$mig")" ] || continue
    grep -qiE "create or replace function public\.$name\b" "$f" || continue
    settled="$( { printf "begin;\ncreate temp table zz_was on commit drop as select p.prosrc from pg_proc p where p.oid = '%s'::regprocedure;\nselect zz_probe.stub('%s'::regprocedure);\n" "$fn" "$fn"
                  cat "$f"
                  printf "\n;\nselect 'ZZSETTLED' where (select p.prosrc from pg_proc p where p.oid = '%s'::regprocedure) = (select prosrc from zz_was);\nrollback;\n" "$fn"
                } | psq "$PROBE" -At -q -v ON_ERROR_STOP=1 2>/dev/null | grep -c '^ZZSETTLED$' )"
    if [ "$settled" = 1 ]; then
      printf '%s %s %s\t%s\n' "$verdict" "$mig" "$fn" "$(basename "$f" .sql)" >> "$OUT/anchor-settled.txt"
      break
    fi
  done
done < "$OUT/anchor-trials.tsv"
if [ -s "$OUT/anchor-settled.txt" ]; then
  say "settled by a later migration that states the function whole (met with the anchorless body, it leaves the replay's):"
  awk -F'\t' '{ print "    " $1 "   <- " $2 }' "$OUT/anchor-settled.txt"
fi
awk -F'\t' '$3 == "SILENT" || $3 == "PATCHED_STUB" { print $3 " " $1 " " $2 }' "$OUT/anchor-trials.tsv" | LC_ALL=C sort \
  | LC_ALL=C comm -23 - <(cut -f1 "$OUT/anchor-settled.txt" | LC_ALL=C sort) > "$OUT/anchor-findings.txt"
grep -vE '^[[:space:]]*(#|$)' "$KNOWN" 2>/dev/null | sed -E 's/[[:space:]]+#.*$//' | LC_ALL=C sort > "$OUT/anchor-known.txt"
new="$(LC_ALL=C comm -23 "$OUT/anchor-findings.txt" "$OUT/anchor-known.txt")"
gone="$(LC_ALL=C comm -13 "$OUT/anchor-findings.txt" "$OUT/anchor-known.txt")"
if [ -n "$new" ]; then
  echo "::error::upgrade equivalence: a patch completed without its anchor and said nothing (not in $(basename "$KNOWN")):"
  printf '%s\n' "$new" | sed 's/^/    /'
  status=1
fi
if [ -n "$gone" ]; then
  echo "listed as known and no longer found (remove from $(basename "$KNOWN")):"
  printf '%s\n' "$gone" | sed 's/^/    /'
fi
other="$(awk -F'\t' '$3 == "DRY_RUN_FAILED" || $3 == "UNSUPPORTED" || $3 == "CALLED" { print "    " $3 " " $1 " " $2 " " substr($4, 1, 160) }' "$OUT/anchor-trials.tsv")"
[ -z "$other" ] || { echo "not answered by a trial:"; printf '%s\n' "$other"; }

# The archive itself, goods included: the existing drill, in its third case,
# on the empty project this run has at hand (it runs on every Quality run; here
# so that a branch can see it before its pull request).
echo "--- the populated upgrade, with goods"
if STOCK_AT="$STOCK_AT" bash "$HERE/populated_upgrade_check.sh"; then
  [ -d report ] && cp report/stock-*.txt "$OUT/" 2>/dev/null
else
  status=1
fi

echo "upgrade equivalence took $((SECONDS - started))s; the texts are in $OUT/"
exit $status
