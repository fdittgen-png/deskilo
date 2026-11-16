-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3556 (part 2, 0801) — a person's own groups of invoices: read and written
-- by their owner only, never by another account, an assistant's delegated
-- session or an anonymous caller; a name is trimmed, at most 80 characters
-- and used once per person; an invoice is named by its installation-
-- qualified workspace and its id, so two installations' equal local ids
-- stay two invoices; no amount is stored; the personal export carries the
-- groups; deleting a group deletes its references, deleting the account
-- deletes the groups.
begin;
select plan(22);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000003556'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@groups.test','',now(),now(),now()
  from unnest(array['a1','a2']) suffix;

create function pg_temp.act(p_user text, p_extra jsonb default '{}') returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    (json_build_object('sub','00000000-0000-4000-8000-0000003556'||p_user,'role','authenticated')::jsonb || p_extra)::text, true);
end $$;
create function pg_temp.refusal_code(p_sql text) returns text language plpgsql as $$
begin execute p_sql; return null; exception when others then return sqlstate; end $$;
create function pg_temp.rows_of(p_sql text) returns int language plpgsql as $$
declare v int; begin execute p_sql; get diagnostics v = row_count; return v; end $$;
grant execute on all functions in schema pg_temp to authenticated;

-- two installations, one workspace id and one invoice id on each
select set_config('t.ref1', '11111111-1111-4111-8111-111111111111:22222222-2222-4222-8222-222222222222', true);
select set_config('t.ref2', '33333333-3333-4333-8333-333333333333:22222222-2222-4222-8222-222222222222', true);
select set_config('t.inv', '44444444-4444-4444-8444-444444444444', true);

-- ── the owner files invoices ─────────────────────────────────────────────
select pg_temp.act('a1');
set local role authenticated;
select lives_ok($$insert into public.personal_invoice_groups (name) values ('Taxes 2026')$$,
  'a person creates a group');
select set_config('t.g1', (select id::text from public.personal_invoice_groups where name = 'Taxes 2026'), true);
select is(pg_temp.refusal_code($$insert into public.personal_invoice_groups (name) values (repeat('x', 81))$$),
  '23514', 'a name longer than 80 characters is refused');
select is(pg_temp.refusal_code($$insert into public.personal_invoice_groups (name) values (' Spaced ')$$),
  '23514', 'a name is stored trimmed');
select is(pg_temp.refusal_code($$insert into public.personal_invoice_groups (name) values ('')$$),
  '23514', 'an empty name is refused');
select is(pg_temp.refusal_code($$insert into public.personal_invoice_groups (name) values ('taxes 2026')$$),
  '23505', 'a name is used once per person, whatever its case');
select lives_ok(format($$insert into public.personal_invoice_group_items (group_id, network_id, invoice_id, label)
  values (%L, %L, %L, 'F-2026-001'), (%L, %L, %L, 'R-17')$$,
  current_setting('t.g1'), current_setting('t.ref1'), current_setting('t.inv'),
  current_setting('t.g1'), current_setting('t.ref2'), current_setting('t.inv')),
  'two installations'' invoices with the same local ids are filed');
select is((select count(*)::int from public.personal_invoice_group_items where group_id = current_setting('t.g1')::uuid),
  2, 'and stay two references');
select is(pg_temp.refusal_code(format($$insert into public.personal_invoice_group_items (group_id, network_id, invoice_id)
  values (%L, %L, %L)$$, current_setting('t.g1'), current_setting('t.ref1'), current_setting('t.inv'))),
  '23505', 'an invoice is in a group once');
select is(pg_temp.refusal_code(format($$insert into public.personal_invoice_group_items (group_id, network_id, invoice_id)
  values (%L, 'not-a-reference', %L)$$, current_setting('t.g1'), current_setting('t.inv'))),
  '23514', 'a reference names an installation and a workspace');
select is(pg_temp.refusal_code(format($$insert into public.personal_invoice_group_items (group_id, network_id, invoice_id, label)
  values (%L, %L, gen_random_uuid(), repeat('n', 81))$$, current_setting('t.g1'), current_setting('t.ref1'))),
  '23514', 'a number as last seen is at most 80 characters');
