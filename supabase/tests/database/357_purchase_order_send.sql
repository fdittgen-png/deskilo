-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3307 / 0676: e-mailing a purchase order. The billing manager stores the
-- space's sender and its API key (Vault; never read back by a client); a
-- send attempt is opened by the buyer, its outcome recorded by the service
-- role; a pending or unconfirmed attempt blocks a second one; a person
-- decides an unconfirmed one; an accepted one sends the order by e-mail.
begin;
select plan(24);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000033071'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@send.test','',now(),now(),now()
  from unnest(array['a1','a2','a3']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,role_permissions,feature_flags) values
 ('00000000-0000-4000-8000-0000033071b1','Send','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000033071a1','dev',
  '{"member":["viewFinances"]}',
  '{"moneyTab":true,"services":true,"purchases":true,"purchaseOrders":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000033071c1','00000000-0000-4000-8000-0000033071b1','00000000-0000-4000-8000-0000033071a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000033071c2','00000000-0000-4000-8000-0000033071b1','00000000-0000-4000-8000-0000033071a2',false,false,'active');
insert into public.suppliers (id, workspace_id, supplier_number, name, status) values
 ('00000000-0000-4000-8000-0000033071f1','00000000-0000-4000-8000-0000033071b1','1','Alpha','active');

create function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000033071' || p)::uuid;
$$;
create function pg_temp.as_user(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated')::text, true);
  execute p_sql into v;
  return v;
end;
$$;
create function pg_temp.err(p_user text, p_sql text) returns text language plpgsql as $$
begin
  perform pg_temp.as_user(p_user, p_sql);
  return '';
exception when others then
  return sqlstate || ' ' || sqlerrm;
end;
$$;
create function pg_temp.order_of(p_email text) returns jsonb language sql as $$
  select pg_temp.as_user('a1', format('select public.save_purchase_order_v1(%L, %L, 0, %L::jsonb)',
    pg_temp.u('b1'), gen_random_uuid(), jsonb_build_object('supplier_id', pg_temp.u('f1'),
      'recipient_email', p_email,
      'lines', jsonb_build_array(jsonb_build_object('description', 'Paper', 'quantity', 2, 'unit_price_cents', 500)))));
$$;
create function pg_temp.settings(p_key text, p_revision int, p_sender text default 'orders@space.test') returns text language sql as $$
  select format('select public.save_purchase_order_mail_settings_v1(%L, %L, %L, %L, %s)',
    pg_temp.u('b1'), p_sender, 'The Space', p_key, p_revision);
$$;
create function pg_temp.begin_send(p_order jsonb, p_attempt uuid) returns text language sql as $$
  select format('select public.begin_purchase_order_send_v1(%L, %L, %s, %L)',
    pg_temp.u('b1'), p_order ->> 'id', p_order ->> 'revision', p_attempt);
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

set local role authenticated;
select set_config('t.o1', pg_temp.order_of('orders@alpha.test')::text, true);
select set_config('t.o2', pg_temp.order_of('')::text, true);

-- ── the sender and its key ────────────────────────────────────────────
select ok(pg_temp.err('a2', pg_temp.settings('re_test_key_123456', 0)) like '42501%',
  'only a billing manager configures the mail');
select ok(pg_temp.err('a1', pg_temp.settings(null, 0)) like '%brings its API key%',
  'the first configuration brings a key');
select ok(pg_temp.err('a1', pg_temp.settings('not a key!', 0)) like '%not an API key%', 'a key of another shape is refused');
select ok(pg_temp.err('a1', pg_temp.settings('re_test_key_123456', 0, E'a@b.c\nBcc: x@y.z')) like '%not an e-mail address%',
  'a sender carrying a header is refused');
select is(pg_temp.as_user('a1', pg_temp.settings('re_test_key_123456', 0)),
  '{"revision": 1, "has_api_key": true, "sender_name": "The Space", "sender_email": "orders@space.test"}'::jsonb,
  'the settings are saved; the answer never carries the key');
reset role;
select is((select decrypted_secret from vault.decrypted_secrets where name = 'purchase-order-mail:' || pg_temp.u('b1')),
  're_test_key_123456', 'the key is kept in Vault');
select is(public.purchase_order_mail_key_resolved(pg_temp.u('b1')) ->> 'sender_email', 'orders@space.test',
  'the service role reads the key and the sender');
select ok(not has_function_privilege('authenticated', 'public.purchase_order_mail_key_resolved(uuid)', 'execute')
          and not has_function_privilege('authenticated', 'public.finish_purchase_order_send(uuid,text,text,text)', 'execute'),
  'no client calls the key or records an outcome');
set local role authenticated;
select is(pg_temp.as_user('a1', pg_temp.settings(null, 1, 'buying@space.test')) ->> 'sender_email', 'buying@space.test',
  'the sender changes without restating the key');

-- ── opening a send ────────────────────────────────────────────────────
select ok(pg_temp.err('a1', pg_temp.begin_send(current_setting('t.o2')::jsonb, gen_random_uuid())) like '%no address%',
  'an order naming no recipient is not e-mailed');
select ok(pg_temp.err('a2', pg_temp.begin_send(current_setting('t.o1')::jsonb, gen_random_uuid())) like '42501%',
  'a finance reader does not send');
select set_config('t.s1', gen_random_uuid()::text, true);
select is(pg_temp.as_user('a1', pg_temp.begin_send(current_setting('t.o1')::jsonb, current_setting('t.s1')::uuid)) ->> 'state',
  'pending', 'a send opens, pending, to the order''s recipient');
select is(pg_temp.as_user('a1', pg_temp.begin_send(current_setting('t.o1')::jsonb, current_setting('t.s1')::uuid)) ->> 'id',
  current_setting('t.s1'), 'the same attempt id replays the same attempt');
select ok(pg_temp.err('a1', pg_temp.begin_send(current_setting('t.o1')::jsonb, gen_random_uuid())) like '55000%',
  'a second attempt waits while the first has no outcome');

-- ── outcomes ──────────────────────────────────────────────────────────
reset role;
select is(public.finish_purchase_order_send(current_setting('t.s1')::uuid, 'unconfirmed', '', 'timeout') ->> 'state',
  'unconfirmed', 'a timeout is recorded as unconfirmed');
select ok((select state from public.purchase_orders where id = (current_setting('t.o1')::jsonb ->> 'id')::uuid) = 'draft',
  '... and the order is not taken for sent');
set local role authenticated;
select ok(pg_temp.err('a1', pg_temp.begin_send(current_setting('t.o1')::jsonb, gen_random_uuid())) like '%check before sending again%',
  'an unconfirmed attempt is never resent blindly');
select is(pg_temp.as_user('a1', format('select public.resolve_purchase_order_send_v1(%L, %L, false)',
    pg_temp.u('b1'), current_setting('t.s1'))) ->> 'state', 'not_delivered',
  'a person who checked says it did not arrive');
select set_config('t.s2', gen_random_uuid()::text, true);
select is(pg_temp.as_user('a1', pg_temp.begin_send(current_setting('t.o1')::jsonb, current_setting('t.s2')::uuid)) ->> 'state',
  'pending', '... and a new send may go');
reset role;
select is(public.finish_purchase_order_send(current_setting('t.s2')::uuid, 'accepted', 'resend-id-1', '') ->> 'provider_id',
  'resend-id-1', 'an accepted send keeps the provider''s id');
select is((select (state, sent_via) from public.purchase_orders where id = (current_setting('t.o1')::jsonb ->> 'id')::uuid),
  ('sent'::text, 'email'::text), '... and the order is sent, by e-mail');
select is(public.finish_purchase_order_send(current_setting('t.s2')::uuid, 'accepted', 'resend-id-1', '') ->> 'state',
  'accepted', 'the same outcome again is a replay');
select throws_ok(format($q$select public.finish_purchase_order_send(%L, 'refused', '', 'x')$q$, current_setting('t.s2')),
  '55000', null, 'an outcome is never overwritten');
set local role authenticated;

select is(pg_temp.as_user('a2', $q$select to_jsonb(count(*)) from public.purchase_order_sends$q$)::text, '2',
  'a finance reader reads the attempts');

select * from finish();
rollback;
