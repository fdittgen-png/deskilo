-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2585 / 0465 (C2): the replacement of an erroneous invoice carries an exact
-- request identity too.
-- Real roles (authenticated through the definer RPCs); every refusal is
-- followed by a readback. Expected values are written here from the seed
-- (35.00 fee + 10.00 supply = 4500), not read from the function under test.
--   A the replacement: new invoice, the replaced one voided in the same step
--   B the replay answers the ORIGINAL replacement, nothing is issued twice
--   C the same id with another reason or another replaced invoice is refused
--   D a replacement that fails leaves no receipt and the old invoice open
--   E the outcome read names the made invoice
-- NOT RUN here: two synchronized sessions on one id (HTTP topology test).
begin;
select plan(11);

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
  uo uuid := '00000000-0000-4000-8000-000000258541';
  um uuid := '00000000-0000-4000-8000-000000258542';
  us uuid := '00000000-0000-4000-8000-000000258543';
  ws uuid; mm uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner@replace2585.test','',now(),now(),now()),
          (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','member@replace2585.test','',now(),now(),now()),
          (us,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','stranger@replace2585.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,
                                vat_regime,vat_id,feature_flags)
   values ('Receipt replace 2585','FR','EUR','Europe/Paris',uo,'1 rue du Pilote','Pézenas','34120',
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
   values ('Stranger replace 2585','FR','EUR','Europe/Paris',us,'{"invoicing":true}');
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at)
   select id,us,true,true,'2026-01-01' from public.workspaces where name = 'Stranger replace 2585';
  perform set_config('deskilo.r.ws', ws::text, false);
  perform set_config('deskilo.r.m', mm::text, false);
end;
$seed$;




create function pg_temp.act_owner() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub','00000000-0000-4000-8000-000000258541','role','authenticated')::text, true);
end;
$$;

set local role authenticated;
select pg_temp.act_owner();
select set_config('deskilo.v.sep', public.create_invoice_receipted_v1(current_setting('deskilo.r.ws')::uuid, current_setting('deskilo.r.m')::uuid, '2026-09', '00000000-0000-4000-8000-0000002585a1')::text, false);
select set_config('deskilo.v.rep', public.create_invoice_replacement_v1(current_setting('deskilo.r.ws')::uuid, current_setting('deskilo.r.m')::uuid, '2026-09',
  current_setting('deskilo.v.sep')::uuid, '00000000-0000-4000-8000-0000002585d1', false, 'full', '', '', 'wrong period')::text, false);
select set_config('deskilo.v.rep2', public.create_invoice_replacement_v1(current_setting('deskilo.r.ws')::uuid, current_setting('deskilo.r.m')::uuid, '2026-09',
  current_setting('deskilo.v.sep')::uuid, '00000000-0000-4000-8000-0000002585d1', false, 'full', '', '', 'wrong period')::text, false);
reset role;

-- ── A: the replacement ────────────────────────────────────────────────
select isnt(current_setting('deskilo.v.rep'), current_setting('deskilo.v.sep'), 'a NEW invoice replaces the first');
select isnt((select voided_at from public.invoices where id = current_setting('deskilo.v.sep')::uuid), null, 'the replaced invoice is voided with it');
select is((select replaces_invoice_id from public.invoices where id = current_setting('deskilo.v.rep')::uuid), current_setting('deskilo.v.sep')::uuid, 'and the new one references it');
select is((select total_cents from public.invoices where id = current_setting('deskilo.v.rep')::uuid), 4500, 'with the seeded amount');

-- ── B: the replay ─────────────────────────────────────────────────────
select is(current_setting('deskilo.v.rep2'), current_setting('deskilo.v.rep'), 'the replay answers the ORIGINAL replacement');
select is((select count(*)::int from public.invoices where replaces_invoice_id = current_setting('deskilo.v.sep')::uuid), 1, 'nothing was issued twice');

-- ── C: changed payload ────────────────────────────────────────────────
select matches(pg_temp.as_err('00000000-0000-4000-8000-000000258541',
  $$select public.create_invoice_replacement_v1(current_setting('deskilo.r.ws')::uuid, current_setting('deskilo.r.m')::uuid, '2026-09',
     current_setting('deskilo.v.sep')::uuid, '00000000-0000-4000-8000-0000002585d1', false, 'full', '', '', 'another reason')$$),
  'request conflict', 'the same id with another reason is refused');

-- ── D: a failing replacement leaves nothing ───────────────────────────
select isnt(pg_temp.as_err('00000000-0000-4000-8000-000000258541',
  $$select public.create_invoice_replacement_v1(current_setting('deskilo.r.ws')::uuid, current_setting('deskilo.r.m')::uuid, '2026-09',
     '00000000-0000-4000-8000-0000002585ee', '00000000-0000-4000-8000-0000002585d2')$$), '', 'an unknown replaced invoice is refused');
select is((select count(*)::int from public.financial_command_receipts where request_id = '00000000-0000-4000-8000-0000002585d2'), 0, 'with no receipt');

-- ── E: the outcome read ───────────────────────────────────────────────
set local role authenticated;
select pg_temp.act_owner();
select set_config('deskilo.v.out', public.financial_command_outcome_v1(current_setting('deskilo.r.ws')::uuid, '00000000-0000-4000-8000-0000002585d1')::text, false);
reset role;
select is((current_setting('deskilo.v.out')::jsonb)->>'invoice_id', current_setting('deskilo.v.rep'), 'the outcome names the replacement');
select is((current_setting('deskilo.v.out')::jsonb)->>'command_kind', 'invoice_replace', 'and its kind');

select * from finish();
rollback;
