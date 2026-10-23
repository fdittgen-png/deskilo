-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- #2941 — who may read a shared template, and who may read an invoice
-- inside one workspace.
--
-- Part one: a template shared by grant is read only by the account whose
-- CONFIRMED e-mail is the grantee. A profile e-mail the caller edited
-- themselves grants nothing, and neither does an account that has not
-- confirmed the address — even when its JWT carries it. The confirmed
-- grantee and the owner keep reading it, so "nothing is readable" cannot
-- pass this file.
--
-- Part two (the threat model's T2 gap): an invoice is read by its
-- recipient, the owner and an admin the role matrix gives `viewFinances`;
-- not by another member of the same workspace, a narrowed admin, or a
-- member of another workspace.
--
-- Everything is seeded as `postgres` first; the reads then run under
-- `set local role authenticated` with real JWT claims, and `reset role`
-- comes back before every switch (13_matrix_policies.sql). As `postgres`
-- every policy is bypassed and the counts would prove nothing.
begin;
select plan(29);

create or replace function pg_temp.keys() returns text[] language sql immutable as $q$
  select array['towner', 'victim', 'attacker', 'pending', 'changer', 'other',
               'noprofile', 'selfentered', 'owner', 'a', 'b', 'admin', 'issuer',
               'stranger'];
$q$;

create or replace function pg_temp.uid(p_key text) returns uuid language sql immutable as $q$
  select ('00000000-0000-4000-8000-0002941' ||
          lpad(array_position(pg_temp.keys(), p_key)::text, 5, '0'))::uuid;
$q$;

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  v_key text;
  ws_t uuid; ws uuid; ws_x uuid; m_issuer uuid; m_a uuid; tpl uuid; inv uuid;
begin
  -- One account per role, id and address derived from its key. The
  -- profile comes from the trigger on `auth.users`; never insert it.
  -- `pending` has never confirmed its address; `selfentered` has none.
  insert into auth.users (id, instance_id, aud, role, email,
                          encrypted_password, email_confirmed_at,
                          created_at, updated_at)
  select pg_temp.uid(k), '00000000-0000-0000-0000-000000000000',
         'authenticated', 'authenticated',
         case when k = 'selfentered' then null else 'g2941-' || k || '@deskilo.test' end,
         '', case when k in ('pending', 'selfentered') then null else now() end,
         now(), now()
    from unnest(pg_temp.keys()) k;

  -- `changer` has asked to move to the grantee's address and not yet
  -- confirmed it: the pending address sits in `email_change`.
  update auth.users set email_change = 'g2941-victim@deskilo.test'
   where id = pg_temp.uid('changer');
  -- An account whose profile row is gone.
  delete from public.profiles where id = pg_temp.uid('noprofile');
  -- An account whose only address is the one it typed into its profile.
  update public.profiles set email = 'g2941-selfentered@deskilo.test'
   where id = pg_temp.uid('selfentered');

  -- ── the template ──────────────────────────────────────────────────
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Grant 2941 owner', 'FR', 'EUR', 'Europe/Paris', pg_temp.uid('towner'))
  returning id into ws_t;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws_t, pg_temp.uid('towner'), true, true);
  insert into public.workspace_templates (key, name, visibility, owner_workspace_id)
  values ('g2941_shared', 'Grant 2941 shared', 'shared', ws_t) returning id into tpl;
  insert into public.workspace_template_grants (template_id, grantee_email)
  values (tpl, 'g2941-victim@deskilo.test'), (tpl, 'g2941-pending@deskilo.test');

  -- ── one workspace, one invoice to A, issued by a plain member ─────
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Grant 2941 space', 'FR', 'EUR', 'Europe/Paris', pg_temp.uid('owner'))
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, pg_temp.uid('owner'), true, true), (ws, pg_temp.uid('b'), false, false),
         (ws, pg_temp.uid('admin'), false, true);
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, pg_temp.uid('a'), false, false) returning id into m_a;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, pg_temp.uid('issuer'), false, false) returning id into m_issuer;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature)
  values (ws, m_a, m_issuer, 'G2941-1', 'A', '[]'::jsonb, 10000, 'EUR', 'A',
          'Grant 2941 space', 'Issuer', 'sig') returning id into inv;

  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Grant 2941 elsewhere', 'FR', 'EUR', 'Europe/Paris', pg_temp.uid('stranger'))
  returning id into ws_x;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws_x, pg_temp.uid('stranger'), true, true);

  perform set_config('g2941.tpl', tpl::text, true);
  perform set_config('g2941.inv', inv::text, true);
  perform set_config('g2941.ws', ws::text, true);
  foreach v_key in array pg_temp.keys() loop
    perform set_config('g2941.' || v_key, pg_temp.uid(v_key)::text, true);
  end loop;
