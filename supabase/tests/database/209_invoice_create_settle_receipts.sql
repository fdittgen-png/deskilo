-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2585 / 0464 (C2): the batch issue and the settlement carry an exact request
-- identity too.
-- Real roles (authenticated through the definer RPCs); every refusal is
-- followed by a readback. Expected values are written here from the seed
-- (35.00 fee + 10.00 supply = 4500), not read from the function under test.
--   A batch issue: one invoice per id, the replay answers the original id
--   B the same id with another period / kind is refused; a new id on an
--     invoiced month is refused and records nothing
--   C settlement: the replay answers the same settlement, in any id order
--   D the same id with another note or another set is refused
--   E the outcome read names the made invoice
-- NOT RUN here: two synchronized sessions on one id.
begin;
select plan(14);

create function pg_temp.as_err(p_user uuid, p_sql text) returns text
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql;
  reset role;
  return '';
exception when others then
  reset role;
  return sqlerrm;
end;
$$;

do $seed$
declare
  uo uuid := '00000000-0000-4000-8000-000000258531';
  um uuid := '00000000-0000-4000-8000-000000258532';
  us uuid := '00000000-0000-4000-8000-000000258533';
  ws uuid; mm uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner@batch2585.test','',now(),now(),now()),
          (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','member@batch2585.test','',now(),now(),now()),
          (us,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','stranger@batch2585.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,
                                vat_regime,vat_id,feature_flags)
   values ('Receipt batch 2585','FR','EUR','Europe/Paris',uo,'1 rue du Pilote','Pézenas','34120',
           'vat_registered','FR12345678901','{"invoicing":true,"numberSequences":true,"invoiceSettlement":true}')
   returning id into ws;
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at) values (ws,uo,true,true,'2026-01-01');
  insert into public.members(workspace_id,user_id,subscription_pct,joined_at,customer_capacity)
   values (ws,um,1,'2026-01-01','consumer') returning id into mm;
  insert into public.vat_rates(workspace_id,label,percent,is_default) values (ws,'Synthetic standard',20,true);
  delete from public.fee_bands where workspace_id = ws;
  insert into public.fee_bands(workspace_id,from_pct,to_pct,fee_cents,overage_fee_cents) values (ws,0,100,3500,1000);
  update public.profiles set first_name='Synthetic',last_name='Client',country_code='FR',
         street='2 rue du Test',city='Pézenas',postal_code='34120'
   where id = um;
  insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period,vat_percent)
   values (ws,mm,'charge','adjustment',1000,'Supply','2026-09',20),
          (ws,mm,'charge','adjustment',500,'Supply','2026-08',20);
  -- July: more received than supplied, a credit note of 3500 - 5000 = -1500.
  insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period)
   values (ws,mm,'credit','payment',5000,'Advance','2026-07');
  -- A stranger owns another workspace.
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,feature_flags)
   values ('Stranger batch 2585','FR','EUR','Europe/Paris',us,'{"invoicing":true}');
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at)
   select id,us,true,true,'2026-01-01' from public.workspaces where name = 'Stranger batch 2585';
  perform set_config('deskilo.r.ws', ws::text, false);
  perform set_config('deskilo.r.m', mm::text, false);
end;
$seed$;



create function pg_temp.act_owner() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub','00000000-0000-4000-8000-000000258531','role','authenticated')::text, true);
end;
$$;

set local role authenticated;
select pg_temp.act_owner();
select set_config('deskilo.v.sep', public.create_invoice_receipted_v1(current_setting('deskilo.r.ws')::uuid, current_setting('deskilo.r.m')::uuid, '2026-09', '00000000-0000-4000-8000-0000002585a1')::text, false);
select set_config('deskilo.v.sep2', public.create_invoice_receipted_v1(current_setting('deskilo.r.ws')::uuid, current_setting('deskilo.r.m')::uuid, '2026-09', '00000000-0000-4000-8000-0000002585a1')::text, false);
select set_config('deskilo.v.aug', public.create_invoice_receipted_v1(current_setting('deskilo.r.ws')::uuid, current_setting('deskilo.r.m')::uuid, '2026-08', '00000000-0000-4000-8000-0000002585a2')::text, false);
reset role;

