-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0863: no request is needed to pick up an e-invoice attempt that stopped half-way. The sweep moves an
-- overdue `sent` transmission to `uncertain` and leaves a fresh one; it tells the owner of every `uncertain`
-- one and of every `prepared` one past the window, once while the notice is open; it sends nothing (a
-- prepared one stays prepared, its generation unchanged, nothing claimed); the notice ends with the phase
-- the transmission moved to; only those who may issue invoices read it; the window is a setting. Rolled back.
begin;
select plan(22);

create or replace function pg_temp.v(p text) returns text language sql as $$ select current_setting('sw.' || p) $$;
create or replace function pg_temp.as_actor(p_who text, p_sql text) returns text language plpgsql as $$
declare v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.v(p_who), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  reset role;
  return coalesce(v, 'ok');
exception when others then
  reset role;
  return sqlstate;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

do $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000086300d1';
  u_m uuid := '00000000-0000-4000-8000-0000086300d2';
  ws uuid; mo uuid; i1 uuid; i2 uuid; i3 uuid; i4 uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sw-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_m]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Sweep', 'FR', 'EUR', 'Europe/Paris', u_o) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (ws, u_o, true, true) returning id into mo;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (ws, u_m, false, false);
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency,
                               member_name, workspace_name, issuer_name, signature, period, kind)
  values (ws, mo, mo, 'S-1', 'a', '[]'::jsonb, 100, 'EUR', 'M', 'W', 'M', 'sig', '2026-01', 'full') returning id into i1;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency,
                               member_name, workspace_name, issuer_name, signature, period, kind)
  values (ws, mo, mo, 'S-2', 'b', '[]'::jsonb, 100, 'EUR', 'M', 'W', 'M', 'sig', '2026-02', 'full') returning id into i2;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency,
                               member_name, workspace_name, issuer_name, signature, period, kind)
  values (ws, mo, mo, 'S-3', 'c', '[]'::jsonb, 100, 'EUR', 'M', 'W', 'M', 'sig', '2026-03', 'full') returning id into i3;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency,
                               member_name, workspace_name, issuer_name, signature, period, kind)
  values (ws, mo, mo, 'S-4', 'd', '[]'::jsonb, 100, 'EUR', 'M', 'W', 'M', 'sig', '2026-04', 'full') returning id into i4;
  perform set_config('sw.o', u_o::text, false);
  perform set_config('sw.m', u_m::text, false);
  perform set_config('sw.ws', ws::text, false);
  perform set_config('sw.i1', i1::text, false);
  perform set_config('sw.i2', i2::text, false);
  perform set_config('sw.i3', i3::text, false);
  perform set_config('sw.i4', i4::text, false);
end
$seed$;

create or replace function pg_temp.prep(p_inv text) returns text language sql as $$
  select (public.prepare_einvoice_v1(pg_temp.v('ws')::uuid, p_inv::uuid, 'generic', 'government', 'prod', pg_temp.v('o')::uuid,
    'T', 'facturX', 'h-' || p_inv, 'f.pdf', 'application/pdf', '', '', '\x01'::bytea) ->> 'id') $$;

-- t1: sent, its deadline passed. t2: sent, fresh. t3: prepared long ago. t4: prepared just now.
select set_config('sw.t1', pg_temp.prep(pg_temp.v('i1')), false);
select set_config('sw.t2', pg_temp.prep(pg_temp.v('i2')), false);
select set_config('sw.t3', pg_temp.prep(pg_temp.v('i3')), false);
select set_config('sw.t4', pg_temp.prep(pg_temp.v('i4')), false);
select public.claim_einvoice_dispatch_v1(pg_temp.v('t1')::uuid, pg_temp.v('o')::uuid, 150);
select public.claim_einvoice_dispatch_v1(pg_temp.v('t2')::uuid, pg_temp.v('o')::uuid, 150);
update public.invoice_transmissions set deadline = now() - interval '1 minute' where id = pg_temp.v('t1')::uuid;
set local session_replication_role = replica;
update public.invoice_transmissions set created_datetime = now() - interval '3 hours', modified_datetime = now() - interval '3 hours' where id = pg_temp.v('t3')::uuid;
set local session_replication_role = origin;