end
$seed$;

-- Signed in as [who], with the e-mail claim that account's JWT would
-- carry. Called as `postgres`, before `set local role`.
create or replace function pg_temp.be(p_who text, p_email text) returns void
language plpgsql as $be$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('g2941.' || p_who),
                      'role', 'authenticated', 'email', p_email)::text, true);
  perform set_config('request.jwt.claim.sub', current_setting('g2941.' || p_who), true);
end;
$be$;

-- The template, through its RLS policy.
create or replace function pg_temp.template_rows() returns int language sql as $q$
  select count(*)::int from public.workspace_templates
   where id = current_setting('g2941.tpl')::uuid;
$q$;
grant execute on function pg_temp.template_rows() to authenticated;

-- A's invoice, through its RLS policy.
-- The grant rows of the template, through their RLS policy.
create or replace function pg_temp.grant_rows() returns int language sql as $q$
  select count(*)::int from public.workspace_template_grants
   where template_id = current_setting('g2941.tpl')::uuid;
$q$;
grant execute on function pg_temp.grant_rows() to authenticated;

create or replace function pg_temp.invoice_rows() returns int language sql as $q$
  select count(*)::int from public.invoices
   where id = current_setting('g2941.inv')::uuid;
$q$;
grant execute on function pg_temp.invoice_rows() to authenticated;

select pg_temp.seed();

-- ------------------------------------------------------------ the attacker
-- `profiles_update` lets them write their own row: that is the premise.
select pg_temp.be('attacker', 'g2941-attacker@deskilo.test');
set local role authenticated;

update public.profiles set email = 'g2941-victim@deskilo.test' where id = auth.uid();

select ok(not public.workspace_template_readable(current_setting('g2941.tpl')::uuid),
  'a profile e-mail edited to the grantee''s address does not make the template readable');
select is(pg_temp.template_rows(), 0,
  'and the template stays invisible through its policy');
select ok(public.search_workspace_templates('Grant 2941', '{}', '{}', 25, null)::text
            not like '%' || current_setting('g2941.tpl') || '%',
  'and the server''s template search does not list it');
select is(pg_temp.grant_rows(), 0,
  'nor does it show the grant row that names the grantee''s address');

reset role;
select is((select email from public.profiles
            where id = current_setting('g2941.attacker')::uuid),
  'g2941-victim@deskilo.test',
  'the attacker''s profile really carries the grantee''s address');

-- ------------------------------------------------------------ the confirmed grantee
select pg_temp.be('victim', 'g2941-victim@deskilo.test');
set local role authenticated;

select ok(public.workspace_template_readable(current_setting('g2941.tpl')::uuid),
  'the account whose confirmed e-mail is the grantee reads the template');
select is(pg_temp.template_rows(), 1, 'and sees its row');
select is(pg_temp.grant_rows(), 1,
  'and sees the grant that names them, not the one naming somebody else');

reset role;

-- ------------------------------------------------------------ an unconfirmed grantee
-- The JWT carries the granted address; the account never confirmed it.
select pg_temp.be('pending', 'g2941-pending@deskilo.test');
set local role authenticated;

select is(pg_temp.template_rows(), 0,
  'an account that has not confirmed the granted address cannot read the template');

reset role;

-- ------------------------------------------------------------ the template's owner
select pg_temp.be('towner', 'g2941-towner@deskilo.test');
set local role authenticated;

select is(pg_temp.template_rows(), 1, 'the owner of the template''s workspace still reads it');

reset role;

-- ------------------------------------------------------------ a pending e-mail change
-- Confirmed address is their own; the grantee's address is only asked
-- for, in `email_change`.
select pg_temp.be('changer', 'g2941-changer@deskilo.test');
set local role authenticated;
select is(pg_temp.template_rows(), 0,
  'an unconfirmed e-mail change to the grantee''s address grants nothing');
reset role;

-- ------------------------------------------------------------ strangers to the grant
select pg_temp.be('other', 'g2941-other@deskilo.test');
set local role authenticated;
select is(pg_temp.template_rows(), 0, 'an unrelated signed-in account cannot read it');
reset role;

select pg_temp.be('noprofile', 'g2941-noprofile@deskilo.test');
set local role authenticated;
select is(pg_temp.template_rows(), 0, 'an account with no profile row cannot read it');
reset role;

-- ------------------------------------------------------------ a stale session
-- The grantee moves their confirmed address away; a session minted
-- before still carries the old address as its e-mail claim.
update auth.users set email = 'g2941-victim-moved@deskilo.test'
 where id = current_setting('g2941.victim')::uuid;
