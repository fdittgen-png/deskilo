-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4140 (0802): a member takes back a payment declaration that still waits
-- for the business. Withdrawn, its claim frees the invoices it names (another
-- payment may name them) and nothing is credited; the business reads that it
-- was withdrawn and by whom. A withdrawal is the declarer's own act: the
-- member it is for, or the member who recorded it. Anyone else (even who
-- issues the invoices), a member of another business, an unknown event or
-- one that is not a payment is refused (DKC08); a declaration already
-- confirmed, refused or withdrawn is refused with its own code (DKC13), and
-- the business cannot decide one that was withdrawn. The decision locks the
-- event it decides (the race itself is scripts/payment_claim_race.sh,
-- case i).
begin;
select plan(24);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00004140' || lpad(n::text, 4, '0'))::uuid;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'withdraw' || n || '@example.test', '', now(), now(), now()
  from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags)
values (pg_temp.u(101), 'Withdraw 4140', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
        '{"moneyTab": true, "invoicing": true, "onlinePayments": true}'),
       (pg_temp.u(102), 'Withdraw 4140 elsewhere', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4),
        '{"moneyTab": true, "invoicing": true, "onlinePayments": true}');
delete from public.validation_policies where workspace_id = pg_temp.u(101);
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active', '2026-01-01'),
       (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, false, 'active', '2026-01-01'),
       (pg_temp.u(204), pg_temp.u(102), pg_temp.u(4), true, true, 'active', '2026-01-01');
insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines,
                             total_cents, currency, member_name, workspace_name, issuer_name, signature, period, issued_at, kind)
values (pg_temp.u(301), pg_temp.u(101), pg_temp.u(202), pg_temp.u(201), 'WD-1', 'One', '[]'::jsonb, 5000, 'EUR',
        'Ada', 'Withdraw 4140', 'Owner', 'sig', '2026-10', '2026-10-01', 'full'),
       (pg_temp.u(302), pg_temp.u(101), pg_temp.u(202), pg_temp.u(201), 'WD-2', 'Two', '[]'::jsonb, 3000, 'EUR',
        'Ada', 'Withdraw 4140', 'Owner', 'sig', '2026-11', '2026-11-01', 'full');
