-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3336 / 0691 -- admission of NEW accounting work is split from reading,
-- managing and revoking what exists. With the accountingConnectors feature
-- off (derived state `servicing`): the connections and the transfers read
-- for whoever may read them; the manageable door answers for the
-- revocation and still refuses for work; a connection is revoked (and a
-- repeat is safe); a delivery already admitted records its outcome and a
-- replay returns it; opening a connection and preparing a NEW delivery
-- refuse with the same 0A000 as before. Authority never relaxes: a plain
-- member, another space's owner and an assistant's delegated token are
-- refused in both states.
begin;
select plan(19);

create or replace function pg_temp.v(p text) returns text language sql as $$
  select current_setting('sg.' || p)
$$;
create or replace function pg_temp.act_as(p text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.v(p), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end;
$$;
-- The answer of a statement, or the SQLSTATE it was refused with, as the actor.
create or replace function pg_temp.as_actor(p_who text, p_sql text, p_delegated boolean default false) returns text
language plpgsql as $$
declare v text;
begin
  perform set_config('request.jwt.claims',
    (json_build_object('sub', pg_temp.v(p_who), 'role', 'authenticated')::jsonb
      || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  reset role;
  return coalesce(v, 'ok');
exception when others then
  reset role;
  return sqlstate;
end;
$$;
create or replace function pg_temp.rec(p_doc text, p_status text) returns text language plpgsql as $d$
declare v jsonb;
begin
  v := public.record_accounting_delivery(pg_temp.v('c1')::uuid, 'invoice', p_doc::uuid, date '2026-03-02', 'F-2026-0007',
         date '2026-01-01', date '2026-12-31', repeat('a', 64), p_status, '{}', '');
  return v ->> 'outcome';
exception when others then
  return sqlstate;
end
$d$;
grant execute on all functions in schema pg_temp to authenticated, anon;

do $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000033600c1';
  u_p uuid := '00000000-0000-4000-8000-0000033600c2';
  u_x uuid := '00000000-0000-4000-8000-0000033600c3';
  ws uuid; ws2 uuid; site uuid; c1 uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'servicing-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_p, u_x]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Servicing books', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"moneyTab": true, "invoicing": true, "accountingBook": true, "accountingConnectors": true}'::jsonb)
  returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Another space', 'FR', 'EUR', 'Europe/Paris', u_x,
          '{"moneyTab": true, "invoicing": true, "accountingBook": true, "accountingConnectors": true}'::jsonb)
  returning id into ws2;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true), (ws, u_p, false, false), (ws2, u_x, true, true);
  insert into public.sites (workspace_id, name) values (ws, 'Studio') returning id into site;
  insert into public.accounting_connections
    (workspace_id, issuer_site_id, target_id, auth_kind, remote_tenant_id, display_name, status, connected_at)
  values (ws, site, 'pennylane_api', 'token', '812345678', 'Pennylane', 'connected', now())
  returning id into c1;
  perform set_config('sg.o', u_o::text, false);
  perform set_config('sg.p', u_p::text, false);
  perform set_config('sg.x', u_x::text, false);
  perform set_config('sg.ws', ws::text, false);
  perform set_config('sg.site', site::text, false);
  perform set_config('sg.c1', c1::text, false);
end
$seed$;

-- a delivery admitted while the feature is on
select is(pg_temp.rec('00000000-0000-4000-8000-00000336d001', 'generated'), 'created', 'with the feature on, a delivery is admitted');

-- ── the feature goes off: servicing ─────────────────────────────────────
update public.workspaces set feature_flags = feature_flags || '{"accountingConnectors": false}'::jsonb
 where id = pg_temp.v('ws')::uuid;

select is(pg_temp.as_actor('o', format($q$select jsonb_array_length(public.accounting_connections_v1(%L))::text$q$, pg_temp.v('ws'))),
  '1', 'servicing: the connections read for the manager');
