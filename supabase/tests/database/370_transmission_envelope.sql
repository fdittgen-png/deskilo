-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3336 / 0694 -- the transmission envelope. prepare_einvoice_v1 writes one
-- 'transmission' envelope on the `prepared` insert and never again: a replay or
-- a conflict adds none, and a claim, an outcome, a manual resolution or a
-- capability state change leave it as it was. What a client declares about its
-- renderer is clipped in one place (record_provenance): only four keys, only
-- strings of at most 120 characters (a non-string is dropped, never coerced),
-- at most 4096 bytes, and it stays apart from the server-established fields.
-- The invoice hook reads the rule day as the workspace's LOCAL day.
begin;
select plan(24);

create or replace function pg_temp.v(p text) returns text language sql as $$
  select current_setting('te.' || p)
$$;
create or replace function pg_temp.prep(p_dest text, p_hash text, p_declared jsonb default null, p_scheme text default '', p_recv text default '')
returns jsonb language plpgsql as $$
begin
  if p_declared is null then
    return public.prepare_einvoice_v1(pg_temp.v('ws')::uuid, pg_temp.v('inv')::uuid, 'generic', p_dest, 'prod',
      pg_temp.v('uo')::uuid, 'T', 'facturX', p_hash, 'f.pdf', 'application/pdf', p_scheme, p_recv, '\x01'::bytea);
  end if;
  return public.prepare_einvoice_v1(pg_temp.v('ws')::uuid, pg_temp.v('inv')::uuid, 'generic', p_dest, 'prod',
    pg_temp.v('uo')::uuid, 'T', 'facturX', p_hash, 'f.pdf', 'application/pdf', p_scheme, p_recv, '\x01'::bytea, p_declared);
end;
$$;
create or replace function pg_temp.env(p_id text) returns public.provenance_envelopes language sql as $$
  select * from public.provenance_envelopes where result_kind = 'transmission' and result_id = p_id::uuid
$$;
create or replace function pg_temp.invoice(p_ws uuid, p_member uuid, p_number text, p_period text, p_issued timestamptz default now())
returns uuid language plpgsql as $$
declare v uuid;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.v('uo'), 'role', 'authenticated')::text, true);
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, period, title, lines, total_cents,
                               currency, member_name, workspace_name, issuer_name, signature, kind, issued_at)
  values (p_ws, p_member, p_member, p_number, p_period, p_period, '[]', 1000, 'EUR', 'M', 'W', 'O', repeat('s', 64), 'full', p_issued)
  returning id into v;
  return v;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

do $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000033700e1';
  ws uuid; ws2 uuid; m uuid; m2 uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  values (u_o, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'tenv-' || u_o || '@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Transmission books', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"moneyTab": true, "invoicing": true, "accountingBook": true, "accountingConnectors": true}'::jsonb)
  returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Far east books', 'FR', 'EUR', 'Pacific/Auckland', u_o,
          '{"moneyTab": true, "invoicing": true}'::jsonb)
  returning id into ws2;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (ws, u_o, true, true);
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (ws2, u_o, true, true);
  select id into m from public.members where workspace_id = ws and user_id = u_o;
  select id into m2 from public.members where workspace_id = ws2 and user_id = u_o;
  perform set_config('te.uo', u_o::text, false);
  perform set_config('te.ws', ws::text, false);
  perform set_config('te.ws2', ws2::text, false);
  perform set_config('te.m', m::text, false);
  perform set_config('te.m2', m2::text, false);
end
$seed$;
select set_config('te.inv', pg_temp.invoice(pg_temp.v('ws')::uuid, pg_temp.v('m')::uuid, 'TE-1', '2026-05')::text, false);

-- 1-5. one envelope when the transmission is prepared
select set_config('te.t1', pg_temp.prep('government', 'h1', '{"renderer": "facturX", "app_version": "1.2.3"}'::jsonb, '0088', 'recv-1') ->> 'id', false);
select is((select module_id || '/' || module_version || '/' || input_schema from pg_temp.env(pg_temp.v('t1'))),
  'einvoice.transmission/1/einvoice-transmission/1', 'preparing a transmission writes its envelope');
