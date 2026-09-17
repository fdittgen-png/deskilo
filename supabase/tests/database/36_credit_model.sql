-- SPDX-License-Identifier: 0BSD
--
-- #1279 S2 — a carnet is sold once, charged once, and nobody writes their
-- own credits.
begin;
select plan(7);

create or replace function pg_temp.act_as(p_user uuid) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  execute 'set local role authenticated';
end
$act$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-000000001361', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'carnet-owner@deskilo.test', '', now(), now(), now()),
       ('00000000-0000-4000-8000-000000001362', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'carnet-stranger@deskilo.test', '', now(), now(), now());

select pg_temp.act_as('00000000-0000-4000-8000-000000001361');
select set_config('deskilo.cr.ws',
  public.create_workspace('Carnets', 'FR', 'EUR', 'Europe/Paris', 'dev', false,
    '{"invoicing": true, "carnets": true}'::jsonb)::text, true);
select set_config('deskilo.cr.me',
  (select id from public.members where workspace_id = current_setting('deskilo.cr.ws')::uuid
     and user_id = '00000000-0000-4000-8000-000000001361')::text, true);
insert into public.credit_products (workspace_id, name, half_days, price_cents, validity_months)
values (current_setting('deskilo.cr.ws')::uuid, 'Carnet 10', 10, 5000, null),
       (current_setting('deskilo.cr.ws')::uuid, 'Carnet 20', 20, 8000, 6);

select lives_ok(
  $$ select public.sell_credit(current_setting('deskilo.cr.ws')::uuid,
       current_setting('deskilo.cr.me')::uuid,
       (select id from public.credit_products where name = 'Carnet 10'
          and workspace_id = current_setting('deskilo.cr.ws')::uuid)) $$,
  'an owner sells a carnet');
select public.sell_credit(current_setting('deskilo.cr.ws')::uuid,
  current_setting('deskilo.cr.me')::uuid,
  (select id from public.credit_products where name = 'Carnet 20'
     and workspace_id = current_setting('deskilo.cr.ws')::uuid));

select is(public.member_credit_balance(current_setting('deskilo.cr.me')::uuid), 30,
  'the member can spend thirty half-days');

reset role;
select is(
  (select count(*)::int from public.ledger_entries
    where member_id = current_setting('deskilo.cr.me')::uuid
      and kind = 'charge' and category = 'package'),
  2,
  'each sale is charged once, as a package');
select is(
  (select array_agg(expires_at is not null order by half_days) from public.member_credits
    where member_id = current_setting('deskilo.cr.me')::uuid),
  array[false, true],
  'a carnet without a validity never expires; one with a validity does');

select pg_temp.act_as('00000000-0000-4000-8000-000000001361');
select throws_like(
  $$ insert into public.member_credits (workspace_id, member_id, half_days)
     values (current_setting('deskilo.cr.ws')::uuid, current_setting('deskilo.cr.me')::uuid, 500) $$,
  '%permission denied%',
  'nobody writes credits directly — only a sale does');

select pg_temp.act_as('00000000-0000-4000-8000-000000001362');
select throws_like(
  $$ select public.sell_credit(current_setting('deskilo.cr.ws')::uuid,
       current_setting('deskilo.cr.me')::uuid,
       (select id from public.credit_products limit 1)) $$,
  'only someone who issues invoices%',
  'a stranger cannot sell');
select throws_like(
  $$ select public.member_credit_balance(current_setting('deskilo.cr.me')::uuid) $$,
  'not allowed%',
  'nor read somebody else''s carnets');

select * from finish();
rollback;
