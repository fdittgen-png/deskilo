-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3673 (0729): an issued invoice leaves by e-mail once; "send again" is
-- its own deliberate attempt, only after the first left. Only a native
-- session of someone who issues invoices opens an attempt or reads the
-- invoice page's state, and a replay is checked against those rights
-- first. A voided invoice is never e-mailed; no attempt opens while one has
-- no outcome; an old pending attempt is never sent again. An e-mailed
-- invoice adds no event and no push. The sender may be set when only
-- invoices by e-mail are on. Rolled back.
begin;
select plan(17);

do $seed$
declare ws uuid := '00000000-0000-4000-8000-0000036731b1';
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select ('00000000-0000-4000-8000-000003673' || s)::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated',
         'authenticated', s || '@invoice.test', '', now(), now(), now()
    from unnest(array['1a1', '1a2', '1a3']) s;
  insert into public.profiles (id, email) values
    ('00000000-0000-4000-8000-0000036731a1', 'a1@invoice.test'),
    ('00000000-0000-4000-8000-0000036731a2', 'a2@invoice.test'),
    ('00000000-0000-4000-8000-0000036731a3', '')
  on conflict (id) do update set email = excluded.email;
  insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags)
  values (ws, 'Invoice', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-0000036731a1',
          '{"moneyTab": true, "invoicing": true, "invoiceEmail": false, "purchaseOrders": false, "reminderEmail": false}');
  insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
    ('00000000-0000-4000-8000-0000036731c1', ws, '00000000-0000-4000-8000-0000036731a1', true, true, 'active'),
    ('00000000-0000-4000-8000-0000036731c2', ws, '00000000-0000-4000-8000-0000036731a2', false, false, 'active'),
    ('00000000-0000-4000-8000-0000036731c3', ws, '00000000-0000-4000-8000-0000036731a3', false, false, 'active');
  -- f1, f2, f4 to a member with an address; f3 to one without; f5 voided.
  insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                               currency, member_name, workspace_name, issuer_name, signature, issued_at)
  select ('00000000-0000-4000-8000-0000036731' || k)::uuid, ws,
         case when k = 'f3' then '00000000-0000-4000-8000-0000036731c3'::uuid
              else '00000000-0000-4000-8000-0000036731c2'::uuid end,
         '00000000-0000-4000-8000-0000036731c1', 'IE-' || k, 'T', '[]'::jsonb, 12000, 'EUR', 'A', 'Invoice',
         'Owner', 'sig', now() - interval '5 days'
    from unnest(array['f1', 'f2', 'f3', 'f4', 'f5']) k;
  alter table public.invoices disable trigger user;
  update public.invoices set voided_at = now() where id = '00000000-0000-4000-8000-0000036731f5';
  alter table public.invoices enable trigger user;
  perform set_config('t.sent', 'fixture_key_729001', false);
end;
$seed$;

create or replace function pg_temp.as_user(p_user text, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', (case when p_delegated
    then json_build_object('sub', '00000000-0000-4000-8000-000003673' || p_user, 'role', 'authenticated', 'client_id', 'delegated')
    else json_build_object('sub', '00000000-0000-4000-8000-000003673' || p_user, 'role', 'authenticated') end)::text, true);
  set local role authenticated;
  execute p_sql into v;
  reset role;
  return coalesce(v, 'null');
exception when others then
  reset role;
  return 'ERROR: ' || sqlerrm;
end
$f$;
create or replace function pg_temp.j(p text) returns jsonb language plpgsql as $f$
begin
  return p::jsonb;
exception when others then
  return jsonb_build_object('state', p, 'reason', p, 'kind', p, 'error', p, 'available', false);