select is((select issuer ->> 'provider' || '/' || (issuer ->> 'destination') || '/' || (issuer ->> 'environment')
             from pg_temp.env(pg_temp.v('t1'))), 'generic/government/prod',
  'it names the provider, destination and environment the server decided');
select is((select issuer ->> 'business_key' from pg_temp.env(pg_temp.v('t1'))),
  (select business_key from public.invoice_transmissions where id = pg_temp.v('t1')::uuid), 'and the business key of the record');
select is((select artifacts ->> 'sha256' || '/' || (artifacts ->> 'format') || '/' || (artifacts ->> 'bytes')
             from pg_temp.env(pg_temp.v('t1'))), 'h1/facturX/1', 'the digest, the format and the byte count');
select ok((select (artifacts ->> 'receiver_given')::boolean and artifacts ->> 'receiver_scheme' = '0088'
             and not (artifacts::text like '%recv-1%') from pg_temp.env(pg_temp.v('t1'))),
  'the recipient is recorded as given, never as its address');

-- 6-10. what the client declares: clipped, apart, never coerced
select is((select declared from pg_temp.env(pg_temp.v('t1'))), '{"renderer": "facturX", "app_version": "1.2.3"}'::jsonb,
  'a declared renderer and version are kept as declared');
select set_config('te.inv2', pg_temp.invoice(pg_temp.v('ws')::uuid, pg_temp.v('m')::uuid, 'TE-2', '2026-06')::text, false);
select set_config('te.t2', public.prepare_einvoice_v1(pg_temp.v('ws')::uuid, pg_temp.v('inv2')::uuid, 'generic', 'government', 'prod',
  pg_temp.v('uo')::uuid, 'T', 'facturX', 'h2', 'f.pdf', 'application/pdf', '', '', '\x01'::bytea,
  jsonb_build_object('renderer', 7, 'app_version', repeat('x', 300), 'format', 'facturX', 'issuer', '{"x": 1}'::jsonb,
                     'actor_user_id', 'forged', 'renderer_version', true)) ->> 'id', false);
select ok(not (select declared ? 'renderer' from pg_temp.env(pg_temp.v('t2'))), 'a non-string value is dropped, not coerced');
select is((select length(declared ->> 'app_version') from pg_temp.env(pg_temp.v('t2'))), 120, 'a long string is cut to 120 characters');
select ok((select not declared ? 'issuer' and not declared ? 'actor_user_id' and not declared ? 'renderer_version'
             and declared ->> 'format' = 'facturX' from pg_temp.env(pg_temp.v('t2'))),
  'only the four allowed keys survive');
select is((select issuer ->> 'actor_user_id' from pg_temp.env(pg_temp.v('t2'))), pg_temp.v('uo'),
  'and a forged actor never reaches the server-established part');

-- 11. an old caller without a declaration
select set_config('te.inv3', pg_temp.invoice(pg_temp.v('ws')::uuid, pg_temp.v('m')::uuid, 'TE-3', '2026-07')::text, false);
select set_config('te.t3', public.prepare_einvoice_v1(pg_temp.v('ws')::uuid, pg_temp.v('inv3')::uuid, 'generic', 'government', 'prod',
  pg_temp.v('uo')::uuid, 'T', 'facturX', 'h3', 'f.pdf', 'application/pdf', '', '', '\x01'::bytea) ->> 'id', false);
select is((select declared from pg_temp.env(pg_temp.v('t3'))), '{}'::jsonb, 'the old fourteen-argument call still works and invents no renderer');

-- 12. the size cap
select throws_ok($$ select public.record_provenance(pg_temp.v('ws')::uuid, 'transmission', gen_random_uuid(), '{}',
    (select jsonb_object_agg('k' || g, repeat('y', 100)) from generate_series(1, 80) g), '{}') $$,
  '22023', 'the declared provenance is too large', 'a declaration of more than 4096 bytes is refused');

