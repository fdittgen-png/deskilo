-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2872 (0546, ADR 0047 §9): sample data in the owner's own test space.
-- Only a configurer of a TEST space fills it, never a plain member, a
-- delegated assistant or a production space. Filling twice answers the
-- same batch. Sample bookings and members are no evidence that the space
-- is in use, and a space holding them cannot be declared production.
-- Clearing removes exactly the batch: every recorded row is gone and every
-- row that existed before reads byte for byte as it did (whole-row
-- digests). A clear that something blocks raises, keeps the batch open,
-- and succeeds when retried.
begin;
select plan(23);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000002872'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@sample-data.test','',now(),now(),now()
  from unnest(array['a1','a2']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,booking_rules) values
 ('00000000-0000-4000-8000-0000002872b1','Sample test','FR','EUR','Europe/Paris',
  '00000000-0000-4000-8000-0000002872a1','dev','{"open_weekdays":[1,2,3,4,5]}'),
 ('00000000-0000-4000-8000-0000002872b2','Sample prod','FR','EUR','Europe/Paris',
  '00000000-0000-4000-8000-0000002872a1','prod','{"open_weekdays":[1,2,3,4,5]}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000002872c1','00000000-0000-4000-8000-0000002872b1','00000000-0000-4000-8000-0000002872a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000002872c2','00000000-0000-4000-8000-0000002872b1','00000000-0000-4000-8000-0000002872a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000002872c3','00000000-0000-4000-8000-0000002872b2','00000000-0000-4000-8000-0000002872a1',true,true,'active');
insert into public.levels(id,workspace_id,name,sort_order) values
 ('00000000-0000-4000-8000-0000002872d1','00000000-0000-4000-8000-0000002872b1','Ground',0);
insert into public.offices(id,workspace_id,level_id,name,color,bookable_as_whole,x,y,w,h) values
 ('00000000-0000-4000-8000-0000002872d2','00000000-0000-4000-8000-0000002872b1','00000000-0000-4000-8000-0000002872d1','Open space',1,false,0,0,10,10);
insert into public.desks(id,workspace_id,office_id,name,x,y,w,h) values
 ('00000000-0000-4000-8000-0000002872d3','00000000-0000-4000-8000-0000002872b1','00000000-0000-4000-8000-0000002872d2','Table',1,1,4,2);
insert into public.seats(id,workspace_id,desk_id,name,x,y,orientation,chair,amenities) values
 ('00000000-0000-4000-8000-0000002872e1','00000000-0000-4000-8000-0000002872b1','00000000-0000-4000-8000-0000002872d3','S1',1,1,'n','','{}'),
 ('00000000-0000-4000-8000-0000002872e2','00000000-0000-4000-8000-0000002872b1','00000000-0000-4000-8000-0000002872d3','S2',2,1,'n','','{}');
-- A new space is seeded with its fee bands; give them a price.
update public.fee_bands set fee_cents = 9000 where workspace_id = '00000000-0000-4000-8000-0000002872b1';

create function pg_temp.batch() returns uuid language sql as $$
  select id from public.sample_data_batches
   where workspace_id = '00000000-0000-4000-8000-0000002872b1' and cleared_at is null
$$;
create function pg_temp.section(p text) returns jsonb language sql as $$
  select s from jsonb_array_elements(public.workspace_readiness('00000000-0000-4000-8000-0000002872b1')) s
   where s->>'section' = p
