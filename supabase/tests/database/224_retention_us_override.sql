-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2571 / 0481: a US space may set its state's retention years; 0 leaves the
-- rule in force; the setting never reaches another country or another space.
-- Expected dates are written by hand: invoice dated 2020-06-01.
begin;
select plan(9);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002572' || lpad(n::text, 4, '0'))::uuid;
$$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@usclock.test', '', now(), now(), now()
  from generate_series(1, 2) i;

select pg_temp.act_as(pg_temp.u(1));
select set_config('t.us', public.create_workspace('US clock', 'US', 'USD', 'America/New_York', 'dev', false, null)::text, true);
select pg_temp.act_as(pg_temp.u(2));
select set_config('t.gb', public.create_workspace('GB clock', 'GB', 'GBP', 'Europe/London', 'dev', false, null)::text, true);

reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"configurableSettings": true}'::jsonb where id = current_setting('t.us')::uuid;
select pg_temp.act_as(pg_temp.u(1));
select is(public.retention_until(current_setting('t.us')::uuid, 'invoice', date '2020-06-01'), date '2024-06-01',
  'the US rule: 4 years from the document day');
select is(public.setting_value(current_setting('t.us')::uuid, 'retention.us_years') #>> '{}', '0', 'the override defaults to 0');
select is(public.set_setting(current_setting('t.us')::uuid, 'retention.us_years', '3'::jsonb, 'state asks 3')->>'status', 'saved',
  'the owner sets 3 years');
select is(public.retention_until(current_setting('t.us')::uuid, 'invoice', date '2020-06-01'), date '2023-06-01',
  'now an invoice of 2020-06-01 may go on 2023-06-01');
select is(public.retention_rule(current_setting('t.us')::uuid, 'books') ->> 'years', '3', 'every class follows the setting');
select throws_ok(format('select public.set_setting(%L, ''retention.us_years'', ''31''::jsonb, ''too long'')', current_setting('t.us')),
  null, null, 'over 30 years is refused');
reset role;

select pg_temp.act_as(pg_temp.u(2));
select throws_ok(format('select public.set_setting(%L, ''retention.us_years'', ''3''::jsonb, ''not mine'')', current_setting('t.us')),
  null, null, 'another space''s owner cannot set it');
select is(public.retention_until(current_setting('t.gb')::uuid, 'invoice', date '2020-06-01'), date '2026-12-31',
  'a UK space is unaffected by any US setting');
select is((public.preview_my_erasure(current_setting('t.gb')::uuid) -> 'retained' -> 0 ->> 'period'), '6 years from the end of the fiscal year (GB)',
  'and its erasure preview states the UK rule');
reset role;

select * from finish();
rollback;
