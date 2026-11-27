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
#
# Second case (#3338 row 8): STAGE_AT=0689 carries the SAME archive to the
# schema of 0689 first -- the first with a durable `prepared` e-invoice
# attempt -- seeds the in-flight work of `archive_seed_0689.sql` there (a
# prepared transmission with its stored bytes, an accepted one with its upload
# receipt), and only then runs 0690..latest over it (0694's envelope, 0696 and
# 0697's removal facts all touch `invoice_transmissions`). The snapshot gains
# those rows, the destructive control is applied across them, and their state
# is also asserted against literals, so a change of the seeded pending state is
# a red job, not a quiet before/after agreement.
#
# Third case (#4492 row 6): STOCK_AT=0747 carries the archive to the first
# schema with a goods ledger and seeds the goods of `archive_seed_0747.sql`
# there, through the move command of that schema: a shelf count that opens the
# ledger, cartons of 12 received, a transfer, a sale, litres sold by the glass
# of a fifth, two lots at two costs. Then 0748..latest run over those rows --
# the variants that rebuild the balances' key (0837), the places (0855), the
# units per business, the item units from the master data, the packages and
# the conversions (0951 to 0974). The comparison: every movement, balance, lot,
# item unit and shelf count is the same before and after (quantities compared
# as numbers); the quantities on hand are the literals the seed implies; every
# balance still equals the sum of its movements; `destructive_control_stock.sql`
# (a second conversion of the carton receipt) is named by the diff and breaks
# that sum; and on the upgraded schema a carton received is still 12 pieces and
# a glass taken out still a fifth of a litre. May be combined with STAGE_AT
# (the goods are seeded after it).
set -uo pipefail

BASELINE="${BASELINE:-0226}"
TEMPLATE="${TEMPLATE:-deskilo_lifecycle_empty}"
DB="deskilo_archive"
SEED=supabase/restore/archive_seed.sql
STAGE_AT="${STAGE_AT:-}"
STAGE_SEED="${STAGE_SEED:-supabase/restore/archive_seed_0689.sql}"
STOCK_AT="${STOCK_AT:-}"
STOCK_SEED="${STOCK_SEED:-supabase/restore/archive_seed_0747.sql}"
STOCK_CONTROL=supabase/restore/destructive_control_stock.sql
I_WATER=00000000-0000-4000-8000-0000000a0501
I_WINE=00000000-0000-4000-8000-0000000a0502
TX_PREP=00000000-0000-4000-8000-0000000a0401
TX_ACC=00000000-0000-4000-8000-0000000a0402
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