$$;
-- Every row of the space that a batch could touch, whole, in one digest per table.
create function pg_temp.digest() returns jsonb language sql as $$
  select jsonb_build_object(
    'members', (select md5(coalesce(string_agg(md5(to_jsonb(t)::text), ',' order by t.id), '')) from public.members t where t.workspace_id = '00000000-0000-4000-8000-0000002872b1'),
    'directory_people', (select md5(coalesce(string_agg(md5(to_jsonb(t)::text), ',' order by t.id), '')) from public.directory_people t where t.id in (select person_id from public.members where workspace_id = '00000000-0000-4000-8000-0000002872b1')),
    'reservations', (select md5(coalesce(string_agg(md5(to_jsonb(t)::text), ',' order by t.id), '')) from public.reservations t where t.workspace_id = '00000000-0000-4000-8000-0000002872b1'),
    'reservation_target_history', (select md5(coalesce(string_agg(md5(to_jsonb(t)::text), ',' order by t.id), '')) from public.reservation_target_history t where t.workspace_id = '00000000-0000-4000-8000-0000002872b1'),
    'events', (select md5(coalesce(string_agg(md5(to_jsonb(t)::text), ',' order by t.id), '')) from public.events t where t.workspace_id = '00000000-0000-4000-8000-0000002872b1'),
    'ledger_entries', (select md5(coalesce(string_agg(md5(to_jsonb(t)::text), ',' order by t.id), '')) from public.ledger_entries t where t.workspace_id = '00000000-0000-4000-8000-0000002872b1'),
    'number_sequences', (select md5(coalesce(string_agg(md5(to_jsonb(t)::text), ',' order by to_jsonb(t)::text), '')) from public.number_sequences t where t.workspace_id = '00000000-0000-4000-8000-0000002872b1'),
    'workspaces', (select md5(to_jsonb(t)::text) from public.workspaces t where t.id = '00000000-0000-4000-8000-0000002872b1'))
$$;

-- Who may not.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002872a2","role":"authenticated"}',true);
select throws_ok($$select public.create_sample_data('00000000-0000-4000-8000-0000002872b1', gen_random_uuid())$$,
  '42501', 'only someone who configures this space may add or clear sample data',
  'a plain member does not fill the space');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002872a1","role":"authenticated","client_id":"assistant"}',true);
select throws_ok($$select public.create_sample_data('00000000-0000-4000-8000-0000002872b1', gen_random_uuid())$$,
  '42501', 'sample data is not available to a delegated assistant',
  'an assistant acting for the owner does not either');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002872a1","role":"authenticated"}',true);
select throws_ok($$select public.create_sample_data('00000000-0000-4000-8000-0000002872b2', gen_random_uuid())$$,
  '22023', 'sample data lives only in a test space, never in a production one',
  'a production space never holds sample data');

-- The owner fills the test space from its own configuration.
select is(public.sample_data_status('00000000-0000-4000-8000-0000002872b1'), null, 'no batch before the first fill');
select is((public.create_sample_data('00000000-0000-4000-8000-0000002872b1', gen_random_uuid())->'counts'->>'members')::int,
  6, 'six sample members');
select ok((select count(*) from public.reservations where workspace_id = '00000000-0000-4000-8000-0000002872b1') > 0,
  'they book the space''s own seats');
select ok((select bool_and(user_id is null and member_number = '' and managed_identity->>'email' is null)
             from public.members where id in (select record_id from public.sample_data_records where table_name = 'members')),
  'without an account, a number or an e-mail address');
select is((select count(*)::int from public.events e where e.workspace_id = '00000000-0000-4000-8000-0000002872b1' and e.status <> 'applied'),
  0, 'the events their bookings log notify nobody');
select ok((select count(*) from public.ledger_entries where workspace_id = '00000000-0000-4000-8000-0000002872b1') > 0,
  'and some of them paid at the fee band of their level');
select is((public.create_sample_data('00000000-0000-4000-8000-0000002872b1', gen_random_uuid())->>'batch_id')::uuid,
  pg_temp.batch(), 'filling twice answers the open batch');
select is(pg_temp.section('first_booking')->>'state', 'needs_configuration',
  'a sample booking is no first booking');
select is((pg_temp.section('invitations')->>'count')::int, 2, 'nor is a sample member a member who joined');
select throws_ok($$select public.set_workspace_environment('00000000-0000-4000-8000-0000002872b1', 'prod')$$,
  '55000', 'clear the sample data before declaring this space production',
  'a space holding sample data stays a test space');