select is(public.setting_value(null, 'einvoice.stuck_attempt_minutes'), '60'::jsonb, 'the window is a setting, 60 minutes by default');
select is((public.einvoice_sweep() ->> 'expired'), '1', 'the sweep expires the overdue dispatch, with no request');
select is((select phase from public.invoice_transmissions where id = pg_temp.v('t1')::uuid), 'uncertain', 'it is uncertain now');
select is((select phase from public.invoice_transmissions where id = pg_temp.v('t2')::uuid), 'sent', 'a fresh dispatch is left');
select is((select count(*)::int from public.events where type = 'einvoice_outcome_unknown'), 2, 'the owner is told of the uncertain one and of the old prepared one');
select is((select count(*)::int from public.events where type = 'einvoice_outcome_unknown' and payload ->> 'transmission' = pg_temp.v('t4')), 0,
  'a prepared one inside the window is not told');
select is((select count(*)::int from public.events where type = 'einvoice_outcome_unknown' and payload ->> 'transmission' = pg_temp.v('t2')), 0,
  'nor a fresh dispatch');
select is((select payload ->> 'phase' from public.events where type = 'einvoice_outcome_unknown' and payload ->> 'transmission' = pg_temp.v('t3')), 'prepared',
  'the old prepared one is told as prepared');
select is((select actor_member_id = subject_member_id and status = 'applied' from public.events
            where type = 'einvoice_outcome_unknown' and payload ->> 'transmission' = pg_temp.v('t1')), true,
  'the owner is its actor and subject; nobody decides it');
select is((public.einvoice_sweep() ->> 'told'), '0', 'a second sweep tells nothing more');
select is((select count(*)::int from public.events where type = 'einvoice_outcome_unknown'), 2, 'one notice per transmission while it is open');

-- it sends nothing
select is((select phase || '/' || generation::text from public.invoice_transmissions where id = pg_temp.v('t3')::uuid), 'prepared/0',
  'the old prepared one stays prepared, nothing claimed: it is never sent again');
select is((select external_id from public.invoice_transmissions where id = pg_temp.v('t1')::uuid), '', 'and nothing was asked of a provider');

-- who reads it
select is(pg_temp.as_actor('o', $q$select count(*)::text from public.events where type = 'einvoice_outcome_unknown'$q$), '2', 'the owner reads the notices');
select is(pg_temp.as_actor('m', $q$select count(*)::text from public.events where type = 'einvoice_outcome_unknown'$q$), '0', 'a plain member reads none');
select is(pg_temp.as_actor('o', $q$select public.einvoice_sweep()::text$q$), '42501', 'a signed-in person cannot run the sweep');

-- the notice ends with the phase the transmission moved to
select public.record_einvoice_outcome_v1(pg_temp.v('t1')::uuid, 1, pg_temp.v('o')::uuid, 'accepted', 'X1', '', '{}');
select is((select payload ->> 'ended' from public.events where type = 'einvoice_outcome_unknown' and payload ->> 'transmission' = pg_temp.v('t1')), 'accepted',
  'a late outcome ends its notice with the phase');
select public.claim_einvoice_dispatch_v1(pg_temp.v('t3')::uuid, pg_temp.v('o')::uuid, 150);
select is((select payload ->> 'ended' from public.events where type = 'einvoice_outcome_unknown' and payload ->> 'transmission' = pg_temp.v('t3')), 'sent',
  'a claim of the prepared one ends its notice');

-- the window
set local session_replication_role = replica;
update public.invoice_transmissions set created_datetime = now() - interval '10 minutes', modified_datetime = now() - interval '10 minutes' where id = pg_temp.v('t4')::uuid;
set local session_replication_role = origin;
select is((public.einvoice_sweep() ->> 'told'), '0', '10 minutes old: inside the default window');
insert into public.setting_values (scope, workspace_id, key, value) values ('platform', null, 'einvoice.stuck_attempt_minutes', '5'::jsonb);
select is((public.einvoice_sweep() ->> 'told'), '1', 'with the window at 5 minutes it is told');
select is((select count(*)::int from public.events where type = 'einvoice_outcome_unknown' and payload ->> 'transmission' = pg_temp.v('t4')), 1, 'once');
select is((select count(*)::int from public.invoice_transmissions where phase = 'uncertain'), 0, 'no transmission moved to uncertain without having been sent');

select * from finish();
rollback;