-- ── A: one invoice per id ─────────────────────────────────────────────
select is((select count(*)::int from public.invoices where member_id = current_setting('deskilo.r.m')::uuid and period = '2026-09'), 1, 'one September invoice');
select is(current_setting('deskilo.v.sep2'), current_setting('deskilo.v.sep'), 'the replay answers the ORIGINAL id (not "already invoiced")');
select is((select total_cents from public.invoices where id = current_setting('deskilo.v.sep')::uuid), 4500, 'it carries the seeded amount');
select is((select count(*)::int from public.financial_command_receipts where workspace_id = current_setting('deskilo.r.ws')::uuid), 2, 'one receipt per id');

-- ── B: conflicts and refusals ─────────────────────────────────────────
select matches(pg_temp.as_err('00000000-0000-4000-8000-000000258531',
  $$select public.create_invoice_receipted_v1(current_setting('deskilo.r.ws')::uuid, current_setting('deskilo.r.m')::uuid, '2026-08', '00000000-0000-4000-8000-0000002585a1')$$),
  'request conflict', 'the same id with another period is refused');
select matches(pg_temp.as_err('00000000-0000-4000-8000-000000258531',
  $$select public.create_invoice_receipted_v1(current_setting('deskilo.r.ws')::uuid, current_setting('deskilo.r.m')::uuid, '2026-09', '00000000-0000-4000-8000-0000002585b9')$$),
  'already invoiced', 'a new id on an invoiced month is refused');
select is((select count(*)::int from public.financial_command_receipts where request_id = '00000000-0000-4000-8000-0000002585b9'), 0, 'with no receipt');

-- ── C: settlement ─────────────────────────────────────────────────────
set local role authenticated;
select pg_temp.act_owner();
select set_config('deskilo.v.set1', public.settle_invoices_v1(current_setting('deskilo.r.ws')::uuid, current_setting('deskilo.r.m')::uuid,
  array[current_setting('deskilo.v.aug')::uuid, current_setting('deskilo.v.sep')::uuid], '00000000-0000-4000-8000-0000002585c1', 'quarter')::text, false);
select set_config('deskilo.v.set2', public.settle_invoices_v1(current_setting('deskilo.r.ws')::uuid, current_setting('deskilo.r.m')::uuid,
  array[current_setting('deskilo.v.sep')::uuid, current_setting('deskilo.v.aug')::uuid], '00000000-0000-4000-8000-0000002585c1', 'quarter')::text, false);
reset role;
select is(current_setting('deskilo.v.set2'), current_setting('deskilo.v.set1'), 'the settlement replays in any id order');
select is((select count(*)::int from public.invoices where kind = 'settlement' and member_id = current_setting('deskilo.r.m')::uuid), 1, 'one settlement document');

-- ── D: changed payload ────────────────────────────────────────────────
select matches(pg_temp.as_err('00000000-0000-4000-8000-000000258531',
  $$select public.settle_invoices_v1(current_setting('deskilo.r.ws')::uuid, current_setting('deskilo.r.m')::uuid,
     array[current_setting('deskilo.v.aug')::uuid, current_setting('deskilo.v.sep')::uuid], '00000000-0000-4000-8000-0000002585c1', 'another note')$$),
  'request conflict', 'the same id with another note is refused');
select matches(pg_temp.as_err('00000000-0000-4000-8000-000000258531',
  $$select public.settle_invoices_v1(current_setting('deskilo.r.ws')::uuid, current_setting('deskilo.r.m')::uuid,
     array[current_setting('deskilo.v.aug')::uuid], '00000000-0000-4000-8000-0000002585c1', 'quarter')$$),
  'request conflict', 'and with another set of invoices');

-- ── E: the outcome read ───────────────────────────────────────────────
set local role authenticated;
select pg_temp.act_owner();
select set_config('deskilo.v.out', public.financial_command_outcome_v1(current_setting('deskilo.r.ws')::uuid, '00000000-0000-4000-8000-0000002585c1')::text, false);
reset role;
select is((current_setting('deskilo.v.out')::jsonb)->>'invoice_id', current_setting('deskilo.v.set1'), 'the outcome names the settlement document');
select is((current_setting('deskilo.v.out')::jsonb)->>'command_kind', 'settle_invoices', 'and its kind');
select isnt(pg_temp.as_err('00000000-0000-4000-8000-000000258533',
  $$select public.settle_invoices_v1(current_setting('deskilo.r.ws')::uuid, current_setting('deskilo.r.m')::uuid,
     array[current_setting('deskilo.v.aug')::uuid, current_setting('deskilo.v.sep')::uuid], '00000000-0000-4000-8000-0000002585c9')$$), '',
  'a stranger of another workspace is refused');

select * from finish();
rollback;
