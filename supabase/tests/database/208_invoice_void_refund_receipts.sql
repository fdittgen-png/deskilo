-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2585 / 0463 (C2): voiding an invoice and refunding a credit note carry an
-- exact request identity too.
-- Real roles (authenticated through the definer RPCs); every refusal is
-- followed by a readback. Expected values are written here from the seed
-- (35.00 fee + 10.00 supply = 4500), not read from the function under test.
--   A void: applied once, the replay answers without a second effect
--   B the same id naming another kind or text is refused and records nothing
--   C the outcome read names the kind and the subject invoice
--   D a new id on an already voided invoice is refused, never relabelled
--   E a held void: pending, then rejected (refused) or confirmed (applied)
--   F refund of a credit note: one event, replay without a second one
-- NOT RUN here: two synchronized sessions on one id (needs two psql
-- processes).
begin;
select plan(18);

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
  uo uuid := '00000000-0000-4000-8000-000000258521';
  um uuid := '00000000-0000-4000-8000-000000258522';
  us uuid := '00000000-0000-4000-8000-000000258523';
  ws uuid; mm uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner@void2585.test','',now(),now(),now()),
          (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','member@void2585.test','',now(),now(),now()),
          (us,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','stranger@void2585.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,
                                vat_regime,vat_id,feature_flags)
   values ('Receipt void 2585','FR','EUR','Europe/Paris',uo,'1 rue du Pilote','Pézenas','34120',
           'vat_registered','FR12345678901','{"invoicing":true,"numberSequences":true}')
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
   values ('Stranger void 2585','FR','EUR','Europe/Paris',us,'{"invoicing":true}');
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at)
   select id,us,true,true,'2026-01-01' from public.workspaces where name = 'Stranger void 2585';
  perform set_config('deskilo.r.ws', ws::text, false);
  perform set_config('deskilo.r.m', mm::text, false);
end;
$seed$;


create function pg_temp.act_owner() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub','00000000-0000-4000-8000-000000258521','role','authenticated')::text, true);
end;
$$;

-- Invoices issued the ordinary way: September (4500), August (600), July (-1500).
set local role authenticated;
select pg_temp.act_owner();
select set_config('deskilo.v.sep', public.create_invoice(current_setting('deskilo.r.ws')::uuid, current_setting('deskilo.r.m')::uuid, '2026-09')::text, false);
select set_config('deskilo.v.aug', public.create_invoice(current_setting('deskilo.r.ws')::uuid, current_setting('deskilo.r.m')::uuid, '2026-08')::text, false);
select set_config('deskilo.v.jul', public.create_invoice(current_setting('deskilo.r.ws')::uuid, current_setting('deskilo.r.m')::uuid, '2026-07')::text, false);
select set_config('deskilo.v.void1', public.request_invoice_void_v1(current_setting('deskilo.v.sep')::uuid, '00000000-0000-4000-8000-0000002585d1', 'wrong month')::text, false);
select set_config('deskilo.v.void1b', public.request_invoice_void_v1(current_setting('deskilo.v.sep')::uuid, '00000000-0000-4000-8000-0000002585d1', 'wrong month')::text, false);
reset role;

-- ── A: void applied once ──────────────────────────────────────────────
select is((current_setting('deskilo.v.void1')::jsonb)->>'pending', 'false', 'the void applies');
select isnt((select voided_at from public.invoices where id = current_setting('deskilo.v.sep')::uuid), null, 'the invoice is voided');
select is((current_setting('deskilo.v.void1b')::jsonb)->>'replayed', 'true', 'the replay answers instead of failing on "already voided"');
select is((select count(*)::int from public.events where workspace_id = current_setting('deskilo.r.ws')::uuid and type = 'invoice_void'), 1, 'one void event, the replay made none');

-- ── B: the same id, another command ───────────────────────────────────
select matches(pg_temp.as_err('00000000-0000-4000-8000-000000258521',
  $$select public.request_refund_v1(current_setting('deskilo.v.sep')::uuid, '00000000-0000-4000-8000-0000002585d1', 'wrong month')$$),
  'request conflict', 'the same id as a refund is refused');
select matches(pg_temp.as_err('00000000-0000-4000-8000-000000258521',
  $$select public.request_invoice_void_v1(current_setting('deskilo.v.sep')::uuid, '00000000-0000-4000-8000-0000002585d1', 'another reason')$$),
  'request conflict', 'and with another reason too');

