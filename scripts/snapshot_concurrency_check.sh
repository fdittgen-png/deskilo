#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #2587 C2 — the fiscal source is read from ONE snapshot, whatever the
# other sessions do meanwhile.
#
# pgTAP runs a file in one transaction and cannot interleave writers, so
# the promise "documents, ledger and totals of an accounting export belong
# together" is proved here, with real psql processes against the replayed
# stack (the address is the only argument; nothing here starts a stack).
#
#  1. Torn read. A writer commits, again and again, a pair that belongs
#     together: an invoice R<i> and the ledger entry R<i> that books it,
#     in ONE transaction. A reader asks for the source in a loop, as the
#     real role. Every answer must hold both halves of a pair or neither,
#     and its control totals must equal the rows it carries. The answers
#     must also change while the writer runs, or the interleaving proved
#     nothing.
#  2. Uncommitted work is invisible and committed work appears: a session
#     holding an uncommitted invoice is not seen; once it commits, a new
#     read has it.
#  3. Revocation. A read already running keeps the database snapshot it
#     began with (no statement can be rewound); the next read, after the
#     member lost viewFinances, is refused.
set -uo pipefail

DB_URL=${1:?usage: snapshot_concurrency_check.sh <db url>}
# Fresh ids each run: the invoices it writes can never be deleted again.
uid() { uuidgen | tr 'A-Z' 'a-z'; }
RUN="$$" # the rows of this run are named by it, and live in a workspace of their own
U_OWNER=$(uid); U_PLAIN=$(uid); WS=$(uid); M_OWNER=$(uid); M_PLAIN=$(uid)
PAIRS=${SNAPSHOT_PAIRS:-120}

say() { printf '  %s\n' "$*"; }
fail() { echo "::error::$*"; exit 1; }
psql_q() { psql "$DB_URL" -qtAX -v ON_ERROR_STOP=1 -c "$1"; }

# The caller, as the real role: a claim and `authenticated`, local to the
# transaction the statement runs in.
as() {
  printf "select set_config('request.jwt.claims', '{\"sub\":\"%s\",\"role\":\"authenticated\"}', true); set local role authenticated;" "$1"
}
SRC="select public.accounting_source_snapshot_v1('$WS', date '2026-01-01', date '2026-12-31')"

echo "the fiscal source, one snapshot"

fixture=$(psql "$DB_URL" -qX -v ON_ERROR_STOP=1 2>&1 <<SQL
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values ('$U_OWNER', '00000000-0000-0000-0000-000000000000', 'authenticated',
        'authenticated', 'src-owner-${RUN}-${U_OWNER}@deskilo.test', '', now(), now(), now()),
       ('$U_PLAIN', '00000000-0000-0000-0000-000000000000', 'authenticated',
        'authenticated', 'src-plain-${RUN}-${U_PLAIN}@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by)
values ('$WS', 'Source race $RUN', 'FR', 'EUR', 'Europe/Paris', '$U_OWNER');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin)
values ('$M_OWNER', '$WS', '$U_OWNER', true, true),
       ('$M_PLAIN', '$WS', '$U_PLAIN', false, true);
SQL
) || fail "the fixture would not build. psql said: $fixture"

invoice_sql() { # number total
  printf "insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency, member_name, workspace_name, issuer_name, signature, issued_at)
          values ('%s', '%s', '%s', %s, %s, '[]'::jsonb, %s, 'EUR', 'M', 'W', 'O', 's', '2026-06-15 10:00+00')" \
    "$WS" "$M_PLAIN" "$M_OWNER" "$1" "$1" "$2"
}
ledger_sql() { # description amount
  printf "insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
          values ('%s', '%s', 'credit', 'payment', %s, %s, '2026-06', '2026-06-15')" \
    "$WS" "$M_PLAIN" "$2" "$1"
}

