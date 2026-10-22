-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2587 / 0533: the fiscal source carries the purchase side in the same
-- snapshot. An approved bill of 10 March with two lines is in March's
-- source with its lines and totals; a bill still waiting for a decision and
-- a bill dated in April are not; the totals are the rows'.
begin;
select plan(7);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000025870'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@source.test','',now(),now(),now()
  from unnest(array['a1','a3']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags) values
 ('00000000-0000-4000-8000-0000025870b1','Source','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000025870a1','dev',
  '{"moneyTab":true,"invoicing":true,"purchases":true,"supplyExpenses":true,"inputVat":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000025870c1','00000000-0000-4000-8000-0000025870b1','00000000-0000-4000-8000-0000025870a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000025870c3','00000000-0000-4000-8000-0000025870b1','00000000-0000-4000-8000-0000025870a3',false,true,'active');
insert into public.suppliers (id, workspace_id, supplier_number, name, status) values
 ('00000000-0000-4000-8000-0000025870f1','00000000-0000-4000-8000-0000025870b1','1','Fournitures SA','active');

create function pg_temp.call(p_user uuid, p_sql text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute p_sql into v;
  return v;
end;
$$;
create function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000025870' || p)::uuid;
$$;
create function pg_temp.line(p_what text, p_net int, p_tax int) returns jsonb language sql as $$
  select jsonb_build_object('description', p_what, 'gross_cents', p_net + p_tax, 'net_cents', p_net,
    'tax_cents', p_tax, 'tax_rate_percent', case when p_tax = 0 then 0 else 20 end,
    'recoverable_tax_cents', p_tax, 'nonrecoverable_tax_cents', 0, 'recognition_kind', 'operating');
$$;
-- A bill dated p_date with two lines; submitted, and approved by a second
-- admin when p_approve.
create function pg_temp.bill(p_ref text, p_date text, p_approve boolean) returns uuid language plpgsql as $$
declare v uuid;
begin
  v := (pg_temp.call(pg_temp.u('a1'),
    format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', pg_temp.u('b1'), gen_random_uuid(),
      jsonb_build_object('kind', 'bill', 'supplier_id', pg_temp.u('f1'), 'original_reference', p_ref,
        'original_date', p_date, 'due_on', '2026-05-31', 'payer_kind', 'unpaid',
        'lines', jsonb_build_array(pg_temp.line('Cleaning', 100, 20), pg_temp.line('Paper', 50, 10)))::text))
    ->> 'purchase_id')::uuid;
  perform pg_temp.call(pg_temp.u('a1'),
    format('select public.submit_purchase_v1(%L, %L, 1, %L)', pg_temp.u('b1'), v, gen_random_uuid()));
  if p_approve then
    perform pg_temp.call(pg_temp.u('a3'),
      format('select public.decide_purchase_v1(%L, %L, %s, true, %L, %L)', pg_temp.u('b1'), v,
        (select revision from public.purchase_documents where id = v), '', gen_random_uuid()));
  end if;
  return v;
end;
$$;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000025870a1","role":"authenticated"}',true);
set local role authenticated;

select set_config('t.march', pg_temp.bill('F-1', '2026-03-10', true)::text, true);
select pg_temp.bill('F-2', '2026-03-12', false);
select pg_temp.bill('F-3', '2026-04-02', true);
select set_config('t.src', pg_temp.call(pg_temp.u('a1'),
  format('select public.accounting_source_snapshot_v1(%L, %L, %L)', pg_temp.u('b1'), '2026-03-01', '2026-03-31'))::text, true);

select is(current_setting('t.src')::jsonb ->> 'status', 'ok', 'the source answers');
select is(jsonb_array_length(current_setting('t.src')::jsonb -> 'purchases'), 1,
  'only the approved bill dated in March: not the one waiting, not April''s');
select is(current_setting('t.src')::jsonb -> 'purchases' -> 0 ->> 'id', current_setting('t.march'),
  'and it is that bill');
select is(jsonb_array_length(current_setting('t.src')::jsonb -> 'purchases' -> 0 -> 'lines'), 2,
  'with its two lines');
select is(current_setting('t.src')::jsonb -> 'totals' -> 'purchases',
  '{"count": 1, "line_count": 2, "gross_cents": 180}'::jsonb,
  'the totals are the rows: one document, two lines, 1.20 + 0.60');
select is((current_setting('t.src')::jsonb -> 'purchases' -> 0 -> 'lines' -> 0 ->> 'line_no')::int, 1,
  'the lines in their order');
select ok(current_setting('t.src')::jsonb ? 'book_profiles' and current_setting('t.src')::jsonb ? 'ledger',
  'every key version 1 had is still there');

select * from finish();
rollback;
