-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3774 (0727): the answer of begin_purchase_order_send_v1 says whether the
-- call opened the attempt and whether it may still be sent. The opening call
-- and a young pending replay may send; a pending replay past the bound a
-- person decides after, an unconfirmed one and a finished one may not.
-- Rolled back.
begin;
select plan(6);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000037740'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@replay.test','',now(),now(),now()
  from unnest(array['a1']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags) values
 ('00000000-0000-4000-8000-0000037740b1','Replay','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000037740a1','dev',
  '{"moneyTab":true,"services":true,"purchases":true,"purchaseOrders":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000037740c1','00000000-0000-4000-8000-0000037740b1','00000000-0000-4000-8000-0000037740a1',true,true,'active');
insert into public.suppliers (id, workspace_id, supplier_number, name, status) values
 ('00000000-0000-4000-8000-0000037740f1','00000000-0000-4000-8000-0000037740b1','1','Alpha','active');
-- The sender is configured; no key is needed to open an attempt.
insert into public.purchase_order_mail_settings (workspace_id, sender_email, sender_name, has_api_key)
values ('00000000-0000-4000-8000-0000037740b1', 'orders@replay.test', 'Replay', true);

create function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000037740' || p)::uuid;
$$;
create function pg_temp.as_user(p_sql text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.u('a1'), 'role', 'authenticated')::text, true);
  execute p_sql into v;
  return v;
end;
$$;
create function pg_temp.new_order() returns jsonb language sql as $$
  select pg_temp.as_user(format('select public.save_purchase_order_v1(%L, %L, 0, %L::jsonb)',
    pg_temp.u('b1'), gen_random_uuid(), jsonb_build_object('supplier_id', pg_temp.u('f1'),
      'recipient_email', 'orders@alpha.test',
      'lines', jsonb_build_array(jsonb_build_object('description', 'Paper', 'quantity', 2, 'unit_price_cents', 500)))));
$$;
create function pg_temp.begin_send(p_order jsonb, p_attempt text) returns jsonb language sql as $$
  select pg_temp.as_user(format('select public.begin_purchase_order_send_v1(%L, %L, %s, %L)',
    pg_temp.u('b1'), p_order ->> 'id', p_order ->> 'revision', pg_temp.u(p_attempt)));
$$;
grant execute on all functions in schema pg_temp to authenticated;

set local role authenticated;
select set_config('t.o1', pg_temp.new_order()::text, true);
select set_config('t.o2', pg_temp.new_order()::text, true);
select set_config('t.o3', pg_temp.new_order()::text, true);

select is(pg_temp.begin_send(current_setting('t.o1')::jsonb, 'e1') - array['id', 'order_id', 'recipient', 'provider_id', 'reason', 'created_at', 'finished_at'],
  '{"state": "pending", "opened": true, "sendable": true}'::jsonb, 'the opening call may send');
select is(pg_temp.begin_send(current_setting('t.o1')::jsonb, 'e1') - array['id', 'order_id', 'recipient', 'provider_id', 'reason', 'created_at', 'finished_at'],
  '{"state": "pending", "opened": false, "sendable": true}'::jsonb, 'a young pending replay may send, under the same key');

-- ── a pending attempt past the bound: a crash left no outcome ─────────
select pg_temp.begin_send(current_setting('t.o2')::jsonb, 'e2');
reset role;
set local session_replication_role = replica;
update public.purchase_order_sends set created_datetime = now() - interval '11 minutes' where id = pg_temp.u('e2');
set local session_replication_role = origin;
set local role authenticated;
select is(pg_temp.begin_send(current_setting('t.o2')::jsonb, 'e2') ->> 'sendable', 'false',
  'an old pending replay is never sent again: a person decides it');

-- ── finished attempts ─────────────────────────────────────────────────
select pg_temp.begin_send(current_setting('t.o3')::jsonb, 'e3');
reset role;
select public.finish_purchase_order_send(pg_temp.u('e3'), 'unconfirmed', '', 'timeout');
set local role authenticated;
select ok((pg_temp.begin_send(current_setting('t.o3')::jsonb, 'e3') ->> 'sendable') = 'false'
          and (pg_temp.begin_send(current_setting('t.o3')::jsonb, 'e3') ->> 'state') = 'unconfirmed',
  'an unconfirmed replay is answered as it stands, never sent');
reset role;
select public.resolve_purchase_order_send_v1(pg_temp.u('b1'), pg_temp.u('e3'), false)
  from (select set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.u('a1'), 'role', 'authenticated')::text, true)) x;
select set_config('t.o3', (select jsonb_build_object('id', id, 'revision', revision) from public.purchase_orders
                            where id = (current_setting('t.o3')::jsonb ->> 'id')::uuid)::text, true);
set local role authenticated;
select pg_temp.begin_send(current_setting('t.o3')::jsonb, 'e4');
reset role;
select public.finish_purchase_order_send(pg_temp.u('e4'), 'accepted', 'prov-4', '');
set local role authenticated;
select is(pg_temp.begin_send(current_setting('t.o3')::jsonb, 'e4') ->> 'state', 'accepted',
  'a finished replay is answered as it stands');
select is(pg_temp.begin_send(current_setting('t.o3')::jsonb, 'e4') ->> 'sendable', 'false',
  '... and is not sendable');

select * from finish();
rollback;
