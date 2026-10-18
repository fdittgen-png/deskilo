-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2487 / 0476 (S4 of #2483): the read-notice retention and the VAT-number
-- check freshness are registry settings; defaults are today's values; the
-- purge touches READ notices only; a change applies to the next run only.
--   A the rows and their bounds   B the notice purge   C the VIES freshness
begin;
select plan(19);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.refused(p_ws uuid, p_key text, p_value text) returns boolean language plpgsql as $$
begin
  perform public.set_setting(p_ws, p_key, p_value::jsonb, '');
  return false;
exception when others then return sqlerrm like '%is refused%';
end;
$$;
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002487' || lpad(n::text, 4, '0'))::uuid;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@retention.test', '', now(), now(), now()
  from generate_series(1, 4) i;
-- 1 owner, 2 platform owner (and the notice recipient), 3 other recipient.
insert into public.platform_admins (user_id) values (pg_temp.u(2));

-- ── A: the rows and their bounds ───────────────────────────────────────
select is(public.setting_value(null, 'mcp.notice_read_retention_days')::text, '90', 'A: the notice retention defaults to today''s 90 days');
select is(public.setting_value(null, 'vat.vies_evidence_days')::text, '90', 'A: and the VAT-number freshness to 90 days');
select pg_temp.act_as(pg_temp.u(2));
select ok(pg_temp.refused(null, 'mcp.notice_read_retention_days', '3'), 'A: a retention under 7 days is refused');
select ok(pg_temp.refused(null, 'mcp.notice_read_retention_days', '4000'), 'A: and over 3650');
select ok(pg_temp.refused(null, 'vat.vies_evidence_days', '91'), 'A: a VAT-number check kept longer than 90 days is refused');
select ok(pg_temp.refused(null, 'vat.vies_evidence_days', '0'), 'A: and a freshness of zero days');
select is(public.set_setting(null, 'mcp.notice_read_retention_days', '30', 'tighten')->>'status', 'saved', 'A: a platform owner shortens the retention');
select public.set_setting(null, 'mcp.notice_read_retention_days', '90', 'restore');
reset role;

-- ── B: the notice purge ────────────────────────────────────────────────
insert into public.instance_notices (user_id, kind, subject, read_at, created_at) values
 (pg_temp.u(3), 'notice_old', 'read 100 days ago', now() - interval '100 days', now() - interval '110 days'),
 (pg_temp.u(3), 'notice_mid', 'read 50 days ago',  now() - interval '50 days',  now() - interval '60 days'),
 (pg_temp.u(3), 'notice_new', 'read yesterday',    now() - interval '1 day',    now() - interval '2 days'),
 (pg_temp.u(3), 'notice_unread', 'never read',     null,                        now() - interval '200 days');
select public.instance_notify_operators('notice_run', 'run 1', '{}'::jsonb, null);
select is((select string_agg(kind, ',' order by kind) from public.instance_notices where user_id = pg_temp.u(3)),
  'notice_mid,notice_new,notice_unread', 'B: golden: at 90 days the notice read 100 days ago goes, the others stay');
select is((select count(*)::int from public.instance_notices where user_id = pg_temp.u(3) and read_at is null), 1,
  'B: an unread notice is never purged, however old');
select public.store_setting(null, 'mcp.notice_read_retention_days', '30'::jsonb, 'test', null);
select is((select count(*)::int from public.instance_notices where user_id = pg_temp.u(3) and kind = 'notice_mid'), 1,
  'B: changing the days purged nothing by itself: it applies to the next run');
select public.instance_notify_operators('notice_run', 'run 2', '{}'::jsonb, null);
select is((select string_agg(kind, ',' order by kind) from public.instance_notices where user_id = pg_temp.u(3)),
  'notice_new,notice_unread', 'B: at 30 days the next run purges the one read 50 days ago');
insert into public.instance_notices (user_id, kind, subject, read_at) values
 (pg_temp.u(3), 'notice_own', 'read 40 days ago', now() - interval '40 days');
select pg_temp.act_as(pg_temp.u(3));
select ok((public.mark_instance_notice_read(null) ->> 'status') in ('read', 'unchanged'), 'B: a person marking their notices read runs the purge for their own rows');
reset role;
select is((select count(*)::int from public.instance_notices where user_id = pg_temp.u(3) and kind = 'notice_own'), 0,
  'B: and it uses the same setting: 40 days is past a 30-day retention');
select is((select count(*)::int from public.instance_notices where user_id = pg_temp.u(3) and kind in ('notice_new', 'notice_unread')), 2,
  'B: readback: the recent and the unread notice are kept');
select public.store_setting(null, 'mcp.notice_read_retention_days', '1'::jsonb, 'test', null);
select is(public.setting_value(null, 'mcp.notice_read_retention_days')::text, '7', 'B: a stored value under the bound is held at 7 days');
select public.store_setting(null, 'mcp.notice_read_retention_days', '90'::jsonb, 'test', null);

-- ── C: the VAT-number check freshness ──────────────────────────────────
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.ws', public.create_workspace('Retention', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values ('00000000-0000-4000-8000-0000248700c1', current_setting('t.ws')::uuid, pg_temp.u(4), false, false, 'active', '2026-01-01');
-- The VIES columns are written by the recorder only (0404); the fixture plays it
-- with the check dated 60 days ago.
select set_config('deskilo.vies', 'record', true);
update public.members set vies_vat_id = 'FR12345678901', vies_status = 'valid', vies_consultation = 'test',
       vies_checked_at = now() - interval '60 days' where id = '00000000-0000-4000-8000-0000248700c1';
select set_config('deskilo.vies', '', true);
select is(public.member_vies_verified('00000000-0000-4000-8000-0000248700c1', 'FR12345678901'), true, 'C: golden: a valid check 60 days old stands at the default 90');
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"configurableSettings": true}' where id = current_setting('t.ws')::uuid;
select pg_temp.act_as(pg_temp.u(1));
select is(public.set_setting(current_setting('t.ws')::uuid, 'vat.vies_evidence_days', '30', 'stricter')->>'status', 'saved', 'C: the workspace asks for fresher checks: 30 days');
reset role;
select is(public.member_vies_verified('00000000-0000-4000-8000-0000248700c1', 'FR12345678901'), false, 'C: the same 60-day-old check no longer stands, at once');
select public.store_setting(current_setting('t.ws')::uuid, 'vat.vies_evidence_days', '500'::jsonb, 'test', null);
select is(public.setting_value(current_setting('t.ws')::uuid, 'vat.vies_evidence_days')::text, '90', 'C: a stored value above the bound is held at 90');

select * from finish();
rollback;
