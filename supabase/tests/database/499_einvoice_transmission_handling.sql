-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0859: how an e-invoice transmission was handled (its business key, binding, dispatch owner and
-- generation, deadline, last query error, who requested and resolved it, the reason and the evidence)
-- is read by those who may issue invoices, through one reader; the member an invoice is for reads what
-- happened to it and none of those columns. A manual `failed` is admitted only once the claim of the
-- dispatch has ended; `accepted` and `rejected` stay admitted. Rolled back.
begin;
select plan(17);

create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims',
    case when p_user is null then '' else
    (jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text end, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    v := 'ERR ' || sqlstate;
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000049900c1';
  u_m uuid := '00000000-0000-4000-8000-0000049900c2';
  u_x uuid := '00000000-0000-4000-8000-0000049900c3';
  ws uuid; ws2 uuid; mo uuid; mm uuid; inv uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'handling-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_m, u_x]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Handling A', 'FR', 'EUR', 'Europe/Paris', u_o) returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Handling B', 'FR', 'EUR', 'Europe/Paris', u_x) returning id into ws2;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (ws, u_o, true, true) returning id into mo;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (ws, u_m, false, false) returning id into mm;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (ws2, u_x, true, true);
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency, member_name, workspace_name, issuer_name, signature)
  values (ws, mm, mo, 'H-1', 'September', '[]'::jsonb, 5000, 'EUR', 'M', 'W', 'O', 'sig') returning id into inv;
  perform set_config('hd.ws', ws::text, false);
  perform set_config('hd.inv', inv::text, false);
  perform set_config('hd.uo', u_o::text, false);
  perform set_config('hd.um', u_m::text, false);
  perform set_config('hd.ux', u_x::text, false);
end
$seed$;
select pg_temp.seed();

select set_config('hd.id', (public.prepare_einvoice_v1(current_setting('hd.ws')::uuid, current_setting('hd.inv')::uuid, 'generic', 'government', 'prod',
  current_setting('hd.uo')::uuid, 'T', 'facturX', 'h1', 'f.pdf', 'application/pdf', '', '', '\x01'::bytea) ->> 'id'), false);
select public.claim_einvoice_dispatch_v1(current_setting('hd.id')::uuid, current_setting('hd.uo')::uuid, 150);
select public.record_einvoice_outcome_v1(current_setting('hd.id')::uuid, 1, current_setting('hd.uo')::uuid, 'uncertain', '', '', '{}');

-- ── what the invoiced member reads ──
select is(pg_temp.run_as(current_setting('hd.um')::uuid, format($q$select phase from public.invoice_transmissions where invoice_id = %L$q$, current_setting('hd.inv'))), 'uncertain',
  'the member an invoice is for reads what happened to it');
select is(pg_temp.run_as(current_setting('hd.um')::uuid, format($q$select external_id || document_hash from public.invoice_transmissions where invoice_id = %L$q$, current_setting('hd.inv'))) like 'ERR%', false,
  'with its provider, external id and document hash');
select is(pg_temp.run_as(current_setting('hd.um')::uuid, format($q$select business_key from public.invoice_transmissions where invoice_id = %L$q$, current_setting('hd.inv'))), 'ERR 42501',
  'but not the business key');
select is(pg_temp.run_as(current_setting('hd.um')::uuid, format($q$select resolved_reason from public.invoice_transmissions where invoice_id = %L$q$, current_setting('hd.inv'))), 'ERR 42501', 'nor the reason of a resolution');
select is(pg_temp.run_as(current_setting('hd.um')::uuid, format($q$select resolved_evidence from public.invoice_transmissions where invoice_id = %L$q$, current_setting('hd.inv'))), 'ERR 42501', 'nor its evidence');
select is(pg_temp.run_as(current_setting('hd.um')::uuid, format($q$select query_error from public.invoice_transmissions where invoice_id = %L$q$, current_setting('hd.inv'))), 'ERR 42501', 'nor the last query error');
select is(pg_temp.run_as(current_setting('hd.um')::uuid, format($q$select requested_by::text from public.invoice_transmissions where invoice_id = %L$q$, current_setting('hd.inv'))), 'ERR 42501', 'nor who requested it');
select is(pg_temp.run_as(current_setting('hd.um')::uuid, format($q$select resolved_by::text from public.invoice_transmissions where invoice_id = %L$q$, current_setting('hd.inv'))), 'ERR 42501', 'nor who resolved it');
select is(pg_temp.run_as(current_setting('hd.um')::uuid, format($q$select count(*)::text from (select * from public.invoice_transmissions where invoice_id = %L) x$q$, current_setting('hd.inv'))), 'ERR 42501', 'and a whole-row read is refused');

-- ── the reader of the issuers ──
select is(pg_temp.run_as(current_setting('hd.uo')::uuid, format($q$select (public.einvoice_transmission_handling_v1(%L, %L)) -> 0 ->> 'phase'$q$, current_setting('hd.ws'), current_setting('hd.inv'))), 'uncertain',
  'the issuer reads how it was handled');
select is(pg_temp.run_as(current_setting('hd.um')::uuid, format($q$select public.einvoice_transmission_handling_v1(%L, null)::text$q$, current_setting('hd.ws'))), 'ERR 42501', 'the member does not');
select is(pg_temp.run_as(current_setting('hd.ux')::uuid, format($q$select public.einvoice_transmission_handling_v1(%L, null)::text$q$, current_setting('hd.ws'))), 'ERR 42501', 'nor does another business');
select is(pg_temp.run_as(current_setting('hd.uo')::uuid, format($q$select public.einvoice_transmission_handling_v1(%L, null)::text$q$, current_setting('hd.ws')), true), 'ERR 42501', 'nor does an assistant session');

-- ── a manual failed waits for the end of the claim ──
select is((public.resolve_einvoice_manually_v1(current_setting('hd.id')::uuid, current_setting('hd.uo')::uuid, 'failed', 'checked', 'the provider has no trace') ->> 'detail'), 'claim_live',
  'a manual failed while the claim is live is refused');
select is((select phase from public.invoice_transmissions where id = current_setting('hd.id')::uuid), 'uncertain', 'and the row stays uncertain, never claimable');
update public.invoice_transmissions set deadline = now() - interval '1 minute' where id = current_setting('hd.id')::uuid;
select is((public.resolve_einvoice_manually_v1(current_setting('hd.id')::uuid, current_setting('hd.uo')::uuid, 'failed', 'checked', 'the provider has no trace') ->> 'resolved'), 'true',
  'once the claim has ended it is admitted');
select is(pg_temp.run_as(current_setting('hd.uo')::uuid, format($q$select (public.einvoice_transmission_handling_v1(%L, %L)) -> 0 ->> 'resolved_reason'$q$, current_setting('hd.ws'), current_setting('hd.inv'))), 'checked',
  'and the issuer reads its reason');

select * from finish();
rollback;