end
$f$;
create or replace function pg_temp.begin_(p_user text, p_invoice text, p_kind text, p_attempt text,
                                          p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.as_user(p_user, format(
    'select public.begin_invoice_email_v1(''00000000-0000-4000-8000-0000036731b1'', %L, %L, ''fr'', %L)::text',
    '00000000-0000-4000-8000-0000036731' || p_invoice, p_kind, '00000000-0000-4000-8000-0000036731e' || p_attempt),
    p_delegated)
$f$;
create or replace function pg_temp.state_(p_user text, p_invoice text, p_delegated boolean default false)
returns jsonb language sql as $f$
  select pg_temp.j(pg_temp.as_user(p_user, format(
    'select public.invoice_email_state_v1(''00000000-0000-4000-8000-0000036731b1'', %L)::text',
    '00000000-0000-4000-8000-0000036731' || p_invoice), p_delegated))
$f$;
create or replace function pg_temp.finish(p_attempt text, p_outcome text) returns text language plpgsql as $f$
begin
  return public.finish_invoice_email(('00000000-0000-4000-8000-0000036731e' || p_attempt)::uuid,
                                     p_outcome, case when p_outcome = 'accepted' then 'prov-' || p_attempt else '' end,
                                     case when p_outcome = 'refused' then 'provider_422' else '' end)::text;
exception when others then
  return 'ERROR: ' || sqlerrm;
end
$f$;
create or replace function pg_temp.events() returns int language sql as $f$
  select count(*)::int from public.events where workspace_id = '00000000-0000-4000-8000-0000036731b1'
$f$;

-- ── who may ask, and when ───────────────────────────────────────────
select is(pg_temp.begin_('1a1', 'f1', 'first', '1'), 'ERROR: invoices by e-mail are off in this space',
          'with the feature off, nothing is e-mailed');
update public.workspaces set feature_flags = feature_flags || '{"invoiceEmail": true}'
 where id = '00000000-0000-4000-8000-0000036731b1';
select is(pg_temp.as_user('1a1', format(
            'select (public.save_business_mail_sender_v1(''00000000-0000-4000-8000-0000036731b1'', ''billing@invoice.test'', ''Invoice'', %L, null) ->> ''sender_email'')',
            current_setting('t.sent'))),
          'billing@invoice.test', 'with invoices by e-mail alone on, the billing manager sets the sender');
select ok(pg_temp.state_('1a2', 'f1') ->> 'error' = 'ERROR: not allowed'
          and pg_temp.state_('1a1', 'f1', true) ->> 'error' = 'ERROR: not allowed',
          'the invoice page''s read answers neither a member who issues no invoices nor an assistant');
select ok((pg_temp.state_('1a1', 'f1') ->> 'available')::boolean
          and pg_temp.state_('1a1', 'f1') ->> 'recipient' = 'a2@invoice.test'
          and pg_temp.state_('1a1', 'f3') ->> 'reason' = 'no_address'
          and pg_temp.state_('1a1', 'f5') ->> 'reason' = 'voided',
          'it says to whom, or why not: no address, voided');
select is(pg_temp.begin_('1a1', 'f5', 'first', '1'), 'ERROR: a voided invoice is not e-mailed', 'a voided invoice is refused');
select is(pg_temp.begin_('1a1', 'f1', 'resend', '1'), 'ERROR: this invoice was not e-mailed yet',
          '"send again" needs a first e-mail that left');

-- ── the first e-mail, its replay, the fence ─────────────────────────
select ok(pg_temp.j(pg_temp.begin_('1a1', 'f1', 'first', '1')) ->> 'opened' = 'true'
          and pg_temp.j(pg_temp.begin_('1a1', 'f1', 'first', '1')) ->> 'opened' = 'false'
          and pg_temp.j(pg_temp.begin_('1a1', 'f1', 'first', '1')) ->> 'sendable' = 'true',
          'the issuer opens the first e-mail; the same id replays it, still sendable while young');
select is(pg_temp.begin_('1a2', 'f1', 'first', '1'), 'ERROR: not allowed',
          'a member who issues no invoices learns nothing from a known attempt id');
select is(pg_temp.begin_('1a1', 'f1', 'first', '2'),
          'ERROR: an earlier e-mail of this invoice has no confirmed outcome: check before sending again',
          'no second attempt while one has no outcome');
select is(has_function_privilege('authenticated', 'public.finish_invoice_email(uuid,text,text,text)', 'execute'),
          false, 'only the service role records an answer');
do $s$ begin perform set_config('t.before', pg_temp.events()::text, false); end $s$;
select ok(pg_temp.j(pg_temp.finish('1', 'accepted')) ->> 'state' = 'accepted'
          and pg_temp.events() = current_setting('t.before')::int,
          'the provider''s acceptance is recorded, with no event and no push');
select is(pg_temp.begin_('1a1', 'f1', 'first', '3'), 'ERROR: this invoice was already e-mailed: send it again deliberately',
          'the first e-mail leaves once');
select throws_ok($$insert into public.invoice_email_sends (id, workspace_id, invoice_id, kind, state, recipient, language, actor_member_id)
                   select gen_random_uuid(), workspace_id, invoice_id, 'first', 'accepted', recipient, language, actor_member_id
                     from public.invoice_email_sends where id = '00000000-0000-4000-8000-0000036731e1'$$,
                 '23505', null, 'a second first e-mail of the same invoice cannot exist');

-- ── send again, refused, unconfirmed, old pending ───────────────────
do $s$ begin
  perform set_config('t.r', pg_temp.j(pg_temp.begin_('1a1', 'f1', 'resend', '4')) ->> 'kind', false);
  perform pg_temp.finish('4', 'accepted');
end $s$;
select ok(current_setting('t.r') = 'resend'
          and jsonb_array_length(pg_temp.state_('1a1', 'f1') -> 'sends') = 2
          and (select count(*) from jsonb_array_elements(pg_temp.state_('1a1', 'f1') -> 'sends') e
                where e ->> 'kind' = 'resend' and e ->> 'state' = 'accepted') = 1,
          '"send again" is its own attempt and row');
do $s$ begin
  perform pg_temp.begin_('1a1', 'f2', 'first', '5');
  perform pg_temp.finish('5', 'refused');
end $s$;
select is(pg_temp.j(pg_temp.begin_('1a1', 'f2', 'first', '6')) ->> 'state', 'pending',
          'a refused first e-mail left nothing: the first can go again');
do $s$ begin
  perform pg_temp.begin_('1a1', 'f4', 'first', '7');
  perform pg_temp.finish('7', 'unconfirmed');
  perform set_config('t.d', pg_temp.as_user('1a1', $q$select public.resolve_invoice_email_v1('00000000-0000-4000-8000-0000036731b1', '00000000-0000-4000-8000-0000036731e7', true) ->> 'state'$q$), false);
end $s$;
select is(current_setting('t.d'), 'delivered', 'an unconfirmed e-mail is decided by the issuer');
alter table public.invoice_email_sends disable trigger zz_system_columns_stamp;
update public.invoice_email_sends set created_datetime = now() - interval '20 minutes'
 where id = '00000000-0000-4000-8000-0000036731e6';
alter table public.invoice_email_sends enable trigger zz_system_columns_stamp;
select is(pg_temp.j(pg_temp.begin_('1a1', 'f2', 'first', '6')) ->> 'sendable', 'false',
          'an old pending attempt is never sent again: its replay says so');

select * from finish();
rollback;
