-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3336 / 0695 -- the linked-document correction route of a stopped capability.
-- Servicing refuses new work with the unchanged 0A000, except the delivery of a
-- replacement invoice whose replaces link points to an invoice this very
-- connection delivered and the target acknowledged. Nothing a caller labels
-- makes a delivery a correction; retired, a switched-off feature, another
-- connection, an unacknowledged original and another space's invoice all keep
-- the refusal. The envelope marks the admitted one.
begin;
select plan(16);

create or replace function pg_temp.v(p text) returns text language sql as $$
  select current_setting('cs.' || p)
$$;
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
  return case when sqlerrm like '%unresolved%' then sqlstate || ':unresolved' else sqlstate end;
end;
$$;
create or replace function pg_temp.set_state(p_who text, p_to text, p_reason text default 'because', p_key text default 'accountingConnectors')
returns text language sql as $$
  select pg_temp.as_actor(p_who, format($q$select (r ->> 'state') || ':' || (r ->> 'changed') from (select public.set_capability_state_v1(%L, %L, %L, %L) as r) x$q$,
    pg_temp.v('ws'), p_key, p_to, p_reason))
$$;
create or replace function pg_temp.rec(p_doc text, p_status text, p_remote jsonb default '{}', p_conn text default null) returns text language plpgsql as $d$
declare v jsonb;
begin
  v := public.record_accounting_delivery(coalesce(p_conn, pg_temp.v('c1'))::uuid, 'invoice', p_doc::uuid, date '2026-03-02', 'F-2026-0007',
         date '2026-01-01', date '2026-12-31', repeat('a', 64), p_status, p_remote, '');
  return v ->> 'outcome';
exception when others then
  return sqlstate;
end
$d$;
create or replace function pg_temp.state_now(p_who text) returns text language sql as $$
  select pg_temp.as_actor(p_who, format($q$select (public.capability_states_v1(%L) -> 0 ->> 'state') || ':' || (public.capability_states_v1(%L) -> 0 ->> 'derived')$q$,
    pg_temp.v('ws'), pg_temp.v('ws')))
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

do $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000033600d1';
  u_a uuid := '00000000-0000-4000-8000-0000033600d2';
  u_p uuid := '00000000-0000-4000-8000-0000033600d3';
  u_x uuid := '00000000-0000-4000-8000-0000033600d4';
  ws uuid; ws2 uuid; site uuid; c1 uuid; r_b uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'capstate-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_a, u_p, u_x]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Capability books', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"moneyTab": true, "invoicing": true, "accountingBook": true, "accountingConnectors": true, "customRoles": true}'::jsonb)
  returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Another space', 'FR', 'EUR', 'Europe/Paris', u_x,
          '{"moneyTab": true, "invoicing": true, "accountingBook": true, "accountingConnectors": true}'::jsonb)
  returning id into ws2;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true), (ws, u_a, false, false), (ws, u_p, false, false), (ws2, u_x, true, true);
  -- the manager: not the owner, holds the connector right through a role
  insert into public.workspace_roles (workspace_id, key, permissions)
  values (ws, 'billing', array['manageBilling']) returning id into r_b;
  insert into public.workspace_role_members (workspace_id, role_id, member_id)
  select ws, r_b, id from public.members where workspace_id = ws and user_id = u_a;
  insert into public.sites (workspace_id, name) values (ws, 'Studio') returning id into site;
  insert into public.accounting_connections
    (workspace_id, issuer_site_id, target_id, auth_kind, remote_tenant_id, display_name, status, connected_at)
  values (ws, site, 'pennylane_api', 'token', '812345678', 'Pennylane', 'connected', now())
  returning id into c1;
  perform set_config('cs.o', u_o::text, false);
  perform set_config('cs.a', u_a::text, false);
  perform set_config('cs.p', u_p::text, false);
  perform set_config('cs.x', u_x::text, false);
  perform set_config('cs.ws', ws::text, false);
  perform set_config('cs.ws2', ws2::text, false);
  perform set_config('cs.site', site::text, false);
  perform set_config('cs.c1', c1::text, false);
end
$seed$;


create or replace function pg_temp.inv(p_id text, p_replaces text default null, p_ws text default null) returns void language sql as $$
  insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                               currency, member_name, workspace_name, issuer_name, signature, issued_at, replaces_invoice_id)
  select ('00000000-0000-4000-8000-0000033672' || p_id)::uuid, coalesce(p_ws, pg_temp.v('ws'))::uuid, m.id, m.id,
         'C-' || p_id, 'T', '[]'::jsonb, 1000, 'EUR', 'A', 'Books', 'Owner', 'sig', now(),
         case when p_replaces is null then null else ('00000000-0000-4000-8000-0000033672' || p_replaces)::uuid end
    from public.members m where m.workspace_id = coalesce(p_ws, pg_temp.v('ws'))::uuid and m.is_owner
$$;
create or replace function pg_temp.id(p text) returns text language sql as $$ select '00000000-0000-4000-8000-0000033672' || p $$;
grant execute on all functions in schema pg_temp to authenticated, anon;

do $second$
declare s2 uuid; c2 uuid;
begin
  insert into public.sites (workspace_id, name) values (pg_temp.v('ws')::uuid, 'Annex') returning id into s2;
  insert into public.accounting_connections
    (workspace_id, issuer_site_id, target_id, auth_kind, remote_tenant_id, display_name, status, connected_at)
  values (pg_temp.v('ws')::uuid, s2, 'pennylane_api', 'token', '999', 'Second', 'connected', now()) returning id into c2;
  perform set_config('cs.c2', c2::text, false);
