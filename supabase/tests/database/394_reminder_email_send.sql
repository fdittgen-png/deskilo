-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3673 (0726): a payment reminder leaves by e-mail at most once per invoice
-- and level. Only a native session of someone who issues invoices opens an
-- attempt, with the feature on, the sender configured, the customer's
-- address on file and the level the rules give now; the same attempt id
-- replays it. Only the service role records the provider's answer:
-- accepted counts the reminder with its e-mail evidence, refused counts
-- nothing and frees the level, unconfirmed fences it until a person
-- decides. Rolled back.
begin;
select plan(22);

do $seed$
declare ws uuid := '00000000-0000-4000-8000-0000003673b1';
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select ('00000000-0000-4000-8000-0000003673' || s)::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated',
         'authenticated', s || '@remind.test', '', now(), now(), now()
    from unnest(array['a1', 'a2', 'a3']) s;
  insert into public.profiles (id, email) values
    ('00000000-0000-4000-8000-0000003673a1', 'a1@remind.test'),
    ('00000000-0000-4000-8000-0000003673a2', 'a2@remind.test'),
    ('00000000-0000-4000-8000-0000003673a3', '')
  on conflict (id) do update set email = excluded.email;
  insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, dunning_rules)
  values (ws, 'Remind', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-0000003673a1',
          '{"moneyTab": true, "invoicing": true, "dunning": true, "paymentReminders": true, "reminderEmail": false}',
          '{"levels": 3, "first_after_days": 30, "between_days": 14, "automatic": false}');
  insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
    ('00000000-0000-4000-8000-0000003673c1', ws, '00000000-0000-4000-8000-0000003673a1', true, true, 'active'),
    ('00000000-0000-4000-8000-0000003673c2', ws, '00000000-0000-4000-8000-0000003673a2', false, false, 'active'),
    ('00000000-0000-4000-8000-0000003673c3', ws, '00000000-0000-4000-8000-0000003673a3', false, false, 'active');
  -- f1, f2, f4 are addressed to a member with an address; f3 to one without.
  insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                               currency, member_name, workspace_name, issuer_name, signature, issued_at)
  select ('00000000-0000-4000-8000-0000003673' || k)::uuid, ws,
         case when k = 'f3' then '00000000-0000-4000-8000-0000003673c3'::uuid
              else '00000000-0000-4000-8000-0000003673c2'::uuid end,
         '00000000-0000-4000-8000-0000003673c1', 'RM-' || k, 'T', '[]'::jsonb, 12000, 'EUR', 'A', 'Remind',
         'Owner', 'sig', now() - interval '40 days'
    from unnest(array['f1', 'f2', 'f3', 'f4']) k;
end;
$seed$;

create or replace function pg_temp.j(p text) returns jsonb language plpgsql as $f$
begin
  return p::jsonb;
exception when others then
  return jsonb_build_object('state', p, 'level', p, 'reason', p, 'recipient', p, 'available', false, 'error', p);
end
$f$;
create or replace function pg_temp.as_user(p_user text, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', (case when p_delegated
    then json_build_object('sub', '00000000-0000-4000-8000-0000003673' || p_user, 'role', 'authenticated',
                           'client_id', 'delegated')
    else json_build_object('sub', '00000000-0000-4000-8000-0000003673' || p_user, 'role', 'authenticated') end)::text, true);
  set local role authenticated;
  execute p_sql into v;
  reset role;
  return coalesce(v, 'null');
exception when others then
  reset role;
  return 'ERROR: ' || sqlerrm;
