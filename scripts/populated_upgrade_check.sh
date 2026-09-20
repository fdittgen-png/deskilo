#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1338 — a populated instance upgrades and keeps its archives.
#
# The replay from empty proves the migrations run; the restore drill
# proves a CURRENT backup comes back whole. Neither says what happens to
# an instance that already holds issued invoices, posted credits and
# captured payments when the next twenty migrations run over it — and
# INVARIANTS.md records the day that went wrong: backfills before 0152
# rewrote signed columns, and every hash from before that day is
# `unverifiable` for good.
#
# So this installs a supported populated baseline the same way the
# lifecycle check installs anything — file by file, as `postgres`, onto
# the empty-project template that check leaves behind — seeds the
# archive of `supabase/restore/archive_seed.sql` on it, runs every later
# migration, and compares:
#
#   * a snapshot of every signed field, hash, posting and payment
#     relation, taken before and after: byte-equal, or the diff is the
#     report;
#   * `verify_invoice_signature`: the modern invoice stays `verified`,
#     the legacy one stays `unverifiable` — no hash was recomputed to
#     make it look better;
#   * the 0240 association backfill: the intent with one credit is
#     associated, the two sharing a credit are not, and the
#     reconciliation names them;
#   * a deliberately destructive control (`destructive_control.sql`,
#     which "repairs" the legacy hash) applied through the same path:
#     the comparison MUST catch it, or the check proves nothing;
#   * the permitted transitions after the upgrade — void, settle — still
#     work, an edit or a delete is still refused, and a synthetic
#     alteration reads `altered`.
#
# Baseline: 0226, the first schema that writes its own version marker.
# It is a parameter (BASELINE=NNNN) so a second supported baseline is a
# variable, not a second script.
set -uo pipefail

BASELINE="${BASELINE:-0226}"
TEMPLATE="${TEMPLATE:-deskilo_lifecycle_empty}"
DB="deskilo_archive"
SEED=supabase/restore/archive_seed.sql
CONTROL=supabase/restore/destructive_control.sql
OWNER_ID=00000000-0000-4000-8000-0000000a0001
WS=00000000-0000-4000-8000-0000000a0002

fail() { echo "::error::populated upgrade: $*"; exit 1; }
say() { printf '  %s\n' "$*"; }

C="$(docker ps --format '{{.Names}}' | grep -E '^supabase_db' | head -1)"
[ -n "$C" ] || fail "the local stack's database container is not running"

admin() { docker exec -i -e PGPASSWORD=postgres "$C" "$@"; }
asql() { admin psql -X -h 127.0.0.1 -U supabase_admin "$@"; }
# Migrations and checks run as `postgres`, the role the replay and the
# lifecycle install use; RLS is not what is under test here.
psq() { admin psql -X -h 127.0.0.1 -U postgres -d "$DB" -v ON_ERROR_STOP=1 "$@"; }

cleanup() { asql -d postgres -q -c "drop database if exists $DB with (force)" >/dev/null 2>&1; }
trap cleanup EXIT

started=$SECONDS
echo "--- a populated instance at $BASELINE"
[ "$(asql -d postgres -At -c "select count(*) from pg_database where datname = '$TEMPLATE'")" = 1 ] \
  || fail "the empty project $TEMPLATE is not there — run scripts/instance_lifecycle_check.sh with KEEP_EMPTY=1 first"
OWNER="$(asql -d postgres -At -c "select pg_get_userbyid(datdba) from pg_database where datname = 'postgres'")"
cleanup
asql -d postgres -q -v ON_ERROR_STOP=1 -c "create database $DB template $TEMPLATE owner $OWNER" \
  || fail "could not copy the empty project into $DB"

# One file, one transaction — what `InstanceBuilder.installSchema` sends.
apply() { psq -q -1 < "$1" >/dev/null || fail "$1 did not apply"; }
version_of() { local n; n="${1##*/}"; n="${n%%_*}"; echo "$((10#$n))"; }

