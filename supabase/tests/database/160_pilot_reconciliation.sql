-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1917: for the pilot's association (FR, not subject to VAT), one member's
-- month — subscription, usage beyond what it includes, an approved expense
-- share and a manual payment — reads the same through the statement, the
-- invoice lines and the issued invoice. The payment is counted once, as a
-- credit: it lowers the balance and the invoice total, and it is never in
-- the VAT base. And the 0 % lines of a seller that does not charge VAT are
-- what they should be: the stricter essentials of 0393 let it issue.
-- The member submits through record_payment; a different authenticated
-- operator confirms. A repeated confirmation cannot create another credit.
begin;
select plan(19);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  uo uuid := '00000000-0000-4000-8000-000000191701';
  um uuid := '00000000-0000-4000-8000-000000191702';
  ws uuid; mm uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner@pilot1917.test','',now(),now(),now()),
          (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','member@pilot1917.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,vat_regime,feature_flags)
   values ('Pilot 1917','FR','EUR','Europe/Paris',uo,'1 rue du Pilote','Pézenas','34120','not_subject','{"invoicing":true}')
   returning id into ws;
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at) values (ws,uo,true,true,'2026-01-01');
  -- 1 % of September's 22 open days × 2 = one included half-day.
  insert into public.members(workspace_id,user_id,subscription_pct,joined_at) values (ws,um,1,'2026-01-01')
   returning id into mm;
  delete from public.fee_bands where workspace_id = ws;
  insert into public.fee_bands(workspace_id,from_pct,to_pct,fee_cents,overage_fee_cents) values (ws,0,100,3500,1000);
  -- Three half-days used: one included, two billed at 10.00.
  insert into public.reservations(workspace_id,member_id,starts_at,ends_at,status,space_label) values
   (ws,mm,'2026-09-07 08:00+02','2026-09-07 12:00+02','completed','desk'),
   (ws,mm,'2026-09-08 08:00+02','2026-09-08 12:00+02','completed','desk'),
   (ws,mm,'2026-09-09 13:00+02','2026-09-09 17:00+02','completed','desk');
  perform set_config('deskilo.pilot.ws', ws::text, false);
  perform set_config('deskilo.pilot.m', mm::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub',uo,'role','authenticated')::text, false);
end;
$seed$;

select pg_temp.seed();
set local role authenticated;
select is(current_user::text,'authenticated','payment journey runs as authenticated');
select public.distribute_expense(current_setting('deskilo.pilot.ws')::uuid,'Café',1200,'custom','2026-09',
 jsonb_build_array(jsonb_build_object('member_id',current_setting('deskilo.pilot.m')::uuid,'amount_cents',1200)));
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000191702","role":"authenticated"}',true);
select set_config('deskilo.pilot.payment',public.record_payment(current_setting('deskilo.pilot.ws')::uuid,
 current_setting('deskilo.pilot.m')::uuid,2000,'virement','bank_transfer','2026-09-15','2026-09')::text,true);
select is((public.member_statement(current_setting('deskilo.pilot.m')::uuid,'2026-09')->>'balance_cents')::int,-6700,
 'unconfirmed payment does not reduce the balance');
select is((select status from public.events where id=current_setting('deskilo.pilot.payment')::uuid),'pending',
 'manual payment awaits confirmation');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000191701","role":"authenticated"}',true);
select lives_ok($$select public.respond_to_event(current_setting('deskilo.pilot.payment')::uuid,true)$$,
 'operator confirms the members payment');
select throws_ok($$select public.respond_to_event(current_setting('deskilo.pilot.payment')::uuid,true)$$,
 'P0001','already decided','retrying the confirmation cannot post a second credit');
select is((select count(*)::int from public.ledger_entries where event_id=current_setting('deskilo.pilot.payment')::uuid),1,
 'confirmed command posts exactly one ledger row');

create or replace function pg_temp.st() returns jsonb language sql as $$
  select public.member_statement(current_setting('deskilo.pilot.m')::uuid, '2026-09');
$$;
create or replace function pg_temp.lines() returns jsonb language sql as $$
  select public.invoice_lines_for(current_setting('deskilo.pilot.m')::uuid, '2026-09');
$$;

select is((pg_temp.st()->>'fee_cents')::int, 3500, 'the statement bills the subscription band');
select is((pg_temp.st()->>'overage_cents')::int, 2000, 'and two half-days beyond the one included');
select is((pg_temp.st()->>'credits_cents')::int, 800, 'the payment less the expense share is the net of the ledger');
select is((pg_temp.st()->>'balance_cents')::int, -4700, 'and the balance owes 47.00');

select is((select string_agg((l->>'kind') || ':' || (l->>'amount_cents'), ',' order by (l->>'amount_cents')::int desc)
             from jsonb_array_elements(pg_temp.lines()) l),
  'subscription:3500,overage:2000,adjustment:1200,payment:-2000',
  'the invoice lines are the four facts, the payment as a credit');
select is((select count(*)::int from jsonb_array_elements(pg_temp.lines()) l where l->>'kind' = 'payment'),
  1, 'the payment appears once');

select lives_ok($$select public.create_invoice(current_setting('deskilo.pilot.ws')::uuid,
    current_setting('deskilo.pilot.m')::uuid, '2026-09')$$,
  'a seller that does not charge VAT issues its 0 % lines');
select is((select total_cents from public.invoices where member_id = current_setting('deskilo.pilot.m')::uuid),
  4700, 'the issued total is what the statement says is owed');
select is((select sum((l->>'amount_cents')::int)::int from public.invoices i, jsonb_array_elements(i.lines) l
            where i.member_id = current_setting('deskilo.pilot.m')::uuid),
  4700, 'and the stored lines add up to it');
select is((select vat_totals from public.invoices where member_id = current_setting('deskilo.pilot.m')::uuid),
  '[{"percent": 0, "category": "O", "net_cents": 6700, "vat_cents": 0, "gross_cents": 6700}]'::jsonb,
  'the VAT base is the charges alone, at 0 % outside the scope');
select is((select jsonb_array_length(lines) from public.invoices where member_id = current_setting('deskilo.pilot.m')::uuid),
  4, 'and nothing was invented on the way');

-- And what the pilot leaves outside the app is refused at the server, not
-- merely hidden: no online collection (onlinePayments is off) and no VAT
-- filing for an association that is not VAT registered.
select throws_ok($$select public.open_payment_intent(current_setting('deskilo.pilot.ws')::uuid,
    current_setting('deskilo.pilot.m')::uuid, 'stripe', '2026-10', 4700, 'EUR')$$,
  'P0001', 'online payments are off in this workspace', 'no payment is collected online (0393)');
select throws_ok($$select public.save_vat_declaration(current_setting('deskilo.pilot.ws')::uuid,
    '2026-09-01', '2026-09-30', '[]'::jsonb, 0, 0, 'EUR', 0)$$,
  'P0001', 'the workspace is not VAT registered', 'and no VAT return is filed from the app');

reset role;
select * from finish();
rollback;
