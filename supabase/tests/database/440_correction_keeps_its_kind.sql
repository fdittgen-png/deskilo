-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3994 (0784) -- a correction is of the kind of the invoice it replaces.
-- September has a subscription and a usage invoice: replacing the usage one
-- without a kind (as an app sends it) issues a usage invoice and leaves the
-- subscription invoice standing; replacing it with its own kind does too; an
-- explicit other kind is refused (DKI08). A month with one full invoice is
-- corrected as before. Rolled back.
begin;
select plan(7);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  uo uuid := '00000000-0000-4000-8000-000000039941';
  um uuid := '00000000-0000-4000-8000-000000039942';
  ws uuid; mm uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner@kind3994.test','',now(),now(),now()),
          (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','member@kind3994.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,vat_regime,feature_flags)
   values ('Kind 3994','FR','EUR','Europe/Paris',uo,'1 rue du Genre','Pézenas','34120','not_subject','{"invoicing":true,"subscriptionInvoices":true,"usageInvoices":true}')
   returning id into ws;
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at) values (ws,uo,true,true,'2026-01-01');
  insert into public.members(workspace_id,user_id,subscription_pct,joined_at) values (ws,um,1,'2026-01-01')
   returning id into mm;
  delete from public.fee_bands where workspace_id = ws;
  insert into public.fee_bands(workspace_id,from_pct,to_pct,fee_cents,overage_fee_cents) values (ws,0,100,3500,1000);
  -- three half-days in September: one included, two billed as use
  insert into public.reservations(workspace_id,member_id,starts_at,ends_at,status,space_label) values
   (ws,mm,'2026-09-07 08:00+02','2026-09-07 12:00+02','completed','desk'),
   (ws,mm,'2026-09-08 08:00+02','2026-09-08 12:00+02','completed','desk'),
   (ws,mm,'2026-09-09 13:00+02','2026-09-09 17:00+02','completed','desk');
  perform set_config('deskilo.k.ws', ws::text, false);
  perform set_config('deskilo.k.m', mm::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub',uo,'role','authenticated')::text, false);
end;
$seed$;
grant execute on all functions in schema pg_temp to authenticated, anon;
select pg_temp.seed();

create or replace function pg_temp.kind_of(p_id text) returns text language sql as $$
  select kind from public.invoices where id = p_id::uuid
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

set local role authenticated;
select set_config('deskilo.k.sub', public.create_invoice(current_setting('deskilo.k.ws')::uuid,
  current_setting('deskilo.k.m')::uuid, '2026-09', null, false, 'subscription')::text, false);
select set_config('deskilo.k.use', public.create_invoice(current_setting('deskilo.k.ws')::uuid,
  current_setting('deskilo.k.m')::uuid, '2026-09', null, false, 'usage')::text, false);

-- an app sends a correction without its kind
select set_config('deskilo.k.use2', public.create_invoice(current_setting('deskilo.k.ws')::uuid,
  current_setting('deskilo.k.m')::uuid, '2026-09', current_setting('deskilo.k.use')::uuid)::text, false);
select is(pg_temp.kind_of(current_setting('deskilo.k.use2')), 'usage',
  'a correction sent without a kind is of the kind it replaces');
select is((select voided_at is null from public.invoices where id = current_setting('deskilo.k.sub')::uuid), true,
  'and the month''s subscription invoice stands');

-- with its own kind, as the app now sends it
select set_config('deskilo.k.use3', public.create_invoice(current_setting('deskilo.k.ws')::uuid,
  current_setting('deskilo.k.m')::uuid, '2026-09', current_setting('deskilo.k.use2')::uuid, false, 'usage')::text, false);
select is(pg_temp.kind_of(current_setting('deskilo.k.use3')), 'usage', 'a correction sent with its own kind');

-- an explicit other kind
select throws_ok(format('select public.create_invoice(%L, %L, %L, %L, false, %L)',
    current_setting('deskilo.k.ws'), current_setting('deskilo.k.m'), '2026-09', current_setting('deskilo.k.sub'), 'usage'),
  'DKI08', 'a correction is of the kind of the invoice it replaces', 'a correction of another kind is refused');
select is((select voided_at is null from public.invoices where id = current_setting('deskilo.k.sub')::uuid), true,
  'and the invoice it named is not touched');

-- a month with one full invoice, as before
select set_config('deskilo.k.aug', public.create_invoice(current_setting('deskilo.k.ws')::uuid,
  current_setting('deskilo.k.m')::uuid, '2026-08')::text, false);
select set_config('deskilo.k.aug2', public.create_invoice(current_setting('deskilo.k.ws')::uuid,
  current_setting('deskilo.k.m')::uuid, '2026-08', current_setting('deskilo.k.aug')::uuid)::text, false);
select is(pg_temp.kind_of(current_setting('deskilo.k.aug2')), 'full', 'a full invoice is corrected as a full invoice');
select is((select count(*)::int from public.invoices
            where member_id = current_setting('deskilo.k.m')::uuid and period = '2026-08' and voided_at is null), 1,
  'and the month keeps one invoice');
reset role;

select * from finish();
rollback;