before=0; after=0; latest=0
for f in supabase/migrations/*.sql; do
  v="$(version_of "$f")"
  [ "$v" -gt "$latest" ] && latest=$v
  if [ "$v" -le "$((10#$BASELINE))" ]; then apply "$f"; before=$((before + 1)); fi
done
marker() { psq -At -c "select version from public.deskilo_schema_version" 2>/dev/null; }
[ "$(marker)" = "$((10#$BASELINE))" ] || fail "after $before migrations the marker reads '$(marker)', not $((10#$BASELINE))"
say "$before migrations installed, marker $((10#$BASELINE))"

apply "$SEED"
say "archive seeded: 3 invoices, 2 postings, 1 match, 3 captured intents"

# Everything the archive is made of, keyed by fixed ids; nothing a later
# migration may legitimately add (new columns) and nothing that moves on
# its own (the system columns).
SNAPSHOT_SQL="
select 'invoice ' || number || ' ' || concat_ws(' | ', id::text, signature,
         coalesce(signature_algo::text, 'no-algo'), total_cents::text, currency, kind,
         period, issued_at::text, md5(lines::text), md5(coalesce(details::text, '')),
         md5(coalesce(parties::text, '')), md5(coalesce(vat_totals::text, '')),
         member_name, member_address, workspace_name, workspace_address, issuer_name,
         coalesce(replaces_invoice_id::text, ''), replaces_number,
         coalesce(voided_at::text, ''), coalesce(settled_by_invoice_id::text, ''))
  from public.invoices where workspace_id = '$WS'
union all
select 'ledger ' || concat_ws(' | ', id::text, kind, category, amount_cents::text,
         period, coalesce(description, ''), member_id::text)
  from public.ledger_entries where workspace_id = '$WS'
union all
select 'match ' || concat_ws(' | ', invoice_id::text, paid_cents::text, resolution,
         coalesce(credit_ledger_id::text, ''))
  from public.invoice_matches where workspace_id = '$WS'
union all
select 'intent ' || concat_ws(' | ', id::text, order_id, coalesce(capture_id, ''),
         status, amount_cents::text, period)
  from public.payment_intents where workspace_id = '$WS'
order by 1"
snapshot() { psq -At -c "$SNAPSHOT_SQL"; }

# As the owner, the way the app asks.
AS_OWNER="select set_config('request.jwt.claims',
  '{\"sub\": \"$OWNER_ID\", \"role\": \"authenticated\"}', false);"
verify() {
  psq -At -c "$AS_OWNER
    select string_agg(number || '=' || public.verify_invoice_signature(id), ' ' order by number)
      from public.invoices where workspace_id = '$WS'" | tail -1
}

mkdir -p report
snapshot > report/archive-before.txt || fail "could not read the archive before the upgrade"
[ "$(grep -c '' report/archive-before.txt)" = 9 ] || fail "the snapshot has $(grep -c '' report/archive-before.txt) rows, not 9"
v="$(verify)"
[ "$v" = "ARC-1=verified ARC-2=unverifiable ARC-3=verified" ] \
  || fail "before the upgrade the signatures read [$v]: the seed is not what it claims"
say "before: ARC-1 verified, ARC-2 unverifiable, ARC-3 verified"

echo "--- the upgrade"
for f in supabase/migrations/*.sql; do
  if [ "$(version_of "$f")" -gt "$((10#$BASELINE))" ]; then apply "$f"; after=$((after + 1)); fi
done
[ "$(marker)" = "$latest" ] || fail "after the upgrade the marker reads '$(marker)', not $latest"
say "$after migrations ran over the populated schema, marker $latest"

snapshot > report/archive-after.txt || fail "could not read the archive after the upgrade"
if ! diff -u report/archive-before.txt report/archive-after.txt > report/archive-diff.txt; then
  cat report/archive-diff.txt
  fail "the upgrade changed the archive — the diff above names what moved"
fi
say "signed fields, hashes, postings and payment relations: byte-equal before and after"

v="$(verify)"
[ "$v" = "ARC-1=verified ARC-2=unverifiable ARC-3=verified" ] \
  || fail "after the upgrade the signatures read [$v]"
say "after: ARC-1 verified, ARC-2 still unverifiable (no hash recomputed), ARC-3 verified"

assoc="$(psq -At -c "select string_agg(order_id || '=' || coalesce(ledger_entry_id::text, 'none'), ' ' order by order_id)
  from public.payment_intents where workspace_id = '$WS'")"
[ "$assoc" = "ORDER-1=00000000-0000-4000-8000-0000000a0201 ORDER-2=none ORDER-3=none" ] \
  || fail "the association backfill wrote [$assoc]: only the unambiguous intent may be associated"
findings="$(psq -At -c "$AS_OWNER
  select string_agg(r.\"check\" || ':' || r.subject::text, ' ' order by r.subject)
    from public.reconcile_workspace('$WS') r" | tail -1)"
[ "$findings" = "captured_payment_uncredited:00000000-0000-4000-8000-0000000a0302 captured_payment_uncredited:00000000-0000-4000-8000-0000000a0303" ] \
  || fail "the reconciliation reports [$findings], not the two ambiguous intents"
say "0240 associated the one unambiguous intent; the two ambiguous ones stay visible findings"

echo "--- the destructive control"
# A migration that "repairs" the legacy hash. Applied through the same
# path as every real one; the comparison has to catch it.
apply "$CONTROL"
snapshot > report/archive-control.txt
if diff -u report/archive-before.txt report/archive-control.txt > report/archive-control-diff.txt; then
  fail "the destructive control rewrote the legacy signature and the comparison did not notice"
fi
moved="$(grep -c '^[-+]invoice ARC-2' report/archive-control-diff.txt)"
[ "$moved" = 2 ] || fail "the control's diff touches $(grep -c '^[-+][a-z]' report/archive-control-diff.txt) lines, not exactly ARC-2 twice"
v="$(verify)"
case "$v" in
  *"ARC-2=verified"*) say "the control made ARC-2 read verified — exactly the rewrite the comparison refuses" ;;
  *) fail "the control did not do what a destructive migration does: [$v]" ;;
esac

echo "--- the transitions, on the upgraded schema"
psq -q -c "update public.invoices set voided_at = now(), voided_by_name = 'Owner'
  where id = '00000000-0000-4000-8000-0000000a0103'" || fail "voiding ARC-3 was refused"
psq -q -c "update public.invoices set settled_by_invoice_id = '00000000-0000-4000-8000-0000000a0101'
  where id = '00000000-0000-4000-8000-0000000a0102'" || fail "settling ARC-2 was refused"
edit="$(psq -q -c "update public.invoices set total_cents = 1
  where id = '00000000-0000-4000-8000-0000000a0101'" 2>&1)"
case "$edit" in *"invoices are immutable"*) ;; *) fail "an edit of ARC-1's total went through: $edit" ;; esac
del="$(psq -q -c "delete from public.invoices where id = '00000000-0000-4000-8000-0000000a0101'" 2>&1)"
case "$del" in *"invoices are immutable"*) ;; *) fail "a delete of ARC-1 went through: $del" ;; esac
v="$(verify)"
[ "$v" = "ARC-1=verified ARC-2=verified ARC-3=verified" ] \
  || fail "after void and settle the signatures read [$v]: a permitted transition changed a signed field"
say "void and settle accepted, edit and delete refused, signatures untouched by the transitions"

psq -q -c "alter table public.invoices disable trigger user;
  update public.invoices set total_cents = 4999 where id = '00000000-0000-4000-8000-0000000a0101';
  alter table public.invoices enable trigger user" || fail "could not alter ARC-1 behind the guard"
v="$(verify)"
case "$v" in *"ARC-1=altered"*) ;; *) fail "a synthetic alteration of ARC-1 was not detected: [$v]" ;; esac
say "a synthetic alteration behind the guard reads altered"

echo "populated upgrade: $before + $after migrations, the archive unchanged, the control caught ($((SECONDS - started))s)"