end
$f$;
create or replace function pg_temp.begin_(p_user text, p_invoice text, p_level int, p_attempt text,
                                          p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.as_user(p_user, format(
    'select public.begin_reminder_email_v1(''00000000-0000-4000-8000-0000003673b1'', %L, %s, ''fr'', %L)::text',
    '00000000-0000-4000-8000-0000003673' || p_invoice, p_level, '00000000-0000-4000-8000-0000003673e' || p_attempt),
    p_delegated)
$f$;
create or replace function pg_temp.target(p_invoice text) returns jsonb language sql as $f$
  select pg_temp.j(pg_temp.as_user('a1', format(
    'select public.reminder_email_target_v1(''00000000-0000-4000-8000-0000003673b1'', %L)::text',
    '00000000-0000-4000-8000-0000003673' || p_invoice)))
$f$;
create or replace function pg_temp.sent(p_invoice text) returns int language sql as $f$
  select count(*)::int from public.invoice_reminders
   where invoice_id = ('00000000-0000-4000-8000-0000003673' || p_invoice)::uuid
$f$;
create or replace function pg_temp.finish(p_attempt text, p_outcome text, p_provider text, p_reason text)
returns text language plpgsql as $f$
begin
  return public.finish_reminder_email(('00000000-0000-4000-8000-0000003673e' || p_attempt)::uuid,
                                      p_outcome, p_provider, p_reason)::text;
exception when others then
  return 'ERROR: ' || sqlerrm;
end
$f$;

-- ── who may open an attempt ─────────────────────────────────────────
select is(pg_temp.begin_('a1', 'f1', 1, '1'), 'ERROR: reminders by e-mail are off in this space',
          'with the feature off, nothing is e-mailed');
update public.workspaces set feature_flags = feature_flags || '{"reminderEmail": true}'
 where id = '00000000-0000-4000-8000-0000003673b1';
select is(pg_temp.target('f1') ->> 'reason', 'sender_not_configured',
          'without a configured sender the channel is not offered, and the answer says why');
insert into public.purchase_order_mail_settings (workspace_id, sender_email, sender_name, has_api_key)
values ('00000000-0000-4000-8000-0000003673b1', 'billing@remind.test', 'Remind', true);
select ok((pg_temp.target('f1') ->> 'available')::boolean and pg_temp.target('f1') ->> 'recipient' = 'a2@remind.test',
          'with it, the channel is offered and names the customer''s address');
select ok(not (pg_temp.target('f3') ->> 'available')::boolean and pg_temp.target('f3') ->> 'reason' = 'no_address',
          'a customer without an address on file is not offered the channel, and the answer says why');
select is(pg_temp.begin_('a2', 'f1', 1, '1'), 'ERROR: not allowed', 'a member who issues no invoices cannot send');
select is(pg_temp.begin_('a1', 'f1', 1, '1', true), 'ERROR: not allowed', 'an assistant''s delegated session cannot send');
select is(pg_temp.begin_('a1', 'f3', 1, '1'), 'ERROR: the customer has no e-mail address on file',
          'a customer without an address is refused by the server too');
select is(pg_temp.begin_('a1', 'f1', 2, '1'), 'ERROR: the reminder level changed',
          'a level the rules do not give now is refused');

-- ── once: the attempt, its replay, the fence ─────────────────────────
select is(pg_temp.j((pg_temp.begin_('a1', 'f1', 1, '1'))) ->> 'state', 'pending', 'the issuer opens the attempt');
select is(pg_temp.j((pg_temp.begin_('a1', 'f1', 1, '1'))) ->> 'state', 'pending', 'the same attempt id replays it');
select is((select count(*)::int from public.reminder_email_sends
            where invoice_id = '00000000-0000-4000-8000-0000003673f1'), 1, 'without a second attempt');
select is(pg_temp.begin_('a1', 'f1', 1, '2'),
          'ERROR: an earlier e-mail of this reminder has no confirmed outcome: check before sending again',
          'a second attempt while the first has no outcome is refused');
select is(pg_temp.as_user('a1', $q$select public.finish_reminder_email('00000000-0000-4000-8000-0000003673e1', 'accepted', 'x', '')::text$q$),
          'ERROR: permission denied for function finish_reminder_email', 'only the service role records an answer');

-- ── accepted: the reminder counts, with its e-mail evidence ─────────
select is(pg_temp.j(pg_temp.finish('1', 'accepted', 'prov-1', '')) ->> 'state', 'accepted', 'the provider''s acceptance is recorded');
select ok(pg_temp.sent('f1') = 1
          and (select ri.status = 'provider_accepted' and a.outcome = 'provider_accepted'
                      and a.detail like '%a2@remind.test%' and a.detail like '%prov-1%'
                 from public.reminder_email_sends s join public.reminder_intents ri on ri.id = s.intent_id
                 join public.reminder_attempts a on a.intent_id = ri.id and a.channel = 'email'
                where s.id = '00000000-0000-4000-8000-0000003673e1'),
          'the reminder is counted once, and its evidence says to whom, with which provider id and outcome');
select ok(pg_temp.j(pg_temp.finish('1', 'accepted', 'prov-1', '')) ->> 'state' = 'accepted' and pg_temp.sent('f1') = 1,
          'a repeated answer is a replay: no second reminder');
select is(pg_temp.finish('1', 'refused', '', 'late'), 'ERROR: this attempt already has its outcome',
          'a different answer after the first is refused');
select throws_ok($$insert into public.reminder_email_sends (id, workspace_id, invoice_id, intent_id, level, state, recipient, language, actor_member_id)
                   select gen_random_uuid(), workspace_id, invoice_id, intent_id, level, 'accepted', recipient, language, actor_member_id
                     from public.reminder_email_sends where id = '00000000-0000-4000-8000-0000003673e1'$$,
                 '23505', null, 'a second e-mail of the same invoice and level cannot exist');

-- ── refused: nothing counted, the level can be e-mailed again ───────
-- (each call is its own statement: an uncorrelated subquery would run first)
do $s$ begin
  perform set_config('t.b3', pg_temp.j(pg_temp.begin_('a1', 'f2', 1, '3')) ->> 'state', false);
  perform set_config('t.f3', pg_temp.j(pg_temp.finish('3', 'refused', '', 'invalid_from')) ->> 'state', false);
end $s$;
select ok(current_setting('t.b3') = 'pending' and current_setting('t.f3') = 'refused'
          and pg_temp.sent('f2') = 0
          and (select ri.status = 'failed' and a.outcome = 'failed' and a.detail like '%invalid_from%'
                 from public.reminder_email_sends s join public.reminder_intents ri on ri.id = s.intent_id
                 join public.reminder_attempts a on a.intent_id = ri.id and a.channel = 'email'
                where s.id = '00000000-0000-4000-8000-0000003673e3'),
          'a refusal counts no reminder and is kept as a failed attempt with its reason');
select is(pg_temp.j(pg_temp.begin_('a1', 'f2', 1, '4')) ->> 'level', '1', 'after a refusal the same level can be e-mailed again');

-- ── unconfirmed: fenced until a person decides ──────────────────────
do $s$ begin
  perform set_config('t.b5', pg_temp.j(pg_temp.begin_('a1', 'f4', 1, '5')) ->> 'state', false);
  perform set_config('t.f5', pg_temp.j(pg_temp.finish('5', 'unconfirmed', '', 'no confirmed answer')) ->> 'state', false);
  perform set_config('t.b6', pg_temp.begin_('a1', 'f4', 1, '6'), false);
end $s$;
select ok(current_setting('t.b5') = 'pending' and current_setting('t.f5') = 'unconfirmed'
          and pg_temp.sent('f4') = 0
          and current_setting('t.b6') like 'ERROR: an earlier e-mail%',
          'an unconfirmed e-mail counts nothing and fences the next attempt');
do $s$ begin
  perform set_config('t.r2', pg_temp.as_user('a2', $q$select public.resolve_reminder_email_v1('00000000-0000-4000-8000-0000003673b1', '00000000-0000-4000-8000-0000003673e5', true)::text$q$), false);
  perform set_config('t.r1', pg_temp.j(pg_temp.as_user('a1', $q$select public.resolve_reminder_email_v1('00000000-0000-4000-8000-0000003673b1', '00000000-0000-4000-8000-0000003673e5', true)::text$q$)) ->> 'state', false);
end $s$;
select ok(current_setting('t.r2') = 'ERROR: not allowed' and current_setting('t.r1') = 'delivered'
          and pg_temp.sent('f4') = 1
          and exists (select 1 from public.reminder_attempts a join public.reminder_email_sends s on s.intent_id = a.intent_id
                       where s.id = '00000000-0000-4000-8000-0000003673e5' and a.channel = 'email'
                         and a.outcome = 'declared_delivered'),
          'only an issuer decides it; delivered counts the reminder as a person''s declaration');

select * from finish();
rollback;
