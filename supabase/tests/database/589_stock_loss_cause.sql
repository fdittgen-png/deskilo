-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4492 (row 11, D3): a loss says why. Goods are written off with a cause from the fixed list and, when the person
-- writes one, a note; both are kept on the movement and read back with it. Proven here: the loss command keeps the cause
-- and the trimmed note, at the lot's cost as before; a loss without a cause, with a cause that is not on the list (own
-- use among them: goods the business uses are not a loss) or with a note too long is refused and nothing moves; a person
-- who may not move stock writes nothing off; sent again the command answers once, and sent again with another cause it
-- is refused and the movement keeps what it said; the table itself refuses a cause that is not on the list, a note
-- without a cause and a cause on a movement that is not a loss; an app of the last release still writes a loss off,
-- without a cause, and goods used by the business carry none. Rolled back.
begin;
select plan(17);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
    set constraints all immediate;
    set constraints all deferred;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || d, '');
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
create or replace function pg_temp.sqlstate_of(p_sql text) returns text language plpgsql as $f$
begin execute p_sql; return 'none'; exception when others then return sqlstate; end
$f$;
create or replace function pg_temp.loc(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = p_code
$f$;
create or replace function pg_temp.place(p_kind text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = p_kind order by created_datetime limit 1
$f$;
create or replace function pg_temp.bal(p_item int) returns text language sql stable as $f$
  select trim_scale(coalesce(sum(quantity), 0))::text from public.stock_balances
   where workspace_id = pg_temp.u(101) and item_id = pg_temp.u(p_item) and location_id = pg_temp.loc('MAIN')
$f$;
create or replace function pg_temp.losses() returns text language sql stable as $f$
  select count(*)::text from public.stock_movements where workspace_id = pg_temp.u(101) and reason = 'loss'
$f$;
-- one line of goods taken from the main store
create or replace function pg_temp.line(p_item int, p_qty text, p_lot uuid default null) returns text language sql stable as $f$
  select jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('item_id', pg_temp.u(p_item), 'quantity', p_qty, 'from', pg_temp.loc('MAIN'), 'lot_id', p_lot)))::text
$f$;
-- the loss command as the app of today calls it
create or replace function pg_temp.lose(p_user int, p_req int, p_lines text, p_cause text, p_note text default null) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_loss_v2(%L, %L, %L::jsonb, %L, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_lines, p_cause, p_note))
$f$;
-- the cause and the note the movements of a request keep
create or replace function pg_temp.said(p_req int) returns text language sql stable as $f$
  select coalesce(string_agg(coalesce(m.loss_cause, 'no cause') || '|' || coalesce(m.loss_note, 'no note'), ' ' order by m.line_no, m.part), 'no movement')
    from public.stock_movements m where m.workspace_id = pg_temp.u(101) and m.request_id = pg_temp.u(p_req)
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'loss-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 2) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Loss causes', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "stockManagement": true, "stockLots": true, "stockReceiving": true, "stockTakeOut": true}', '{"member": []}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Apples', 50, true, 'piece', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Milk', 120, true, 'piece', 'expiry', true);
-- ten apples and five bottles of milk (5.00 for the lot) arrive in the main store
do $setup$
declare v text;
begin
  v := pg_temp.run_as(pg_temp.u(1), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(9001),
    format('[{"item_id": "%s", "quantity": "10", "from": "%s", "to": "%s"},
             {"item_id": "%s", "quantity": "5", "from": "%s", "to": "%s", "new_lot": {"code": "M-1", "expires_on": "%s", "total_cost_minor": 500}}]',
      pg_temp.u(301), pg_temp.place('supplier'), pg_temp.loc('MAIN'),
      pg_temp.u(302), pg_temp.place('supplier'), pg_temp.loc('MAIN'), to_char(public.workspace_today(pg_temp.u(101)) + 3, 'YYYY-MM-DD')), 'receipt'));
  if v like 'ERR%' then raise exception 'the goods did not arrive: %', v; end if;
end
$setup$;

-- ── a loss keeps why ─────────────────────────────────────────────────────────────────────────────────────────────────────
select is(left(pg_temp.lose(1, 9101, pg_temp.line(301, '1'), 'damaged', '  fell off the shelf  '), 1) || ' ' || pg_temp.said(9101) || ' ' || pg_temp.bal(301),
  '{ damaged|fell off the shelf 9', 'an apple written off as damaged keeps its cause and its note, trimmed, and leaves the store');
select is(left(pg_temp.lose(1, 9102, pg_temp.line(302, '2', (select id from public.stock_lots where workspace_id = pg_temp.u(101) and lot_code = 'M-1')), 'expired'), 1)
    || ' ' || pg_temp.said(9102) || ' ' || (select round(sum(m.quantity * m.unit_cost))::text from public.stock_movements m where m.request_id = pg_temp.u(9102)),
  '{ expired|no note 200', 'two bottles written off as past their date: no note is asked, and the loss is frozen at the lot''s cost as before');
select is((select string_agg(coalesce(r ->> 'loss_cause', '-') || ':' || coalesce(r ->> 'loss_note', '-'), ' ' order by r ->> 'reason', r ->> 'loss_cause')
             from jsonb_array_elements((pg_temp.run_as(pg_temp.u(1), format('select public.stock_movements_page_v1(%L)::text', pg_temp.u(101))))::jsonb -> 'rows') r),
  'damaged:fell off the shelf expired:- -:- -:-', 'the ledger reads each movement with the cause and the note of its loss; a receipt has none');