select is((public.clear_sample_data('00000000-0000-4000-8000-0000002872b1', pg_temp.batch())->'remaining'->>'members')::int,
  0, 'clearing removes the members');
select is((select count(*)::int from public.members where workspace_id = '00000000-0000-4000-8000-0000002872b1'), 2,
  'and leaves the two real ones');

-- With real activity in the space: the owner's own booking and payment.
insert into public.reservations(workspace_id,seat_id,member_id,starts_at,ends_at,status) values
 ('00000000-0000-4000-8000-0000002872b1','00000000-0000-4000-8000-0000002872e1','00000000-0000-4000-8000-0000002872c1',
  date_trunc('day', now()) + interval '1 day 9 hours', date_trunc('day', now()) + interval '1 day 12 hours','reserved');
insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period) values
 ('00000000-0000-4000-8000-0000002872b1','00000000-0000-4000-8000-0000002872c1','credit','payment',1000,'',to_char(now(),'YYYY-MM'));
create temp table sample_before as select pg_temp.digest() as d;
select ok((public.create_sample_data('00000000-0000-4000-8000-0000002872b1', gen_random_uuid())->>'batch_id') is not null,
  'a second batch after the first was cleared');
create temp table sample_recorded as
  select table_name, record_id from public.sample_data_records where batch_id = pg_temp.batch();

-- A decision a sample member made on a real event keeps it referenced.
insert into public.event_decisions(event_id,member_id,decision)
select e.id, (select record_id from sample_recorded where table_name = 'members' limit 1), 'accept'
  from public.events e
 where e.workspace_id = '00000000-0000-4000-8000-0000002872b1'
   and e.subject_member_id = '00000000-0000-4000-8000-0000002872c1' limit 1;
select throws_like($$select public.clear_sample_data('00000000-0000-4000-8000-0000002872b1', pg_temp.batch())$$,
  'sample data not cleared:%', 'a blocked clear says so');
select ok(pg_temp.batch() is not null and (select count(*) from public.sample_data_records where batch_id = pg_temp.batch())
            = (select count(*) from sample_recorded),
  'and keeps the batch whole for the retry');
delete from public.event_decisions where member_id in (select record_id from sample_recorded where table_name = 'members');

select is((public.clear_sample_data('00000000-0000-4000-8000-0000002872b1', pg_temp.batch())->>'cleared_at') is not null,
  true, 'the retry clears');
select is((select count(*)::int from sample_recorded s
            where (s.table_name = 'members' and exists (select 1 from public.members m where m.id = s.record_id))
               or (s.table_name = 'reservations' and exists (select 1 from public.reservations r where r.id = s.record_id))
               or (s.table_name = 'events' and exists (select 1 from public.events e where e.id = s.record_id))
               or (s.table_name = 'ledger_entries' and exists (select 1 from public.ledger_entries l where l.id = s.record_id))
               or (s.table_name = 'directory_people' and exists (select 1 from public.directory_people p where p.id = s.record_id))
               or (s.table_name = 'managed_identities' and exists (select 1 from public.managed_identities i where i.member_id = s.record_id))
               or (s.table_name = 'reservation_target_history' and exists (select 1 from public.reservation_target_history h where h.id = s.record_id))),
  0, 'every recorded row is gone');
select is(pg_temp.digest(), (select d from sample_before), 'every row that existed before is byte for byte the same');

-- Who reads the batches: the configurer, not a plain member.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002872a1","role":"authenticated"}',true);
select is((select count(*)::int from public.sample_data_batches), 2, 'the owner reads both batches of the space');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002872a2","role":"authenticated"}',true);
select is((select count(*)::int from public.sample_data_batches), 0, 'a plain member reads no batch');

select * from finish();
rollback;
