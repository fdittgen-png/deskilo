-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1279 S1 — a member may have no subscription, and that never books free.
begin;
select plan(7);

create or replace function pg_temp.act_as(p_user uuid) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  execute 'set local role authenticated';
end
$act$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-000000001301', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'zero-sub@deskilo.test', '', now(), now(), now());

select pg_temp.act_as('00000000-0000-4000-8000-000000001301');
select set_config('deskilo.zs.ws',
  public.create_workspace('Zero', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.apply_workspace_template(current_setting('deskilo.zs.ws')::uuid,
  (select id from public.workspace_templates where key = 'tiny'));

reset role;
update public.workspaces
   set booking_rules = booking_rules || '{"open_weekdays":[1,2,3,4,5,6,7],"granularity":"half_day","work_start_minutes":480,"half_boundary_minutes":720,"work_end_minutes":1080}'
 where id = current_setting('deskilo.zs.ws')::uuid;
select set_config('deskilo.zs.me',
  (select id from public.members where workspace_id = current_setting('deskilo.zs.ws')::uuid
     and user_id = '00000000-0000-4000-8000-000000001301')::text, true);
select set_config('deskilo.zs.day', ((now() at time zone 'Europe/Paris')::date + 7)::text, true);

select lives_ok(
  $$ update public.members set subscription_pct = 0, overage_policy = 'blocked'
      where id = current_setting('deskilo.zs.me')::uuid $$,
  'a member may have no subscription');

select throws_like(
  $$ update public.members set overage_policy = 'payg'
      where id = current_setting('deskilo.zs.me')::uuid $$,
  '%cannot pay as they go%',
  'no subscription and pay-as-you-go cannot combine — that would book for free');

select is(
  (select (public.member_statement(current_setting('deskilo.zs.me')::uuid,
     to_char(current_setting('deskilo.zs.day')::date, 'YYYY-MM'))->>'fee_cents')::int),
  0,
  'no subscription: no fee');
select is(
  (select count(*)::int from jsonb_array_elements(public.invoice_lines_for(
     current_setting('deskilo.zs.me')::uuid,
     to_char(current_setting('deskilo.zs.day')::date, 'YYYY-MM'))) l
    where l.value->>'kind' = 'subscription'),
  0,
  'and no subscription line on the invoice, rather than a zero line');

select pg_temp.act_as('00000000-0000-4000-8000-000000001301');
select throws_ok(
  $$ select public.create_reservation(current_setting('deskilo.zs.ws')::uuid,
       (select id from public.seats where workspace_id = current_setting('deskilo.zs.ws')::uuid order by name limit 1),
       null,
       (current_setting('deskilo.zs.day')::date + time '08:00') at time zone 'Europe/Paris',
       (current_setting('deskilo.zs.day')::date + time '12:00') at time zone 'Europe/Paris',
       false, null, null) $$,
  'half-day quota exceeded — request additional half-days',
  'the first half-day is refused, with the message every member already gets');

reset role;
update public.members set subscription_pct = 1 where id = current_setting('deskilo.zs.me')::uuid;
select cmp_ok(
  (select (public.member_statement(current_setting('deskilo.zs.me')::uuid,
     to_char(current_setting('deskilo.zs.day')::date, 'YYYY-MM'))->>'included_half_days')::int),
  '>=', 1,
  'one percent still receives an included half-day');
select throws_like(
  $$ update public.members set subscription_pct = 101
      where id = current_setting('deskilo.zs.me')::uuid $$,
  '%members_subscription_pct_check%',
  'the range still ends at 100');

select * from finish();
rollback;