-- 13-15. once only
select is((select count(*)::int from public.provenance_envelopes where result_kind = 'transmission'), 3, 'one envelope per prepared transmission');
select pg_temp.prep('government', 'h1', '{"renderer": "other"}'::jsonb);
select is((select declared ->> 'renderer' from pg_temp.env(pg_temp.v('t1'))), 'facturX', 'a replay adds none and changes none');
select pg_temp.prep('government', 'h-changed');
select is((select count(*)::int from public.provenance_envelopes where result_kind = 'transmission'), 3,
  'a conflicting (changed) submission adds none either');

-- 16-19. nothing after the preparation touches it
create temp table env_before as select to_jsonb(e) j from pg_temp.env(pg_temp.v('t1')) e;
select public.claim_einvoice_dispatch_v1(pg_temp.v('t1')::uuid, pg_temp.v('uo')::uuid, 150);
select public.record_einvoice_outcome_v1(pg_temp.v('t1')::uuid, 1, pg_temp.v('uo')::uuid, 'uncertain', '', '', '{}');
select public.resolve_einvoice_manually_v1(pg_temp.v('t1')::uuid, pg_temp.v('uo')::uuid, 'accepted', 'portal shows it', 'ref 1');
select ok((select j = to_jsonb(e) from env_before, pg_temp.env(pg_temp.v('t1')) e), 'a claim, an outcome and a manual resolution leave the envelope as it was');
-- servicing after preparation: the late outcome still lands on the admitted attempt
select pg_temp.prep('customer', 'h4');
select set_config('te.t4', (select id::text from public.invoice_transmissions where business_key like '%|customer|prod'), false);
select public.claim_einvoice_dispatch_v1(pg_temp.v('t4')::uuid, pg_temp.v('uo')::uuid, 150);
insert into public.capability_states (workspace_id, capability_key, state, reason, changed_by_member_id)
values (pg_temp.v('ws')::uuid, 'accountingConnectors', 'servicing', '', pg_temp.v('m')::uuid);
select is((public.record_einvoice_outcome_v1(pg_temp.v('t4')::uuid, 1, pg_temp.v('uo')::uuid, 'accepted', 'X1', '', '{}') ->> 'recorded'), 'true',
  'servicing: the late outcome still lands on the admitted attempt');
select is((select declared from pg_temp.env(pg_temp.v('t4'))), '{}'::jsonb, 'and its envelope is unchanged by the state change');
select throws_ok($$ update public.provenance_envelopes set module_version = '9' where result_id = pg_temp.v('t4')::uuid $$,
  '23514', 'provenance is written once and never changed', 'the envelope is still insert-only');

-- 20-21. cross-workspace isolation through the reader
select is((select count(*)::int from public.provenance_envelopes where workspace_id = pg_temp.v('ws2')::uuid), 0,
  'the other space holds none of these envelopes');
select ok((select bool_and(workspace_id = pg_temp.v('ws')::uuid) from public.provenance_envelopes where result_kind = 'transmission'),
  'every transmission envelope is in the space of its transmission');

-- 22-24. the invoice hook: the rule day is the workspace's LOCAL day
select set_config('te.inv4', pg_temp.invoice(pg_temp.v('ws2')::uuid, pg_temp.v('m2')::uuid, 'TE-NZ', '2026-04',
  timestamptz '2026-03-31 20:00:00+00')::text, false);
select is((select rule_revision ->> 'status' from public.provenance_envelopes where result_kind = 'invoice' and result_id = pg_temp.v('inv4')::uuid),
  'known', 'the tax reference is known for that day');
select is((select rule_revision ->> 'as_of' from public.provenance_envelopes where result_kind = 'invoice' and result_id = pg_temp.v('inv4')::uuid),
  '2026-04-01', 'the rule day is the workspace''s local day (20:00 UTC on 31 March is 1 April in Auckland)');
select is((select rule_revision ->> 'as_of' from public.provenance_envelopes where result_kind = 'invoice' and result_id = pg_temp.v('inv')::uuid),
  (select (issued_at at time zone 'Europe/Paris')::date::text from public.invoices where id = pg_temp.v('inv')::uuid),
  'and for a Paris workspace it is the Paris day');

select * from finish();
rollback;