select pg_temp.be('victim', 'g2941-victim@deskilo.test');
set local role authenticated;
select is(pg_temp.template_rows(), 0,
  'once the confirmed address moved away, the old e-mail claim grants nothing');
reset role;

-- ------------------------------------------------------------ the owner rule's e-mail
-- `user_has_email` is the guard behind "an owner must have an e-mail
-- address" (create_workspace, activate_co_owner). Not callable by
-- clients, so asked as `postgres`.
select ok(not public.user_has_email(current_setting('g2941.selfentered')::uuid),
  'an address typed into one''s own profile does not satisfy the owner e-mail rule');
select ok(public.user_has_email(current_setting('g2941.owner')::uuid),
  'a confirmed account e-mail does');

-- ------------------------------------------------------------ invoice privacy (T2)
select pg_temp.be('a', 'g2941-a@deskilo.test');
set local role authenticated;
select is(pg_temp.invoice_rows(), 1, 'the recipient reads their invoice');
reset role;

select pg_temp.be('b', 'g2941-b@deskilo.test');
set local role authenticated;
select is(pg_temp.invoice_rows(), 0,
  'another active member of the same workspace sees no row of it');
reset role;

select pg_temp.be('owner', 'g2941-owner@deskilo.test');
set local role authenticated;
select is(pg_temp.invoice_rows(), 1, 'the owner reads it');
reset role;

-- The issuer is a plain member here: no ownership, no admin flag, no
-- finance permission. `may_view_member_finances` asks about the
-- RECIPIENT (`member_id`) only — the recipient themselves, or
-- viewFinances/issueInvoices — so having issued the invoice is not a
-- reason to read it. That is the intended rule.
select pg_temp.be('issuer', 'g2941-issuer@deskilo.test');
set local role authenticated;
select is(pg_temp.invoice_rows(), 0,
  'the member who issued it, without a finance permission, sees no row of it');
reset role;

update public.workspaces set role_permissions = '{"admin": ["viewFinances"]}'::jsonb
 where id = current_setting('g2941.ws')::uuid;
select pg_temp.be('admin', 'g2941-admin@deskilo.test');
set local role authenticated;
select is(pg_temp.invoice_rows(), 1, 'an admin the matrix gives viewFinances reads it');
reset role;

-- Neither viewFinances nor issueInvoices: `may_view_member_finances`
-- accepts both, so the narrowed row must hold neither.
update public.workspaces set role_permissions = '{"admin": []}'::jsonb
 where id = current_setting('g2941.ws')::uuid;
select pg_temp.be('admin', 'g2941-admin@deskilo.test');
set local role authenticated;
select is(pg_temp.invoice_rows(), 0, 'an admin without viewFinances does not');
reset role;

select pg_temp.be('stranger', 'g2941-stranger@deskilo.test');
set local role authenticated;
select is(pg_temp.invoice_rows(), 0, 'a member of another workspace sees no row of it');
reset role;

-- ------------------------------------------------------------ the signature check
-- `verify_invoice_signature` answers who may read the invoice, and an
-- invoice one may not read is refused exactly like one that does not
-- exist: same code, same words, so an id's existence is not disclosed.
select pg_temp.be('a', 'g2941-a@deskilo.test');
set local role authenticated;
select ok(public.verify_invoice_signature(current_setting('g2941.inv')::uuid)
            in ('verified', 'unverifiable', 'altered'),
  'the recipient gets the signature state of their invoice');
select throws_ok(
  'select public.verify_invoice_signature(''00000000-0000-4000-8000-0000002941ff'')',
  'P0001', 'unknown invoice',
  'an id that does not exist is an unknown invoice');
reset role;

select pg_temp.be('owner', 'g2941-owner@deskilo.test');
set local role authenticated;
select ok(public.verify_invoice_signature(current_setting('g2941.inv')::uuid)
            in ('verified', 'unverifiable', 'altered'),
  'the owner gets it too');
reset role;

select pg_temp.be('b', 'g2941-b@deskilo.test');
set local role authenticated;
select throws_ok(
  format('select public.verify_invoice_signature(%L)', current_setting('g2941.inv')),
  'P0001', 'unknown invoice',
  'another member of the same workspace is told exactly what an unknown id gets');
reset role;

select pg_temp.be('stranger', 'g2941-stranger@deskilo.test');
set local role authenticated;
select throws_ok(
  format('select public.verify_invoice_signature(%L)', current_setting('g2941.inv')),
  'P0001', 'unknown invoice',
  'and so is a member of another workspace');
reset role;

select is((select count(*)::int from public.invoices
            where id = current_setting('g2941.inv')::uuid), 1,
  'the invoice exists, so every 0 above is a refusal, not an empty table');

select * from finish();
rollback;