# ── 1. torn read ────────────────────────────────────────────────────────
writer_for() { cat <<SQL
do \$w\$
begin
  for i in 1..$PAIRS loop
    $(invoice_sql "'$1' || i" "i * 100");
    $(ledger_sql "'$1' || i" "i * 100");
    commit;
    perform pg_sleep(0.02);
  end loop;
end
\$w\$
SQL
}
# The reader never commits: every statement in the loop takes its own
# snapshot, the way separate requests do.
reader_for() { # function prefix
  cat <<SQL
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"$U_OWNER","role":"authenticated"}', false);
do \$r\$
declare
  j jsonb; inv text; led text; sums bigint; sumsl bigint;
  seen int[] := '{}'; n int;
begin
  for k in 1..400 loop
    j := $1('$WS', date '2026-01-01', date '2026-12-31');
    select coalesce(string_agg(e->>'number', ',' order by e->>'number'), ''),
           coalesce(sum((e->>'total_cents')::bigint), 0)
      into inv, sums
      from jsonb_array_elements(j->'invoices') e where e->>'number' like '$2%';
    select coalesce(string_agg(e->>'description', ',' order by e->>'description'), ''),
           coalesce(sum((e->>'amount_cents')::bigint), 0)
      into led, sumsl
      from jsonb_array_elements(j->'ledger') e where e->>'description' like '$2%';
    if inv <> led or sums <> sumsl then
      raise exception 'TORN READ: invoices [%] vs ledger [%]', inv, led;
    end if;
    if (j#>>'{totals,invoices,count}')::int <> jsonb_array_length(j->'invoices')
       or (j#>>'{totals,ledger,count}')::int <> jsonb_array_length(j->'ledger')
       or (j#>>'{totals,invoices,total_cents}')::bigint
            <> (select coalesce(sum((e->>'total_cents')::bigint), 0) from jsonb_array_elements(j->'invoices') e) then
      raise exception 'CONTROL TOTALS differ from the rows carried';
    end if;
    n := jsonb_array_length(j->'invoices');
    if not (n = any(seen)) then seen := seen || n; end if;
    perform pg_sleep(0.002);
  end loop;
  raise notice 'DISTINCT_STATES=%', coalesce(array_length(seen, 1), 0);
end
\$r\$
SQL
}
psql "$DB_URL" -qX -v ON_ERROR_STOP=1 -c "$(writer_for R)" >/tmp/snapshot_writer.log 2>&1 &
writer_pid=$!
sleep 0.3
read_out=$(psql "$DB_URL" -qX -v ON_ERROR_STOP=1 -c "$(reader_for public.accounting_source_snapshot_v1 R)" 2>&1)
read_rc=$?
wait "$writer_pid" || fail "the writer did not finish: $(cat /tmp/snapshot_writer.log)"
[ "$read_rc" -eq 0 ] || fail "a read of the fiscal source was inconsistent. psql said: $read_out"
states=$(printf '%s' "$read_out" | sed -n 's/.*DISTINCT_STATES=\([0-9]*\).*/\1/p')
[ "${states:-0}" -ge 5 ] \
  || fail "the reader saw only ${states:-0} distinct states while $PAIRS pairs were committed: the interleaving proved nothing"
say "400 reads while $PAIRS invoice+ledger pairs committed: every answer whole, ${states} distinct states seen"

# The control that makes the proof worth something: the same reader, the
# same writer, against a read that takes its two halves in two statements
# (a fresh snapshot each, as an export assembled from separate requests
# would). It MUST be caught; if it is not, this harness cannot see a torn
# read and the green above means nothing.
psql_q "create or replace function public.zz_torn_probe(w uuid, f date, t date) returns jsonb language plpgsql as \$f\$
declare i jsonb; l jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object('number', number, 'total_cents', total_cents)), '[]') into i
    from public.invoices where workspace_id = w;
  perform pg_sleep(0.01);
  select coalesce(jsonb_agg(jsonb_build_object('description', description, 'amount_cents', amount_cents)), '[]') into l
    from public.ledger_entries where workspace_id = w;
  return jsonb_build_object('invoices', i, 'ledger', l, 'totals', jsonb_build_object(
    'invoices', jsonb_build_object('count', jsonb_array_length(i), 'total_cents', (select coalesce(sum((e->>'total_cents')::bigint), 0) from jsonb_array_elements(i) e)),
    'ledger', jsonb_build_object('count', jsonb_array_length(l))));