-- ── a loss that does not say why, or says something the list does not know, is refused and nothing moves ────────────────────
select is(pg_temp.lose(1, 9111, pg_temp.line(301, '1'), null), 'ERR DKG11 {"field": "cause", "reason": "required"}', 'a loss without a cause is refused');
select is(pg_temp.lose(1, 9112, pg_temp.line(301, '1'), '   '), 'ERR DKG11 {"field": "cause", "reason": "required"}', 'and so is one whose cause is blank');
select is(pg_temp.lose(1, 9113, pg_temp.line(301, '1'), 'stolen'), 'ERR DKG11 {"field": "cause", "reason": "malformed"}', 'a cause that is not on the list is refused');
select is(pg_temp.lose(1, 9114, pg_temp.line(301, '1'), 'own_use'), 'ERR DKG11 {"field": "cause", "reason": "malformed"}',
  'goods the business uses itself are not a loss: they leave as a consumption');
select is(pg_temp.lose(1, 9115, pg_temp.line(301, '1'), 'other', repeat('x', 501)), 'ERR DKG11 {"field": "note", "reason": "too_long"}', 'a note beyond 500 characters is refused');
select is(left(pg_temp.lose(2, 9116, pg_temp.line(301, '1'), 'damaged'), 9), 'ERR DKN01', 'a person who may not move stock writes nothing off');
select is(pg_temp.bal(301) || ' ' || pg_temp.losses(), '9 2', 'none of the refused losses moved anything: nine apples, two losses');
-- recovery: the refused loss, filed again with its cause
select is(left(pg_temp.lose(1, 9111, pg_temp.line(301, '1'), 'other', repeat('x', 500)), 1) || ' ' || char_length((select loss_note from public.stock_movements where request_id = pg_temp.u(9111)))::text
    || ' ' || pg_temp.bal(301), '{ 500 8', 'filed again with a cause, and a note of exactly 500 characters, the loss is taken');

-- ── once is once, and a movement keeps what it said ──────────────────────────────────────────────────────────────────────────
select is(left(pg_temp.lose(1, 9101, pg_temp.line(301, '1'), 'damaged', '  fell off the shelf  '), 1) || ' ' || pg_temp.bal(301) || ' ' || pg_temp.losses(), '{ 8 3',
  'the first loss sent again answers and moves nothing more');
select is(left(pg_temp.lose(1, 9101, pg_temp.line(301, '1'), 'missing', 'fell off the shelf'), 4) || ' ' || pg_temp.said(9101) || ' ' || pg_temp.bal(301), 'ERR  damaged|fell off the shelf 8',
  'sent again with another cause it is not the same request: refused, and the movement keeps the cause it was written with');
select is(pg_temp.sqlstate_of(format('update public.stock_movements set loss_cause = %L where request_id = %L', 'missing', pg_temp.u(9101))) <> 'none', true,
  'a movement is never edited: its cause cannot be changed afterwards');

-- ── the table keeps the rule whatever door is used ───────────────────────────────────────────────────────────────────────────
select is(pg_temp.sqlstate_of(format('select public.stock_record(%L, %L, null, %L, %L, 1, %L, 1, now(), %L, %L, %L, 1, 1, %L::jsonb)',
      pg_temp.u(101), pg_temp.u(301), pg_temp.loc('MAIN'), pg_temp.place('loss'), 'piece', 'loss', pg_temp.u(201), pg_temp.u(9201), '{"loss_cause": "stolen"}'))
    || ' ' || pg_temp.sqlstate_of(format('select public.stock_record(%L, %L, null, %L, %L, 1, %L, 1, now(), %L, %L, %L, 1, 1, %L::jsonb)',
      pg_temp.u(101), pg_temp.u(301), pg_temp.loc('MAIN'), pg_temp.place('loss'), 'piece', 'loss', pg_temp.u(201), pg_temp.u(9202), '{"loss_note": "no cause beside it"}'))
    || ' ' || (select bool_and(convalidated)::text from pg_constraint where conname in ('stock_movements_loss_cause_check', 'stock_movements_loss_note_check')),
  '23514 23514 true', 'the table refuses a cause that is not on the list and a note without a cause, even from the server''s own writer');

-- ── an app of the last release, and goods the business uses ──────────────────────────────────────────────────────────────────
select is(left(pg_temp.run_as(pg_temp.u(1), format('select public.stock_loss_v1(%L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(9301), pg_temp.line(301, '1'))), 1)
    || ' ' || pg_temp.said(9301) || ' ' || pg_temp.bal(301), '{ no cause|no note 7', 'the loss command of the last release still writes a loss off: it has no cause, and none is guessed');
select is(left(pg_temp.run_as(pg_temp.u(1), format('select public.stock_consume_v1(%L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(9302), pg_temp.line(301, '2'))), 1)
    || ' ' || pg_temp.said(9302) || ' ' || (select string_agg(distinct reason, ',') from public.stock_movements where request_id = pg_temp.u(9302)) || ' '
    || has_function_privilege('anon', 'public.stock_loss_v2(uuid, uuid, jsonb, text, text, timestamptz)', 'execute')::text || ' '
    || has_function_privilege('authenticated', 'public.stock_take_out(uuid, uuid, jsonb, text, timestamptz, jsonb)', 'execute')::text,
  '{ no cause|no note consumption false false', 'goods the business uses leave as a consumption and carry no cause; nobody signed out calls the loss command, and the inner door stays the server''s');

select * from finish();
rollback;