reset role;

-- ── another account sees and changes nothing of it ───────────────────────
select pg_temp.act('a2');
set local role authenticated;
select is((select count(*)::int from public.personal_invoice_groups)
          + (select count(*)::int from public.personal_invoice_group_items),
  0, 'another account reads none of the groups or their invoices');
select is(pg_temp.refusal_code(format($$insert into public.personal_invoice_group_items (group_id, network_id, invoice_id)
  values (%L, %L, gen_random_uuid())$$, current_setting('t.g1'), current_setting('t.ref1'))),
  '23503', 'another account cannot file an invoice in it');
select is(pg_temp.refusal_code(format($$insert into public.personal_invoice_group_items (group_id, user_id, network_id, invoice_id)
  values (%L, '00000000-0000-4000-8000-0000003556a1', %L, gen_random_uuid())$$, current_setting('t.g1'), current_setting('t.ref1'))),
  '42501', 'nor in its owner''s name');
select is(pg_temp.rows_of(format($$update public.personal_invoice_groups set name = 'Mine now' where id = %L$$, current_setting('t.g1')))
          + pg_temp.rows_of(format($$delete from public.personal_invoice_groups where id = %L$$, current_setting('t.g1')))
          + pg_temp.rows_of(format($$delete from public.personal_invoice_group_items where group_id = %L$$, current_setting('t.g1'))),
  0, 'nor rename, delete or empty it');
select is(jsonb_array_length(public.export_my_personal_data_v1() -> 'invoice_groups'), 0,
  'another account''s export carries none of them');
reset role;

-- ── an assistant's delegated session, an anonymous caller: nothing ──────
select pg_temp.act('a1', '{"client_id": "assistant"}');
set local role authenticated;
select is((select count(*)::int from public.personal_invoice_groups), 0,
  'a delegated assistant session reads no group');
reset role;
select ok(not has_table_privilege('anon', 'public.personal_invoice_groups', 'select')
          and not has_table_privilege('anon', 'public.personal_invoice_group_items', 'select'),
  'an anonymous caller cannot read them');

-- ── the owner renames, removes an invoice, exports ──────────────────────
select pg_temp.act('a1');
set local role authenticated;
select is(pg_temp.rows_of(format($$update public.personal_invoice_groups set name = 'To reimburse' where id = %L$$, current_setting('t.g1'))),
  1, 'the owner renames the group');
select is(pg_temp.rows_of(format($$delete from public.personal_invoice_group_items where group_id = %L and network_id = %L and invoice_id = %L$$,
  current_setting('t.g1'), current_setting('t.ref2'), current_setting('t.inv'))),
  1, 'and removes one invoice from it');
select is((select g ->> 'name' || ':' || (g -> 'invoices' -> 0 ->> 'number') || ':' || jsonb_array_length(g -> 'invoices')
             from jsonb_array_elements(public.export_my_personal_data_v1() -> 'invoice_groups') g),
  'To reimburse:F-2026-001:1', 'the personal export carries the group and its invoices, by reference and number');
select set_config('t.deleted',
  pg_temp.rows_of(format($$delete from public.personal_invoice_groups where id = %L$$, current_setting('t.g1')))::text, true);
select is(current_setting('t.deleted')::int * 10 + (select count(*)::int from public.personal_invoice_group_items),
  10, 'deleting the group deletes its references, nothing else');
reset role;

-- ── deleting the account deletes the groups ─────────────────────────────
insert into public.personal_invoice_groups (user_id, name)
values ('00000000-0000-4000-8000-0000003556a1', 'Kept until the account goes');
delete from auth.users where id = '00000000-0000-4000-8000-0000003556a1';
select is((select count(*)::int from public.personal_invoice_groups
            where user_id = '00000000-0000-4000-8000-0000003556a1'),
  0, 'deleting the account deletes its groups');

select * from finish();
rollback;