end \$f\$" >/dev/null || fail "the control probe would not build"
writer2_log=/tmp/snapshot_writer2.log
psql "$DB_URL" -qX -v ON_ERROR_STOP=1 -c "$(writer_for Q)" >"$writer2_log" 2>&1 &
writer2=$!
sleep 0.3
torn_out=$(psql "$DB_URL" -qX -v ON_ERROR_STOP=0 -c "$(reader_for public.zz_torn_probe Q)" 2>&1)
wait "$writer2" || true
psql_q "drop function public.zz_torn_probe(uuid, date, date)" >/dev/null
case "$torn_out" in
  *"TORN READ"*|*"CONTROL TOTALS"*) say "control: the same reader catches a read assembled from two statements" ;;
  *) fail "the control read was not caught — the harness cannot see a torn read: $torn_out" ;;
esac

# ── 2. uncommitted is invisible, committed appears ──────────────────────
total_r() { psql "$DB_URL" -qtAX -c "begin; $(as "$U_OWNER") select (public.accounting_source_snapshot_v1('$WS', date '2026-01-01', date '2026-12-31')#>>'{totals,invoices,count}'); commit;" 2>&1 | grep -E '^[0-9]+$' | head -1; }
before=$(total_r)
psql "$DB_URL" -qX -v ON_ERROR_STOP=1 \
  -c "begin; $(invoice_sql "'HOLD'" 1); select pg_sleep(3); commit;" >/dev/null 2>&1 &
holder=$!
sleep 1
during=$(total_r)
wait "$holder" || fail "the holding session did not commit"
after=$(total_r)
[ "$during" = "$before" ] || fail "an uncommitted invoice showed in the source ($before -> $during)"
[ "$after" = "$((before + 1))" ] || fail "a committed invoice did not appear in the next read ($before -> $after)"
say "an uncommitted invoice is not in the source ($before); once committed the next read has it ($after)"

# ── 3. revocation ───────────────────────────────────────────────────────
# A running transaction keeps its snapshot — including who may read — and
# says so; the read after the commit of the revocation is refused.
psql "$DB_URL" -qtAX -v ON_ERROR_STOP=1 \
  -c "begin isolation level repeatable read; $(as "$U_PLAIN") select public.accounting_source_snapshot_v1('$WS', date '2026-01-01', date '2026-12-31')->>'status'; select pg_sleep(3); select public.accounting_source_snapshot_v1('$WS', date '2026-01-01', date '2026-12-31')->>'status'; commit;" \
  >/tmp/snapshot_running.log 2>&1 &
running=$!
sleep 1
psql_q "update public.members set is_admin = false where id = '$M_PLAIN'" >/dev/null \
  || fail "could not revoke the admin's rights"
wait "$running" || fail "the running read failed: $(cat /tmp/snapshot_running.log)"
[ "$(grep -c '^ok$' /tmp/snapshot_running.log)" = 2 ] \
  || fail "the read that began before the revocation did not finish on its own snapshot: $(cat /tmp/snapshot_running.log)"
fresh=$(psql "$DB_URL" -qX -c "begin; $(as "$U_PLAIN") $SRC; commit;" 2>&1 || true)
case "$fresh" in
  *"not allowed"*|*42501*) say "after the revocation commits, a new read is refused; the one already running finished on its own snapshot" ;;
  *) fail "a read after the admin lost viewFinances was answered. It said: $fresh" ;;
esac
echo "the fiscal source holds"