select is(pg_temp.as_actor('o', format($q$select public.accounting_transfers_v1(%L, date '2026-01-01', date '2026-12-31')::text is not null$q$, pg_temp.v('ws'))),
  'true', 'servicing: the transfers read');
select is(pg_temp.as_actor('p', format($q$select public.accounting_connections_v1(%L)::text$q$, pg_temp.v('ws'))),
  '42501', 'servicing: a plain member still reads nothing');
select is(pg_temp.as_actor('x', format($q$select public.accounting_connections_v1(%L)::text$q$, pg_temp.v('ws'))),
  '42501', 'servicing: another space''s owner still reads nothing');
select is(pg_temp.as_actor('o', format($q$select public.accounting_connections_v1(%L)::text$q$, pg_temp.v('ws')), true),
  '42501', 'servicing: an assistant''s delegated token still reads nothing');

-- the manageable door: work keeps the feature, revocation does not
select is(pg_temp.as_actor('o', format($q$select public.accounting_connection_manageable_v1(%L)::text$q$, pg_temp.v('c1'))),
  '0A000', 'servicing: the default (work) purpose refuses with the unchanged 0A000');
select is(pg_temp.as_actor('o', format($q$select public.accounting_connection_manageable_v1(%L, 'work')::text$q$, pg_temp.v('c1'))),
  '0A000', 'servicing: and so does an explicit work purpose');
select is(pg_temp.as_actor('o', format($q$select (public.accounting_connection_manageable_v1(%L, 'revoke') ->> 'status')$q$, pg_temp.v('c1'))),
  'connected', 'servicing: the revocation purpose answers for the manager');
select is(pg_temp.as_actor('p', format($q$select public.accounting_connection_manageable_v1(%L, 'revoke')::text$q$, pg_temp.v('c1'))),
  '42501', 'servicing: a plain member is not the manager, whatever the purpose');
select is(pg_temp.as_actor('o', format($q$select public.accounting_connection_manageable_v1(%L, 'revoke')::text$q$, pg_temp.v('c1')), true),
  '42501', 'servicing: nor is an assistant''s token');

-- new work still refuses
select is(pg_temp.as_actor('o', format($q$select public.open_accounting_connection_v1(%L, %L, 'pennylane_api', 'token', '')::text$q$,
          pg_temp.v('ws'), pg_temp.v('site'))), '0A000', 'servicing: opening a connection refuses with the unchanged 0A000');
select is(pg_temp.rec('00000000-0000-4000-8000-00000336d002', 'generated'), '0A000',
  'servicing: preparing a NEW delivery refuses with the unchanged 0A000');

-- an admitted delivery completes and replays
select is(pg_temp.rec('00000000-0000-4000-8000-00000336d001', 'sent'), 'updated', 'servicing: the outcome of an admitted delivery is recorded');
select is(pg_temp.rec('00000000-0000-4000-8000-00000336d001', 'generated'), 'existing', 'servicing: a replay returns the existing delivery, nothing new is admitted');
select is((select count(*)::int from public.accounting_deliveries where workspace_id = pg_temp.v('ws')::uuid), 1,
  'servicing: exactly the admitted delivery exists');

-- revocation
select is(pg_temp.as_actor('p', format($q$select public.revoke_accounting_connection_v1(%L)::text$q$, pg_temp.v('c1'))),
  '42501', 'servicing: a plain member revokes nothing');
select is(pg_temp.as_actor('o', format($q$select (public.revoke_accounting_connection_v1(%L) ->> 'status')$q$, pg_temp.v('c1'))),
  'revoked', 'servicing: the manager revokes the connection');
select is(pg_temp.as_actor('o', format($q$select (public.revoke_accounting_connection_v1(%L) ->> 'status')$q$, pg_temp.v('c1'))),
  'revoked', 'servicing: a repeat is safe and answers the same');

select * from finish();
rollback;
