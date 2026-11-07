-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3338 / 0696 -- the runtime half of the removal check: what still needs a
-- jurisdiction module, by id. Unsettled transmissions of the provider and
-- syntax asked about (prepared, sent, uncertain -- never accepted, rejected or
-- failed), the e-invoice channel configured with that provider, and the
-- replacements of an accepted document that still have to leave. Another
-- space's rows never appear; the owner and a manager may ask, a plain member,
-- a stranger and an assistant may not.
begin;
select plan(23);

create or replace function pg_temp.v(p text) returns text language sql as $$
  select current_setting('rf.' || p)
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
  return sqlstate;
end;
$$;
create or replace function pg_temp.facts(p_who text, p_provider text default 'it_sdi', p_format text default null, p_ws text default 'ws', p_delegated boolean default false)
returns text language sql as $$
  select pg_temp.as_actor(p_who, format($q$select public.jurisdiction_removal_facts_v1(%L, %L, %L)::text$q$,
    pg_temp.v(p_ws), p_provider, p_format), p_delegated)
$$;
create or replace function pg_temp.ids(p_json text, p_list text, p_key text) returns text language sql as $$
  select coalesce(string_agg(e ->> p_key, ',' order by e ->> p_key), '')
    from jsonb_array_elements((p_json::jsonb) -> p_list) e
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

do $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000033800d1';
  u_m uuid := '00000000-0000-4000-8000-0000033800d2';
  u_p uuid := '00000000-0000-4000-8000-0000033800d3';
  u_x uuid := '00000000-0000-4000-8000-0000033800d4';
  ws uuid; ws2 uuid; r_b uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'removal-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_m, u_p, u_x]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Removal books', 'IT', 'EUR', 'Europe/Rome', u_o, '{"moneyTab": true, "invoicing": true, "customRoles": true}'::jsonb)
  returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Another space', 'IT', 'EUR', 'Europe/Rome', u_x, '{"moneyTab": true, "invoicing": true}'::jsonb)
  returning id into ws2;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true), (ws, u_m, false, false), (ws, u_p, false, false), (ws2, u_x, true, true);
  insert into public.workspace_roles (workspace_id, key, permissions)
  values (ws, 'billing', array['manageBilling']) returning id into r_b;
  insert into public.workspace_role_members (workspace_id, role_id, member_id)
  select ws, r_b, id from public.members where workspace_id = ws and user_id = u_m;
  insert into public.einvoice_credentials (workspace_id, provider, config) values (ws, 'it_sdi', '{}'::jsonb);
  perform set_config('rf.o', u_o::text, false);
  perform set_config('rf.m', u_m::text, false);
  perform set_config('rf.p', u_p::text, false);
  perform set_config('rf.x', u_x::text, false);
  perform set_config('rf.ws', ws::text, false);
  perform set_config('rf.ws2', ws2::text, false);
end
$seed$;

create or replace function pg_temp.id(p text) returns text language sql as $$ select '00000000-0000-4000-8000-0000033873' || p $$;
create or replace function pg_temp.inv(p_id text, p_replaces text default null, p_ws text default 'ws') returns void language sql as $$
  insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                               currency, member_name, workspace_name, issuer_name, signature, issued_at, replaces_invoice_id)
  select pg_temp.id(p_id)::uuid, pg_temp.v(p_ws)::uuid, m.id, m.id,
         'R-' || p_id, 'T', '[]'::jsonb, 1000, 'EUR', 'A', 'Books', 'Owner', 'sig', now(),
         case when p_replaces is null then null else pg_temp.id(p_replaces)::uuid end
    from public.members m where m.workspace_id = pg_temp.v(p_ws)::uuid and m.is_owner
$$;
create or replace function pg_temp.tx(p_n text, p_inv text, p_phase text, p_provider text default 'it_sdi', p_format text default 'fatturaPa', p_ws text default 'ws') returns void language sql as $$
  insert into public.invoice_transmissions (id, workspace_id, invoice_id, provider, status, phase, format, business_key, sent_at)
  values (pg_temp.id(p_n)::uuid, pg_temp.v(p_ws)::uuid, pg_temp.id(p_inv)::uuid, p_provider, 'failed', p_phase, p_format,
          'k-' || p_n, now() + (p_n::int || ' seconds')::interval)
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- invoices: 01..05 sent through Italy in each phase, 06 through Peppol, 07 in
-- another space; 11 replaces 01 (accepted), 12 replaces 02 (not accepted),
-- 13 replaces 08 (accepted) and is accepted itself
select pg_temp.inv('01'); select pg_temp.inv('02'); select pg_temp.inv('03'); select pg_temp.inv('04');
select pg_temp.inv('05'); select pg_temp.inv('06'); select pg_temp.inv('07', null, 'ws2'); select pg_temp.inv('08');
select pg_temp.inv('11', '01'); select pg_temp.inv('12', '02'); select pg_temp.inv('13', '08');
select pg_temp.tx('01', '01', 'accepted');
select pg_temp.tx('02', '02', 'uncertain');
select pg_temp.tx('03', '03', 'sent');
select pg_temp.tx('04', '04', 'prepared');
select pg_temp.tx('05', '05', 'rejected');
select pg_temp.tx('06', '06', 'sent', 'peppol', 'peppolBis');
select pg_temp.tx('07', '07', 'sent', 'it_sdi', 'fatturaPa', 'ws2');
select pg_temp.tx('08', '08', 'accepted');
select pg_temp.tx('13', '13', 'accepted');
-- the second space also has Italian, Peppol and Romanian work (installation scope, below)
select pg_temp.inv('21', null, 'ws2'); select pg_temp.inv('22', null, 'ws2');
select pg_temp.tx('21', '21', 'uncertain', 'it_sdi', 'fatturaPa', 'ws2');
select pg_temp.tx('22', '22', 'sent', 'peppol', 'peppolBis', 'ws2');
select pg_temp.inv('23', null, 'ws2');
select pg_temp.tx('23', '23', 'sent', 'ro_efactura', 'ciusRo', 'ws2');