-- Ada's own pending request of another type: not a payment, never withdrawn here
insert into public.events (id, workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
values (pg_temp.u(401), pg_temp.u(101), 'quota', 'submitted', pg_temp.u(202), pg_temp.u(202), '{"half_days": 2}', 'pending');

-- Runs [p_sql] as user [n]; its text, or 'ok' for none, or 'ERR <sqlstate>'.
create function pg_temp.as_user(n int, p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(n), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  execute 'reset role';
  return coalesce(nullif(v, ''), 'ok');
exception when others then
  execute 'reset role';
  return 'ERR ' || sqlstate;
end $f$;
-- the business's own day, not the database session's: they differ for a few hours a day
select set_config('t.today', public.workspace_today(pg_temp.u(101))::text, false);
-- User [n] declares Ada's [p_invoice] paid ([p_cents], [p_period]); the event's id.
create function pg_temp.declare_paid(n int, p_invoice uuid, p_cents int, p_period text) returns text language sql as $$
  select pg_temp.as_user(n, format(
    'select public.record_payment(%L, %L, %s, %L, %L, current_setting(''t.today'')::date, %L, array[%L]::uuid[])::text',
    pg_temp.u(101), pg_temp.u(202), p_cents, '', 'transfer', p_period, p_invoice));
$$;
create function pg_temp.withdraw(n int, p_event text) returns text language sql as $$
  select pg_temp.as_user(n, format('select public.withdraw_payment_declaration(%L)::text', p_event));
$$;
create function pg_temp.claimed(p_invoice uuid) returns boolean language sql as $$
  select exists (select 1 from public.open_claim_invoices(pg_temp.u(101)) c where c.invoice_id = p_invoice);
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select set_config('t.e1', pg_temp.declare_paid(2, pg_temp.u(301), 5000, '2026-10'), true);
select ok(pg_temp.claimed(pg_temp.u(301)), 'a declaration that waits holds the invoice it names');

-- ── who may take it back ──
select is(pg_temp.withdraw(3, current_setting('t.e1')), 'ERR DKC08', 'another member is refused');
select is(pg_temp.withdraw(1, current_setting('t.e1')), 'ERR DKC08',
  'whoever issues the invoices, neither its member nor who recorded it, is refused: they decide it instead');
select is(pg_temp.withdraw(4, current_setting('t.e1')), 'ERR DKC08', 'a member of another business is refused');
select is(pg_temp.withdraw(2, gen_random_uuid()::text), 'ERR DKC08', 'an unknown declaration gets the same answer');
select is(pg_temp.withdraw(2, pg_temp.u(401)::text), 'ERR DKC08', 'the member''s own pending request of another type is not a payment');
select is((select status from public.events where id = pg_temp.u(401)), 'pending', 'and stays as it was');
select is(pg_temp.withdraw(2, current_setting('t.e1')), 'ok', 'the member takes back their declaration while it waits');

-- ── what it does ──
select is((select status || ' ' || (payload ->> 'withdrawn_by') from public.events where id = current_setting('t.e1')::uuid),
  'withdrawn ' || pg_temp.u(202)::text, 'the declaration is ended as withdrawn, naming who withdrew it');
select ok(not pg_temp.claimed(pg_temp.u(301)), 'its invoice is free');
select is((select count(*)::int from public.ledger_entries where event_id = current_setting('t.e1')::uuid),
  0, 'and nothing is credited');
select is(pg_temp.as_user(1, format('select status || '' '' || (payload ->> ''withdrawn_by'') from public.events where id = %L',
                                     current_setting('t.e1'))),
  'withdrawn ' || pg_temp.u(202)::text, 'the business reads that it was withdrawn and by whom');
select set_config('t.e2', pg_temp.declare_paid(2, pg_temp.u(301), 5000, '2026-10'), true);
select ok(current_setting('t.e2') !~ '^ERR', 'another payment may name the invoice again');

-- ── what can no longer be taken back ──
select is(pg_temp.withdraw(2, current_setting('t.e1')), 'ERR DKC13', 'a withdrawn declaration is not withdrawn twice');
select is(pg_temp.as_user(1, format('select public.respond_to_event(%L, true)::text', current_setting('t.e1'))),
  'ERR DKD01', 'nor decided by the business');
select is(pg_temp.as_user(1, format('select public.respond_to_event(%L, true)::text', current_setting('t.e2'))),
  'ok', 'the business confirms the new declaration');
select is((select count(*)::int from public.ledger_entries where event_id = current_setting('t.e2')::uuid),
  1, 'and credits it once');
select is(pg_temp.withdraw(2, current_setting('t.e2')), 'ERR DKC13', 'a confirmed declaration cannot be taken back');

-- ── who recorded it takes it back ──
select set_config('t.e3', pg_temp.declare_paid(1, pg_temp.u(302), 3000, '2026-11'), true);
select is(pg_temp.withdraw(1, current_setting('t.e3')), 'ok',
  'the member who recorded a declaration for another takes it back');
select is((select status || ' ' || (payload ->> 'withdrawn_by') from public.events where id = current_setting('t.e3')::uuid),
  'withdrawn ' || pg_temp.u(201)::text, 'and is named as who did');
select set_config('t.e4', pg_temp.declare_paid(2, pg_temp.u(302), 3000, '2026-11'), true);
select is(pg_temp.as_user(1, format('select public.respond_to_event(%L, false)::text', current_setting('t.e4'))),
  'ok', 'the business refuses a declaration');
select is(pg_temp.withdraw(2, current_setting('t.e4')), 'ERR DKC13', 'a refused declaration cannot be taken back');

-- ── the decision locks the event it decides; the constraint is whole ──
select ok(pg_get_functiondef('public.respond_to_event(uuid, boolean)'::regprocedure)
            like '%where e.id = p_event_id for update;%'
          and not has_function_privilege('anon', 'public.withdraw_payment_declaration(uuid)', 'execute'),
  'the decision locks the event it decides; no anonymous caller withdraws anything');
select ok((select convalidated from pg_constraint
            where conrelid = 'public.events'::regclass and conname = 'events_status_check'),
  'the status constraint is validated');

select * from finish();
rollback;
