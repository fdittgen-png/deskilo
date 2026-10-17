-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2585 / 0462 (C2): a native invoice-issue attempt has an exact identity.
-- Real roles (authenticated through the definer RPCs); every refusal is
-- followed by a readback. Expected values are written here from the seed
-- (35.00 fee + 10.00 supply = 4500), not read from the function under test.
--   A one request id: one invoice, one receipt, the original id on replay
--   B the same id with another payload is refused and changes nothing
--   C the outcome read: applied for this id, not_observed for any other
--   D a second id for the same month is refused and never relabelled
--   E a command that fails leaves no receipt
--   F who may read: a stranger and a plain member are refused; no table access
-- NOT RUN here: two synchronized sessions on one id (needs two psql
-- processes) and the pending -> confirmed/rejected readback.
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
  uo uuid := '00000000-0000-4000-8000-000000258511';
  um uuid := '00000000-0000-4000-8000-000000258512';
  us uuid := '00000000-0000-4000-8000-000000258513';
  ws uuid; mm uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner@receipt2585.test','',now(),now(),now()),
          (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','member@receipt2585.test','',now(),now(),now()),
          (us,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','stranger@receipt2585.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,
                                vat_regime,vat_id,feature_flags)
   values ('Receipt 2585','FR','EUR','Europe/Paris',uo,'1 rue du Pilote','Pézenas','34120',
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
   values (ws,mm,'charge','adjustment',1000,'Supply','2026-09',20);
  -- A stranger owns another workspace.
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,feature_flags)
   values ('Stranger receipt 2585','FR','EUR','Europe/Paris',us,'{"invoicing":true}');
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at)
   select id,us,true,true,'2026-01-01' from public.workspaces where name = 'Stranger receipt 2585';
  perform set_config('deskilo.r.ws', ws::text, false);
  perform set_config('deskilo.r.m', mm::text, false);
end;
$seed$;

-- ── A: one id, one invoice, one receipt ───────────────────────────────
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','00000000-0000-4000-8000-000000258511','role','authenticated')::text, false);
select set_config('deskilo.r.first', public.request_invoice_issue_v1(
  current_setting('deskilo.r.ws')::uuid, current_setting('deskilo.r.m')::uuid, '2026-09',
  '00000000-0000-4000-8000-0000002585a1')::text, false);
select set_config('deskilo.r.replay', public.request_invoice_issue_v1(
  current_setting('deskilo.r.ws')::uuid, current_setting('deskilo.r.m')::uuid, '2026-09',
  '00000000-0000-4000-8000-0000002585a1')::text, false);
reset role;

select is((current_setting('deskilo.r.first')::jsonb)->>'pending', 'false', 'the first call applies');
select is((select count(*)::int from public.invoices
            where member_id = current_setting('deskilo.r.m')::uuid and period = '2026-09'), 1,
          'one invoice exists for the month');
select is((select total_cents from public.invoices
            where member_id = current_setting('deskilo.r.m')::uuid and period = '2026-09'), 4500,
          'it carries the seeded amount: 3500 fee + 1000 supply');
select is((current_setting('deskilo.r.replay')::jsonb)->>'invoice_id',
          (current_setting('deskilo.r.first')::jsonb)->>'invoice_id',
          'the replay answers the ORIGINAL invoice id');
select is((current_setting('deskilo.r.replay')::jsonb)->>'replayed', 'true', 'and says it is a replay');
select is((select count(*)::int from public.invoices
            where member_id = current_setting('deskilo.r.m')::uuid and period = '2026-09'), 1,
          'the replay issued nothing');
select is((select count(*)::int from public.financial_command_receipts
            where workspace_id = current_setting('deskilo.r.ws')::uuid), 1,
          'exactly one receipt');

-- ── B: the same id, another payload ───────────────────────────────────
select matches(pg_temp.as_err('00000000-0000-4000-8000-000000258511',
  $$select public.request_invoice_issue_v1(current_setting('deskilo.r.ws')::uuid,
     current_setting('deskilo.r.m')::uuid, '2026-09', '00000000-0000-4000-8000-0000002585a1', 'full', true)$$),
  'request conflict', 'the same id with another payload is refused');
select is((select count(*)::int from public.financial_command_receipts
            where workspace_id = current_setting('deskilo.r.ws')::uuid), 1, 'and records nothing');

-- ── C: the outcome read ───────────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','00000000-0000-4000-8000-000000258511','role','authenticated')::text, false);
select is(public.financial_command_outcome_v1(current_setting('deskilo.r.ws')::uuid,
          '00000000-0000-4000-8000-0000002585a1')->>'invoice_id',
          (current_setting('deskilo.r.first')::jsonb)->>'invoice_id', 'applied: the invoice of THAT request');
select is(public.financial_command_outcome_v1(current_setting('deskilo.r.ws')::uuid,
          '00000000-0000-4000-8000-0000002585ff')->>'state', 'not_observed', 'an unknown id is not observed');
reset role;

-- ── D: another id for the same month is refused, never relabelled ─────
select matches(pg_temp.as_err('00000000-0000-4000-8000-000000258511',
  $$select public.request_invoice_issue_v1(current_setting('deskilo.r.ws')::uuid,
     current_setting('deskilo.r.m')::uuid, '2026-09', '00000000-0000-4000-8000-0000002585b2')$$),
  'already invoiced', 'a second id for the same month is refused');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub','00000000-0000-4000-8000-000000258511','role','authenticated')::text, false);
select is(public.financial_command_outcome_v1(current_setting('deskilo.r.ws')::uuid,
          '00000000-0000-4000-8000-0000002585b2')->>'state', 'not_observed',
          'the existing invoice does not become that request''s success');
reset role;

-- ── E: a failing command leaves no receipt ────────────────────────────
select isnt(pg_temp.as_err('00000000-0000-4000-8000-000000258511',
  $$select public.request_invoice_issue_v1(current_setting('deskilo.r.ws')::uuid,
     current_setting('deskilo.r.m')::uuid, '2025-12', '00000000-0000-4000-8000-0000002585c3')$$),
  '', 'a month with nothing to invoice is refused');
select is((select count(*)::int from public.financial_command_receipts
            where request_id = '00000000-0000-4000-8000-0000002585c3'), 0, 'and has no receipt');

-- ── F: who may read, and the table is closed ──────────────────────────
select isnt(pg_temp.as_err('00000000-0000-4000-8000-000000258513',
  $$select public.financial_command_outcome_v1(current_setting('deskilo.r.ws')::uuid,
     '00000000-0000-4000-8000-0000002585a1')$$), '', 'a stranger of another workspace is refused');
select isnt(pg_temp.as_err('00000000-0000-4000-8000-000000258512',
  $$select public.financial_command_outcome_v1(current_setting('deskilo.r.ws')::uuid,
     '00000000-0000-4000-8000-0000002585a1')$$), '', 'a plain member who may not issue is refused');
select isnt(pg_temp.as_err('00000000-0000-4000-8000-000000258511',
  $$select count(*) from public.financial_command_receipts$$), '', 'no client reads the receipt table');

select * from finish();
rollback;
