-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3091 / 0611: a new badge PIN has at least the registry's minimum number of
-- digits (6 by default), and the badge lockout grows — the configured failures
-- within the configured window lock for that window, twice as many within an
-- hour lock for the hour, three times as many within a day for the day.
begin;
select plan(10);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- n failed attempts on the tag, each [ago] before now.
create function pg_temp.failed(p_uid text, p_n int, p_ago interval) returns void language plpgsql as $$
begin
  insert into public.badge_auth_attempts (token_hash, succeeded, attempted_at)
  select public.badge_token_hash(p_uid), false, now() - p_ago
    from generate_series(1, p_n);
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.verdict(p_uid text) returns text language sql as $$
  select public.badge_auth_verify(p_uid, '000000') ->> 'reason'
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-000000003091', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'pin@badge-hardening.test', '', now(), now(), now());

-- ── the PIN's minimum length ───────────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-000000003091');
select throws_ok($$select public.set_badge_pin('4826')$$, 'P0001',
  'the PIN must be 6 to 8 digits', 'a 4-digit PIN is refused at the default of 6');
select lives_ok($$select public.set_badge_pin('482615')$$, 'a 6-digit PIN is accepted');
select throws_ok($$select public.set_badge_pin('123456')$$, 'P0001',
  'that PIN is too easy to guess', 'a trivial 6-digit PIN is still refused');
reset role;
select public.store_setting(null, 'security.badge_pin_min_length', '4'::jsonb, 'test', null);
select pg_temp.act_as('00000000-0000-4000-8000-000000003091');
select lives_ok($$select public.set_badge_pin('4826')$$, 'lowered to 4, a 4-digit PIN is accepted again');
reset role;

-- ── the lockout grows ──────────────────────────────────────────────────
-- Five failures within the window: the old gate, unchanged.
select pg_temp.failed('9a000000000000a1', 5, interval '1 minute');
select is(pg_temp.verdict('9a000000000000a1'), 'locked', '5 failures in 15 minutes lock the tag');
-- Ten failures 20 minutes ago: outside the 15-minute window, inside the hour.
select pg_temp.failed('9a000000000000a2', 10, interval '20 minutes');
select is(pg_temp.verdict('9a000000000000a2'), 'locked', '10 failures within an hour lock it past the 15 minutes');
-- Nine: the hour gate does not hold yet.
select pg_temp.failed('9a000000000000a3', 9, interval '20 minutes');
select is(pg_temp.verdict('9a000000000000a3'), 'refused', '9 failures 20 minutes ago do not lock');
-- Fifteen failures five hours ago: only the day gate sees them.
select pg_temp.failed('9a000000000000a4', 15, interval '5 hours');
select is(pg_temp.verdict('9a000000000000a4'), 'locked', '15 failures within a day lock it for the day');
-- Older than a day counts for nothing.
select pg_temp.failed('9a000000000000a5', 15, interval '25 hours');
select is(pg_temp.verdict('9a000000000000a5'), 'refused', 'failures older than a day are forgotten');

-- ── a real badge driven to the lock answers like an unknown tag ─────────
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags)
values ('00000000-0000-4000-8000-0000003092b1', 'Badge hardening', 'FR', 'EUR', 'Europe/Paris',
        '00000000-0000-4000-8000-000000003091', '{"badgeSignIn":true,"nfcBadges":true}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, co_owner, status)
values ('00000000-0000-4000-8000-0000003092c1', '00000000-0000-4000-8000-0000003092b1',
        '00000000-0000-4000-8000-000000003091', true, true, 'none', 'active');
insert into public.member_badges (workspace_id, member_id, token_hash, auth_enabled)
values ('00000000-0000-4000-8000-0000003092b1', '00000000-0000-4000-8000-0000003092c1',
        public.badge_token_hash('9b00000000000001'), true);
select pg_temp.failed('9b00000000000001', 5, interval '1 minute');
select pg_temp.failed('9b00000000000002', 5, interval '1 minute');
select is(public.badge_auth_verify('9b00000000000001', '000000'),
          public.badge_auth_verify('9b00000000000002', '000000'),
  'a real badge at the lock returns exactly what an unknown tag at the lock returns');

select * from finish();
rollback;