# Second case: carry the archive to STAGE_AT and seed the in-flight e-invoice
# work there, so the upgrade below starts from a populated schema at that point.
staged=0
upgrade_from="$((10#$BASELINE))"
if [ -n "$STAGE_AT" ]; then
  for f in supabase/migrations/*.sql; do
    v="$(version_of "$f")"
    if [ "$v" -gt "$((10#$BASELINE))" ] && [ "$v" -le "$((10#$STAGE_AT))" ]; then apply "$f"; staged=$((staged + 1)); fi
  done
  [ "$(marker)" = "$((10#$STAGE_AT))" ] || fail "after staging the marker reads '$(marker)', not $((10#$STAGE_AT))"
  apply "$STAGE_SEED"
  upgrade_from="$((10#$STAGE_AT))"
  say "$staged migrations carried the archive to $((10#$STAGE_AT)); in-flight e-invoice work seeded: 1 prepared, 1 accepted with receipt"
fi

# Third case: carry the archive to STOCK_AT and move goods there, so the
# upgrade below runs the later stock migrations over them.
stocked=0
if [ -n "$STOCK_AT" ]; then
  [ "$((10#$STOCK_AT))" -gt "$upgrade_from" ] || fail "STOCK_AT=$STOCK_AT is not after $upgrade_from"
  for f in supabase/migrations/*.sql; do
    v="$(version_of "$f")"
    if [ "$v" -gt "$upgrade_from" ] && [ "$v" -le "$((10#$STOCK_AT))" ]; then apply "$f"; stocked=$((stocked + 1)); fi
  done
  [ "$(marker)" = "$((10#$STOCK_AT))" ] || fail "after carrying to the goods ledger the marker reads '$(marker)', not $((10#$STOCK_AT))"
  apply "$STOCK_SEED"
  upgrade_from="$((10#$STOCK_AT))"
  say "$stocked migrations carried the archive to $((10#$STOCK_AT)); goods moved there: 3 items, 2 item units, 2 lots, 9 commands"
fi

# What the goods are made of, by columns that exist at STOCK_AT; quantities
# as numbers, so a wider scale later is not a difference.
STOCK_SNAPSHOT_SQL="
select 'stock_movement ' || concat_ws(' | ', m.request_id::text, m.line_no::text, m.part::text, m.item_id::text,
         coalesce(l.lot_code, ''), f.code, t.code, trim_scale(m.quantity)::text, trim_scale(m.entered_quantity)::text,
         m.entered_unit, m.occurred_at::text, m.reason, coalesce(trim_scale(m.unit_cost)::text, ''))
  from public.stock_movements m
  join public.stock_locations f on f.id = m.from_location_id
  join public.stock_locations t on t.id = m.to_location_id
  left join public.stock_lots l on l.id = m.lot_id
 where m.workspace_id = '$WS'
union all
select 'stock_balance ' || concat_ws(' | ', b.item_id::text, coalesce(l.lot_code, ''), p.code, trim_scale(b.quantity)::text)
  from public.stock_balances b
  join public.stock_locations p on p.id = b.location_id
  left join public.stock_lots l on l.id = b.lot_id
 where b.workspace_id = '$WS'
union all
select 'stock_lot ' || concat_ws(' | ', l.item_id::text, l.lot_code, l.total_cost_minor::text,
         trim_scale(l.quantity_received)::text, coalesce(l.expires_on::text, ''))
  from public.stock_lots l where l.workspace_id = '$WS'
union all
select 'item_unit ' || concat_ws(' | ', u.item_id::text, u.unit, u.factor_num::text, u.factor_den::text,
         u.default_purchase::text, u.default_sale::text)
  from public.item_units u where u.workspace_id = '$WS'
union all
select 'item ' || concat_ws(' | ', s.id::text, s.name, coalesce(s.stock::text, ''), s.inventory_unit, s.tracking,
         s.stockable::text)
  from public.services s where s.workspace_id = '$WS'
order by 1"
stock_snapshot() { psq -At -c "$STOCK_SNAPSHOT_SQL"; }
# What is on hand at the real places, as the balances say it.
on_hand() {
  psq -At -c "select coalesce(string_agg(s.name || coalesce('/' || l.lot_code, '') || '@' || p.code || '=' || trim_scale(b.quantity)::text,
                                         ' ' order by s.name, l.lot_code, p.code), '')
    from public.stock_balances b
    join public.services s on s.id = b.item_id
    join public.stock_locations p on p.id = b.location_id
    left join public.stock_lots l on l.id = b.lot_id
   where b.workspace_id = '$WS' and p.code in ('MAIN', 'SHELF-A') and b.quantity <> 0"
}
# The balances that are not the sum of their movements.
drifted() {
  psq -At -c "select count(*) from public.stock_balances b
   where b.workspace_id = '$WS'
     and b.quantity <> coalesce((select sum(case when m.to_location_id = b.location_id then m.quantity else -m.quantity end)
                                   from public.stock_movements m
                                  where m.item_id = b.item_id and m.lot_id is not distinct from b.lot_id
                                    and b.location_id in (m.from_location_id, m.to_location_id)), 0)"
}
STOCK_ON_HAND="Juice/A@MAIN=5 Juice/B@MAIN=10 Water@MAIN=19 Water@SHELF-A=7 Wine@MAIN=1.9"

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
# What the staged case adds: the in-flight transmissions and the stored bytes,
# by columns that exist at 0689 and are never rewritten by a later migration.
TX_SNAPSHOT_SQL="
select 'transmission ' || concat_ws(' | ', id::text, invoice_id::text, provider, status,
         phase, external_id, document_hash, detail, sent_at::text, by_name, environment,
         destination, format, coalesce(business_key, ''), coalesce(binding_hash, ''),
         generation::text, coalesce(requested_by::text, ''), md5(verdict::text),
         md5(receipt::text), coalesce(receipt_at::text, ''), query_error)
  from public.invoice_transmissions where workspace_id = '$WS'
union all
select 'artifact ' || concat_ws(' | ', transmission_id::text, sha256, file_name, mime_type,
         receiver_scheme, receiver_id, md5(bytes::text))
  from public.invoice_transmission_artifacts where workspace_id = '$WS'
order by 1"
snapshot() {
  if [ -n "$STAGE_AT" ]; then
    psq -At -c "select * from ($SNAPSHOT_SQL) a union all select * from ($TX_SNAPSHOT_SQL) b order by 1"
  else
    psq -At -c "$SNAPSHOT_SQL"
  fi
}
# The staged case's literals: the pending attempt and the receipt as seeded.
transmissions_state() {
  psq -At -c "select string_agg(id::text || '=' || phase || '/' || status || '/' || generation::text
      || '/' || coalesce(business_key, '') || '/' || binding_hash || '/' || receipt::text, E'\\n' order by id)
    from public.invoice_transmissions where workspace_id = '$WS'"
}

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
want_rows=9; [ -n "$STAGE_AT" ] && want_rows=12
[ "$(grep -c '' report/archive-before.txt)" = "$want_rows" ] || fail "the snapshot has $(grep -c '' report/archive-before.txt) rows, not $want_rows"
v="$(verify)"
[ "$v" = "ARC-1=verified ARC-2=unverifiable ARC-3=verified" ] \
  || fail "before the upgrade the signatures read [$v]: the seed is not what it claims"
say "before: ARC-1 verified, ARC-2 unverifiable, ARC-3 verified"
if [ -n "$STOCK_AT" ]; then
  stock_snapshot > report/stock-before.txt || fail "could not read the goods before the upgrade"
  [ "$(grep -c '^stock_movement ' report/stock-before.txt)" = 10 ] \
    || fail "the goods hold $(grep -c '^stock_movement ' report/stock-before.txt) movements, not the opening and 9 commands"
  [ "$(on_hand)" = "$STOCK_ON_HAND" ] || fail "before the upgrade the goods on hand read [$(on_hand)]: the seed is not what it claims"
  [ "$(drifted)" = 0 ] || fail "before the upgrade $(drifted) balances are not the sum of their movements"
  say "before: $(grep -c '' report/stock-before.txt) facts about the goods; on hand $STOCK_ON_HAND; every balance the sum of its movements"
fi

echo "--- the upgrade"
for f in supabase/migrations/*.sql; do
  if [ "$(version_of "$f")" -gt "$upgrade_from" ]; then apply "$f"; after=$((after + 1)); fi
done
[ "$(marker)" = "$latest" ] || fail "after the upgrade the marker reads '$(marker)', not $latest"
say "$after migrations ran over the populated schema, marker $latest"
if [ -n "$STAGE_AT" ]; then
  # Literals, not a comparison with a snapshot taken after the same seed: a
  # changed seed or a changed migration must turn this red.
  want="$TX_PREP=prepared/failed/0/$WS|00000000-0000-4000-8000-0000000a0101|peppol|government|prod/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/{}
$TX_ACC=accepted/accepted/0/$WS|00000000-0000-4000-8000-0000000a0102|peppol|government|prod/dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd/{\"received\": \"2026-01-15T11:00:00Z\", \"platform_id\": \"EXT-ARC-2\"}"
  got="$(transmissions_state)"
  [ "$got" = "$want" ] || fail "the in-flight e-invoice work changed across 0690..$latest: [$got]"
  [ "$(psq -At -c "select sha256 || '/' || length(bytes)::text from public.invoice_transmission_artifacts where transmission_id = '$TX_PREP'")" = "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee/4" ] \
    || fail "the stored bytes of the prepared attempt changed"
  say "the prepared attempt (with its bytes) and the accepted one (with its receipt) read as seeded after $latest"
fi

snapshot > report/archive-after.txt || fail "could not read the archive after the upgrade"
if ! diff -u report/archive-before.txt report/archive-after.txt > report/archive-diff.txt; then
  cat report/archive-diff.txt
  fail "the upgrade changed the archive — the diff above names what moved"
fi
say "signed fields, hashes, postings and payment relations: byte-equal before and after"
if [ -n "$STOCK_AT" ]; then
  stock_snapshot > report/stock-after.txt || fail "could not read the goods after the upgrade"
  if ! diff -u report/stock-before.txt report/stock-after.txt > report/stock-diff.txt; then
    cat report/stock-diff.txt
    fail "the upgrade changed the goods -- the diff above names what moved"
  fi
  [ "$(on_hand)" = "$STOCK_ON_HAND" ] || fail "after the upgrade the goods on hand read [$(on_hand)]"
  [ "$(drifted)" = 0 ] || fail "after the upgrade $(drifted) balances are not the sum of their movements"
  say "movements, balances, lots, item units and shelf counts: equal before and after; on hand unchanged; every balance still the sum of its movements"
fi

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

if [ -n "$STAGE_AT" ]; then
  # A migration that drops the pending attempt (and, replica mode skipping the
  # cascade, its bytes), blanks the receipt and moves the accepted row's phase. Applied
  # as the platform admin (the user triggers are not what is under test); the
  # comparison has to name exactly those rows.
  asql -d "$DB" -q -v ON_ERROR_STOP=1 -c "set session_replication_role = replica;
    update public.invoice_transmissions set receipt = '{}'::jsonb, receipt_at = null,
      phase = 'uncertain' where id = '$TX_ACC';
    delete from public.invoice_transmission_artifacts where transmission_id = '$TX_PREP';
    delete from public.invoice_transmissions where id = '$TX_PREP'" \
    || fail "could not apply the transmissions control"
  snapshot > report/archive-control-tx.txt
  if diff -u report/archive-before.txt report/archive-control-tx.txt > report/archive-control-tx-diff.txt; then
    fail "the transmissions control dropped the pending attempt and the receipt and the comparison did not notice"
  fi
  grep -q "^-transmission $TX_PREP" report/archive-control-tx-diff.txt \
    && grep -q "^[-+]transmission $TX_ACC" report/archive-control-tx-diff.txt \
    && grep -q "^-artifact $TX_PREP" report/archive-control-tx-diff.txt \
    && grep -q "^+transmission $TX_ACC.* | uncertain | " report/archive-control-tx-diff.txt \
    || fail "the control's diff does not name the pending attempt, its bytes and the receipt"
  say "the control dropped the prepared attempt and blanked the receipt -- exactly what the comparison refuses"
fi

if [ -n "$STOCK_AT" ]; then
  # A unit migration that converts the carton receipt a second time. Applied
  # through the same path; the comparison has to name it, and the sum breaks.
  apply "$STOCK_CONTROL"
  stock_snapshot > report/stock-control.txt
  if diff -u report/stock-before.txt report/stock-control.txt > report/stock-control-diff.txt; then
    fail "the stock control converted a movement twice and the comparison did not notice"
  fi
  moved="$(grep -c '^[-+]stock_movement 00000000-0000-4000-8000-0000000a0601 ' report/stock-control-diff.txt)"
  [ "$moved" = 2 ] && [ "$(grep -c '^[-+][a-z]' report/stock-control-diff.txt)" = 2 ] \
    || fail "the stock control's diff touches $(grep -c '^[-+][a-z]' report/stock-control-diff.txt) lines, not exactly the carton receipt twice"
  [ "$(drifted)" != 0 ] || fail "after the stock control every balance still equals its movements: the sum proves nothing"
  say "the control converted the carton receipt twice -- the diff names it and $(drifted) balances no longer add up"
  # Put back, so the commands below start from the goods as upgraded.
  psq -q -c "alter table public.stock_movements disable trigger user;
    update public.stock_movements set quantity = quantity / 12
     where workspace_id = '$WS' and request_id = '00000000-0000-4000-8000-0000000a0601';
    alter table public.stock_movements enable trigger user" || fail "could not take the stock control back"
  [ "$(drifted)" = 0 ] || fail "the stock control was not taken back cleanly"

  echo "--- the units, on the upgraded schema"
  # As the owner, through today's command, on the items and units of 0747: a
  # carton received is 12 pieces, a glass taken out a fifth of a litre.
  psq -q -c "update public.workspaces set feature_flags = feature_flags || '{\"stockTakeOut\": true}'::jsonb where id = '$WS'" \
    || fail "could not switch the take-out on"
  loc() { psq -At -c "select id from public.stock_locations where workspace_id = '$WS' and code = '$1'"; }
  move() { # <request> <lines json> <reason>
    psq -At -c "$AS_OWNER
      select public.stock_move_v1('$WS', '$1', '$2'::jsonb, '$3')" 2>&1
  }
  got="$(move 00000000-0000-4000-8000-0000000a0611 "[{\"item_id\": \"$I_WATER\", \"quantity\": 1, \"from\": \"$(loc SUPPLIER)\", \"to\": \"$(loc MAIN)\", \"unit\": \"carton\"}]" receipt)"
  case "$got" in *ERROR*|"") fail "a carton of the 0747 item is not received on the upgraded schema: $(printf '%s' "$got" | grep -m1 ERROR)" ;; esac
  got="$(move 00000000-0000-4000-8000-0000000a0612 "[{\"item_id\": \"$I_WINE\", \"quantity\": 3, \"from\": \"$(loc MAIN)\", \"to\": \"$(loc LOSS)\", \"unit\": \"glass\"}]" consumption)"
  case "$got" in *ERROR*|"") fail "three glasses of the 0747 item are not taken out on the upgraded schema: $(printf '%s' "$got" | grep -m1 ERROR)" ;; esac
  want="Juice/A@MAIN=5 Juice/B@MAIN=10 Water@MAIN=31 Water@SHELF-A=7 Wine@MAIN=1.3"
  [ "$(on_hand)" = "$want" ] || fail "after a carton in and three glasses out the goods on hand read [$(on_hand)], not [$want]"
  [ "$(drifted)" = 0 ] || fail "after the new movements $(drifted) balances are not the sum of their movements"
  say "a carton received is 12 more pieces (19 to 31), three glasses out are 0.6 litre less (1.9 to 1.3); the balances add up"
fi

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

echo "populated upgrade${STAGE_AT:+ (staged at $STAGE_AT)}${STOCK_AT:+ (goods at $STOCK_AT)}: $before + $staged + $stocked + $after migrations, the archive unchanged, the control caught ($((SECONDS - started))s)"