-- the owner and a manager may ask
select is(pg_temp.ids(pg_temp.facts('o'), 'unsettled_transmissions', 'transmission_id'),
  pg_temp.id('02') || ',' || pg_temp.id('03') || ',' || pg_temp.id('04'),
  'the owner reads the unsettled transmissions of the provider, by id');
select is(pg_temp.ids(pg_temp.facts('m'), 'unsettled_transmissions', 'transmission_id'),
  pg_temp.id('02') || ',' || pg_temp.id('03') || ',' || pg_temp.id('04'),
  'a manager (manageBilling through a role) reads the same');

-- what is listed is exactly the unsettled ones
select is(pg_temp.ids(pg_temp.facts('o'), 'unsettled_transmissions', 'phase'), 'prepared,sent,uncertain',
  'prepared, sent and uncertain count; accepted and rejected do not');
select is((pg_temp.facts('o')::jsonb -> 'unsettled_transmissions' -> 0 ->> 'invoice_id'), pg_temp.id('02'),
  'a row names its invoice');
select is((pg_temp.facts('o')::jsonb -> 'unsettled_transmissions' -> 0 ->> 'provider'), 'it_sdi',
  'and its provider');

-- filters
select is(pg_temp.ids(pg_temp.facts('o', 'peppol'), 'unsettled_transmissions', 'transmission_id'), pg_temp.id('06'),
  'another provider is asked about on its own');
select is(pg_temp.ids(pg_temp.facts('o', 'it_sdi', 'peppolBis'), 'unsettled_transmissions', 'transmission_id'), '',
  'a syntax the provider never carried lists nothing');
select is(pg_temp.ids(pg_temp.facts('o', null), 'unsettled_transmissions', 'transmission_id'),
  pg_temp.id('02') || ',' || pg_temp.id('03') || ',' || pg_temp.id('04') || ',' || pg_temp.id('06'),
  'no provider named lists the whole space');

-- another space never appears
select is(position(pg_temp.id('07') in pg_temp.facts('o')) , 0,
  'a transmission of another space is not listed');
select is(pg_temp.ids(pg_temp.facts('x', 'it_sdi', null, 'ws2'), 'unsettled_transmissions', 'transmission_id'),
  pg_temp.id('07') || ',' || pg_temp.id('21'),
  'and that space reads only its own');

-- the channel and the correction routes
select is(pg_temp.ids(pg_temp.facts('o'), 'enabled_capabilities', 'capability'), 'einvoice_channel.it_sdi',
  'the e-invoice channel configured with the provider is listed');
select is(pg_temp.ids(pg_temp.facts('o', 'peppol'), 'enabled_capabilities', 'capability'), '',
  'a provider the space did not configure is not');
select is(pg_temp.ids(pg_temp.facts('o'), 'needed_correction_routes', 'invoice_id'), pg_temp.id('11'),
  'a replacement of an accepted document that has not been accepted needs the provider; the one accepted already does not, nor does a replacement of a document that was never accepted');

-- authority
select is(pg_temp.facts('p'), '42501', 'a plain member may not ask');
select is(pg_temp.facts('x'), '42501', 'a member of another space may not ask');
select is(pg_temp.facts('o', 'it_sdi', null, 'ws', true), '42501', 'an assistant (delegated token) may not ask, even as the owner');

-- installation scope (0697): removing a module is not one space's decision
select is(has_function_privilege('authenticated', 'public.jurisdiction_removal_facts_installation_v1(text, text)', 'execute'), false,
  'no member may ask for the whole installation');
select is(has_function_privilege('anon', 'public.jurisdiction_removal_facts_installation_v1(text, text)', 'execute'), false,
  'nor an anonymous caller');
select is(has_function_privilege('service_role', 'public.jurisdiction_removal_facts_installation_v1(text, text)', 'execute'), true,
  'the operator (service role) may');
select is(has_function_privilege('authenticated', 'public.jurisdiction_removal_facts_of(uuid, text, text)', 'execute'), false,
  'the shared per-space function has no caller of its own');
select is(pg_temp.ids(pg_temp.facts('o', 'peppol'), 'unsettled_transmissions', 'transmission_id'), pg_temp.id('06'),
  'a space sees only its own work: the first space is blind to the second space''s peppol transmission');
select is(pg_temp.ids(pg_temp.facts('o', 'ro_efactura'), 'unsettled_transmissions', 'transmission_id'), '',
  'the first space, asked alone, is clean for a provider only the second space uses: its answer is NOT the installation''s');
select is((select string_agg(w ->> 'workspace_id', ',')
             from jsonb_array_elements(public.jurisdiction_removal_facts_installation_v1('ro_efactura', 'ciusRo') -> 'workspaces') w
            where w ->> 'workspace_id' in (pg_temp.v('ws'), pg_temp.v('ws2'))),
  pg_temp.v('ws2'),
  'the installation answer names the second space, and only it, with its ids');

select * from finish();
rollback;