-- ── C: the outcome read ───────────────────────────────────────────────
set local role authenticated;
select pg_temp.act_owner();
select set_config('deskilo.v.out1', public.financial_command_outcome_v1(current_setting('deskilo.r.ws')::uuid, '00000000-0000-4000-8000-0000002585d1')::text, false);
reset role;
select is((current_setting('deskilo.v.out1')::jsonb)->>'command_kind', 'invoice_void', 'the outcome names the kind');
select is((current_setting('deskilo.v.out1')::jsonb)->>'invoice_id', current_setting('deskilo.v.sep'), 'and the subject invoice');

-- ── D: a new id on a voided invoice ───────────────────────────────────
select isnt(pg_temp.as_err('00000000-0000-4000-8000-000000258521',
  $$select public.request_invoice_void_v1(current_setting('deskilo.v.sep')::uuid, '00000000-0000-4000-8000-0000002585d2')$$), '',
  'a new id on an already voided invoice is refused');
select is((select count(*)::int from public.financial_command_receipts where request_id = '00000000-0000-4000-8000-0000002585d2'), 0, 'with no receipt');

-- ── E: a held void ────────────────────────────────────────────────────
insert into public.validation_policies(workspace_id, event_type, required_count)
values (current_setting('deskilo.r.ws')::uuid, 'invoice_void', 1);
set local role authenticated;
select pg_temp.act_owner();
select set_config('deskilo.v.held', public.request_invoice_void_v1(current_setting('deskilo.v.aug')::uuid, '00000000-0000-4000-8000-0000002585e1')::text, false);
select set_config('deskilo.v.out2', public.financial_command_outcome_v1(current_setting('deskilo.r.ws')::uuid, '00000000-0000-4000-8000-0000002585e1')::text, false);
reset role;
select is((current_setting('deskilo.v.held')::jsonb)->>'pending', 'true', 'the policy holds the void');
select is((current_setting('deskilo.v.out2')::jsonb)->>'state', 'pending', 'the outcome reads pending');
update public.events set status = 'rejected' where id = (current_setting('deskilo.v.held')::jsonb->>'event_id')::uuid;
set local role authenticated;
select pg_temp.act_owner();
select set_config('deskilo.v.out3', public.financial_command_outcome_v1(current_setting('deskilo.r.ws')::uuid, '00000000-0000-4000-8000-0000002585e1')::text, false);
reset role;
select is((current_setting('deskilo.v.out3')::jsonb)->>'state', 'refused', 'a rejected event reads as refused');
select is((select voided_at from public.invoices where id = current_setting('deskilo.v.aug')::uuid), null, 'and the invoice is not voided');
set local role authenticated;
select pg_temp.act_owner();
select set_config('deskilo.v.held2', public.request_invoice_void_v1(current_setting('deskilo.v.aug')::uuid, '00000000-0000-4000-8000-0000002585e2')::text, false);
reset role;
update public.events set status = 'confirmed' where id = (current_setting('deskilo.v.held2')::jsonb->>'event_id')::uuid;
set local role authenticated;
select pg_temp.act_owner();
select set_config('deskilo.v.out4', public.financial_command_outcome_v1(current_setting('deskilo.r.ws')::uuid, '00000000-0000-4000-8000-0000002585e2')::text, false);
reset role;
select is((current_setting('deskilo.v.out4')::jsonb)->>'state', 'applied', 'a confirmed event reads as applied');
select isnt((select voided_at from public.invoices where id = current_setting('deskilo.v.aug')::uuid), null, 'and the invoice is voided by the decision');

-- ── F: a refund ───────────────────────────────────────────────────────
delete from public.validation_policies where workspace_id = current_setting('deskilo.r.ws')::uuid;
set local role authenticated;
select pg_temp.act_owner();
select set_config('deskilo.v.refund', public.request_refund_v1(current_setting('deskilo.v.jul')::uuid, '00000000-0000-4000-8000-0000002585f1', 'back to the member')::text, false);
select set_config('deskilo.v.refund2', public.request_refund_v1(current_setting('deskilo.v.jul')::uuid, '00000000-0000-4000-8000-0000002585f1', 'back to the member')::text, false);
reset role;
select is((current_setting('deskilo.v.refund2')::jsonb)->>'replayed', 'true', 'the refund replays');
select is((select count(*)::int from public.events where workspace_id = current_setting('deskilo.r.ws')::uuid and type = 'refund'), 1, 'one refund event');

select * from finish();
rollback;