end
$second$;

-- invoices: a=o1,r1 (acknowledged on c1)  b=o2,r2 (original failed)  c=o3,r3 (original on c2)
-- d=r4 (no link)  e=o5 (another space; a link to it is refused by key)  f=o6,r6  g=o7,r7
select pg_temp.inv('01'); select pg_temp.inv('11', '01');
select pg_temp.inv('02'); select pg_temp.inv('12', '02');
select pg_temp.inv('03'); select pg_temp.inv('13', '03');
select pg_temp.inv('14');
select pg_temp.inv('05', null, pg_temp.v('ws2'));
select pg_temp.inv('06'); select pg_temp.inv('16', '06');
select pg_temp.inv('07'); select pg_temp.inv('17', '07');

-- active: the originals are delivered
select pg_temp.rec(pg_temp.id('01'), 'generated'); select pg_temp.rec(pg_temp.id('01'), 'acknowledged', '{"id": "R-1"}');
select pg_temp.rec(pg_temp.id('02'), 'generated'); select pg_temp.rec(pg_temp.id('02'), 'failed');
select pg_temp.rec(pg_temp.id('03'), 'generated', '{}', pg_temp.v('c2')); select pg_temp.rec(pg_temp.id('03'), 'acknowledged', '{"id": "R-3"}', pg_temp.v('c2'));
select pg_temp.rec(pg_temp.id('06'), 'generated'); select pg_temp.rec(pg_temp.id('06'), 'acknowledged', '{"id": "R-6"}');
select pg_temp.rec(pg_temp.id('07'), 'generated'); select pg_temp.rec(pg_temp.id('07'), 'acknowledged', '{"id": "R-7"}');
create or replace function pg_temp.cross_link() returns text language plpgsql as $f$
begin
  perform pg_temp.inv('15', '05');
  return 'linked';
exception when others then return sqlstate;
end $f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- active: a replacement is an ordinary new delivery, not marked
select is(pg_temp.rec(pg_temp.id('17'), 'generated'), 'created', 'active admits a replacement as any new delivery');
select ok(not (select (issuer ? 'linked_correction') from public.provenance_envelopes where result_kind = 'accounting_delivery'
                 and result_id = (select id from public.accounting_deliveries where document_id = pg_temp.id('17')::uuid)),
  'and its envelope is not marked a linked correction');

select pg_temp.rec(pg_temp.id('17'), 'acknowledged', '{"id": "R-17"}');

select is(pg_temp.set_state('a', 'servicing', ''), 'servicing:true', 'a manager stops new work');
select is(pg_temp.rec(pg_temp.id('14'), 'generated'), '0A000', 'servicing refuses an invoice with no replaces link');
select is(pg_temp.rec(pg_temp.id('12'), 'generated'), '0A000', 'servicing refuses a replacement whose original was never acknowledged');
select is(pg_temp.rec(pg_temp.id('13'), 'generated'), '0A000', 'servicing refuses a replacement whose original was acknowledged on another connection');
select is(pg_temp.cross_link(), '23503', 'a replacement of another space''s invoice cannot exist (the same-workspace key); the helper also joins both invoices to the connection''s workspace');
select is(pg_temp.as_actor('o', format($q$select public.record_accounting_delivery(%L, 'payment', %L, date '2026-03-02', 'C-11',
          date '2026-01-01', date '2026-12-31', %L, 'generated', '{}', '')::text$q$, pg_temp.v('c1'), pg_temp.id('11'), repeat('a', 64))),
  '42501', 'a signed-in caller cannot call the writer to label anything a correction');
select ok(not has_function_privilege('authenticated', 'public.capability_linked_correction(uuid, text, uuid)', 'execute'),
  'the helper is not callable by a client');

-- the admitted one
select is(pg_temp.rec(pg_temp.id('11'), 'generated'), 'created', 'servicing admits the replacement of an invoice this connection delivered and the target acknowledged');
select ok((select (issuer ->> 'linked_correction')::boolean and issuer ->> 'replaces_invoice_id' = pg_temp.id('01')
             from public.provenance_envelopes where result_kind = 'accounting_delivery'
              and result_id = (select id from public.accounting_deliveries where document_id = pg_temp.id('11')::uuid)),
  'its envelope marks a linked correction and names the replaced invoice, server-derived');
select is(pg_temp.rec(pg_temp.id('11'), 'generated'), 'existing', 'the same call again is idempotent');
select is(pg_temp.rec(pg_temp.id('11'), 'acknowledged', '{"id": "R-11"}'), 'updated', 'its outcome lands as for any admitted delivery');

-- a switched-off feature stays authoritative over a stored servicing state
update public.workspaces set feature_flags = feature_flags || '{"accountingConnectors": false}'::jsonb where id = pg_temp.v('ws')::uuid;
select is(pg_temp.rec(pg_temp.id('16'), 'generated'), '0A000', 'a feature that is off admits no correction either');
update public.workspaces set feature_flags = feature_flags || '{"accountingConnectors": true}'::jsonb where id = pg_temp.v('ws')::uuid;

-- retired admits nothing
select is(pg_temp.set_state('o', 'retired', 'closing the country'), 'retired:true', 'the owner retires the capability');
select is(pg_temp.rec(pg_temp.id('16'), 'generated'), '0A000', 'retired refuses a linked correction too');

select * from finish();
rollback;
