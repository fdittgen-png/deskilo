-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3673 (0724): one e-mail sender per business. It can be set when purchase
-- orders OR reminders by e-mail are on, by a billing manager; its read never
-- carries the key; the key reaches the service role only; the purchase-order
-- names of 0683 still work. Rolled back.
begin;
select plan(11);

do $seed$
declare o uuid := '00000000-0000-4000-8000-0000003673a1'; m uuid := '00000000-0000-4000-8000-0000003673a2';
        p uuid := '00000000-0000-4000-8000-0000003673a3'; ws uuid; mp uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', u || '@sender.test', '', now(), now(), now()
    from unnest(array[o, m, p]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Sender', 'FR', 'EUR', 'Europe/Paris', o,
          '{"moneyTab": true, "invoicing": true, "dunning": true, "customRoles": true, "purchases": false, "purchaseOrders": false, "reminderEmail": false}')
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values (ws, o, true, true, 'active'), (ws, m, false, false, 'active');
  -- a purchaser: managePurchases through a custom role, nothing else
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values (ws, p, false, false, 'active') returning id into mp;
  insert into public.workspace_roles (id, workspace_id, key, names, permissions)
  values ('00000000-0000-4000-8000-0000003673c1', ws, 'purchaser', '{"en":"Purchaser"}', array['managePurchases']);
  insert into public.workspace_role_members (workspace_id, role_id, member_id) values (ws, '00000000-0000-4000-8000-0000003673c1', mp);
  perform set_config('t.p', p::text, false);
  perform set_config('t.sent', 'fixture_key_123456', false);
  perform set_config('t.ws', ws::text, false);
  perform set_config('t.o', o::text, false);
  perform set_config('t.m', m::text, false);
end;
$seed$;

create or replace function pg_temp.as_user(p_user text, p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('t.' || p_user), 'role', 'authenticated')::text, true);
  set local role authenticated;
  execute p_sql into v;
  reset role;
  return coalesce(v, 'null');
exception when others then
  reset role;
  return 'ERROR: ' || sqlerrm;
end
$f$;
create or replace function pg_temp.as_delegated(p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  set local role authenticated;
  execute p_sql into v;
  reset role;
  return coalesce(v, 'null');
exception when others then
  reset role;
  return 'ERROR: ' || sqlerrm;
end
$f$;
create or replace function pg_temp.save(p_user text, p_key text, p_revision int) returns text language sql as $f$
  select pg_temp.as_user(p_user, format(
    'select public.save_business_mail_sender_v1(%L, ''billing@space.test'', ''The Space'', %L, %s)::text',
    current_setting('t.ws'), p_key, coalesce(p_revision::text, 'null')))
$f$;

select is(pg_temp.save('o', 'fixture_key_123456', null), 'ERROR: nothing in this business sends e-mail',
          'with neither purchase orders nor reminders by e-mail on, there is no sender to set');
update public.workspaces set feature_flags = feature_flags || '{"reminderEmail": true}' where id = current_setting('t.ws')::uuid;
select is(pg_temp.save('m', 'fixture_key_123456', null), 'ERROR: not allowed to configure how this business sends its e-mail',
          'a member without billing rights cannot set it');
select is((pg_temp.save('o', 'fixture_key_123456', null))::jsonb ->> 'sender_email', 'billing@space.test',
          'with reminders by e-mail on, the billing manager sets it');
select ok(position('fixture_key' in pg_temp.as_user('o', format('select public.business_mail_sender_v1(%L)::text', current_setting('t.ws')))) = 0,
          'its read says configured and the sender, never the key');
select is((pg_temp.as_user('p', format('select public.business_mail_sender_v1(%L)::text', current_setting('t.ws'))))::jsonb ->> 'sender_email',
          'billing@space.test', 'a purchaser reads the sender (an order shows whether it can be e-mailed)');
select is(pg_temp.as_user('m', format('select public.business_mail_sender_v1(%L)::text', current_setting('t.ws'))),
          'ERROR: not allowed to read this business''s e-mail sender', 'a plain member does not');
select is((select v from (select set_config('request.jwt.claims', json_build_object('sub', current_setting('t.o'),
             'role', 'authenticated', 'client_id', 'delegated')::text, true)) x,
           lateral (select pg_temp.as_delegated(format('select public.business_mail_sender_v1(%L)::text', current_setting('t.ws')))) y(v)),
          'ERROR: not allowed to read this business''s e-mail sender', 'a delegated session is refused, as the table refuses it');
select is(public.business_mail_key_resolved(current_setting('t.ws')::uuid) ->> 'api_key',
          current_setting('t.sent'), 'the key reaches the send functions');
select ok(not has_function_privilege('authenticated', 'public.business_mail_key_resolved(uuid)', 'execute'),
          'and no client');
select is(public.purchase_order_mail_key_resolved(current_setting('t.ws')::uuid) ->> 'sender_email', 'billing@space.test',
          'the purchase-order name still resolves the same sender');
select is((pg_temp.as_user('o', format(
  'select public.save_purchase_order_mail_settings_v1(%L, ''orders@space.test'', '''', null, 1)::text',
  current_setting('t.ws'))))::jsonb ->> 'revision', '2', 'and the purchase-order save still writes it');

select * from finish();
rollback;
