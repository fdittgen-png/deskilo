-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4164 B1: a billing-access grant. The seller invites one billing-only subject (its request id replays; a coworker
-- without the right, and a member subject, are refused); the account previews and accepts it (a replay answers the
-- same grant; another account, an expired or a revoked code get one answer); the account then reads that subject's
-- invoices and no other's, without becoming a member; one account holds two subjects apart; a revocation by the
-- account or the seller ends the reading and erases nothing. Rolled back.
begin;
select plan(23);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000041640a1';
  u_m uuid := '00000000-0000-4000-8000-0000041640a2';
  u_c uuid := '00000000-0000-4000-8000-0000041640a3';
  u_x uuid := '00000000-0000-4000-8000-0000041640a4';
  ws uuid; m_o uuid; m_m uuid; s1 uuid; s2 uuid;
  d date;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'grant-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_m, u_c, u_x]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Grant seller', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"moneyTab": true, "invoicing": true, "billingCustomers": true, "standaloneInvoicing": true}'::jsonb)
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
  values (ws, u_o, true, true, 'active', '2026-01-01'), (ws, u_m, false, false, 'active', '2026-01-01');
  select id into m_o from public.members where workspace_id = ws and user_id = u_o;
  select id into m_m from public.members where workspace_id = ws and user_id = u_m;
  insert into public.members (workspace_id, user_id, is_admin, status, origin, subscription_pct, overage_policy)
  values (ws, null, false, 'customer', 'delegated', 0, 'blocked') returning id into s1;
  insert into public.members (workspace_id, user_id, is_admin, status, origin, subscription_pct, overage_policy)
  values (ws, null, false, 'customer', 'delegated', 0, 'blocked') returning id into s2;
  insert into public.billing_parties (member_id, workspace_id, first_name, last_name) values (s1, ws, 'Clara', 'Client');
  insert into public.billing_parties (member_id, workspace_id, company) values (s2, ws, 'Client SARL');
  d := public.workspace_today(ws);
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency,
                               member_name, workspace_name, issuer_name, signature, period, issued_at, kind,
                               source, service_date, due_on)
  values (ws, s1, m_o, 'GR-S1', 'S1', '[]'::jsonb, 1000, 'EUR', 'Clara Client', 'Grant seller', 'Owner', 'sig', null, d - 3, 'full', 'standalone', d - 3, d + 10),
         (ws, s2, m_o, 'GR-S2', 'S2', '[]'::jsonb, 2000, 'EUR', 'Client SARL', 'Grant seller', 'Owner', 'sig', null, d - 3, 'full', 'standalone', d - 3, d + 10),
         (ws, m_m, m_o, 'GR-M1', 'M1', '[]'::jsonb, 500, 'EUR', 'Mia', 'Grant seller', 'Owner', 'sig', '2026-10', '2026-10-01', 'full', 'monthly', null, null);
  perform set_config('t.ws', ws::text, true);
  perform set_config('t.s1', s1::text, true);
  perform set_config('t.s2', s2::text, true);
  perform set_config('t.m_m', m_m::text, true);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.act(p_user text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-4000-8000-0000041640' || p_user, 'role', 'authenticated')::text, true);
end $$;
create or replace function pg_temp.invite(p_subject text, p_request text) returns jsonb language sql as $$
  select public.billing_access_invite_v1(current_setting('t.ws')::uuid, current_setting(p_subject)::uuid, p_request::uuid)
$$;
create or replace function pg_temp.refusal_code(p_sql text) returns text language plpgsql as $$
begin execute p_sql; return null; exception when others then return sqlstate; end $$;
create or replace function pg_temp.seen() returns int language sql as
  $$ select count(*)::int from public.invoices where workspace_id = current_setting('t.ws')::uuid $$;
grant execute on all functions in schema pg_temp to authenticated;

-- ── The seller invites ───────────────────────────────────────────────────
select pg_temp.act('a1');
set local role authenticated;
do $$ begin
  perform set_config('t.code1', pg_temp.invite('t.s1', '00000000-0000-4000-8000-00000416a001') ->> 'code', true);
end $$;
select isnt(current_setting('t.code1', true), null, 'the owner invites the billing customer and gets a code');
select is(pg_temp.invite('t.s1', '00000000-0000-4000-8000-00000416a001') ->> 'code', current_setting('t.code1'),
  'the same request id answers the same invitation');
select is(pg_temp.refusal_code($$select pg_temp.invite('t.s2', '00000000-0000-4000-8000-00000416a001')$$),
  'DKH05', 'the same request id for another subject is refused');
select is(pg_temp.refusal_code($$select pg_temp.invite('t.m_m', '00000000-0000-4000-8000-00000416a002')$$),
  'DKH02', 'a member is not invited to billing access: they read through their membership');
select pg_temp.act('a2');
select is(pg_temp.refusal_code($$select pg_temp.invite('t.s1', '00000000-0000-4000-8000-00000416a003')$$),
  'DKN01', 'a coworker without the right does not invite');

-- ── The customer previews and accepts ────────────────────────────────────
select pg_temp.act('a3');
select is(pg_temp.seen(), 0, 'before accepting, the customer reads none of the seller''s invoices');
select is(public.billing_access_preview_v1(current_setting('t.code1')) ->> 'billed_as', 'Clara Client',
  'the preview names whom the access is for');
select is(public.billing_access_accept_v1(current_setting('t.code1')) ->> 'replayed', 'false', 'the customer accepts');
select is(public.billing_access_accept_v1(current_setting('t.code1')) ->> 'replayed', 'true',
  'accepting again answers the same grant');
select is((select string_agg(number, ',') from public.invoices where workspace_id = current_setting('t.ws')::uuid),
  'GR-S1', 'the customer reads their own subject''s invoice, and no other''s');
select is((select count(*)::int from public.members where user_id = auth.uid()), 0,
  'and is no member of the business');
select pg_temp.act('a4');
select is(pg_temp.refusal_code(format('select public.billing_access_accept_v1(%L)', current_setting('t.code1'))),
  'DKH01', 'another account cannot take an accepted invitation');
select is(pg_temp.refusal_code(format('select public.billing_access_preview_v1(%L)', current_setting('t.code1'))),
  'DKH01', 'nor read what it names');
select is(pg_temp.seen(), 0, 'and reads nothing');

-- ── A second subject for the same account ────────────────────────────────
select pg_temp.act('a1');
do $$ begin
  perform set_config('t.code2', pg_temp.invite('t.s2', '00000000-0000-4000-8000-00000416a004') ->> 'code', true);
end $$;
select pg_temp.act('a3');
select is(public.billing_access_accept_v1(current_setting('t.code2')) ->> 'financial_subject_id', current_setting('t.s2'),
  'the same account accepts the company''s access too');
select is(pg_temp.seen(), 2, 'it now reads both subjects'' invoices, each its own');
select pg_temp.act('a2');
select is((select count(*)::int from public.billing_access_grants), 0, 'a coworker reads no grant');
select is((select string_agg(number, ',') from public.invoices where workspace_id = current_setting('t.ws')::uuid),
  'GR-M1', 'a coworker still reads their own invoice only');
select pg_temp.act('a1');
select is(pg_temp.refusal_code($$select code from public.billing_access_grants limit 1$$), '42501',
  'nobody reads a code from the table: it is handed out by the invitation alone');

-- ── Revocation ───────────────────────────────────────────────────────────
select pg_temp.act('a3');
select is(public.billing_access_revoke_v1((select id from public.billing_access_grants
                                            where financial_subject_id = current_setting('t.s1')::uuid
                                              and revoked_at is null), 'not mine any more') ->> 'replayed',
  'false', 'the account gives up one access itself');
select pg_temp.act('a1');
select lives_ok($$select public.billing_access_revoke_v1((select id from public.billing_access_grants
                   where financial_subject_id = current_setting('t.s2')::uuid and revoked_at is null), 'contract ended')$$,
  'the seller revokes the other');
select pg_temp.act('a3');
select is(pg_temp.seen(), 0, 'the account reads nothing any more');
reset role;
select is((select count(*)::int from public.invoices where workspace_id = current_setting('t.ws')::uuid), 3,
  'and no invoice was erased');

select * from finish();
rollback;
