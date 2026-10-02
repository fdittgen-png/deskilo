-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1914: a privacy notice is a published, versioned record, and an
-- acknowledgment names the notice it acknowledges. The notice shipped on
-- 2026-09-20 is seeded with what the software cannot know marked
-- `unknown`. An arbitrary version cannot be acknowledged through the
-- RPC; another space's version cannot be acknowledged through this
-- space; a non-member acknowledges nothing; only the installation's
-- operator publishes its notice and only a space's owner its supplement;
-- a credential-shaped key or a missing controller is refused. An EU space
-- and a space with a US endpoint show their own truthful regions. A new
-- version supersedes the old one, keeps the earlier acknowledgment as
-- history and opts nobody in. Nobody reads another person's
-- acknowledgments or a space they are not in.
begin;
select plan(28);

-- a1 operator · a2 owner of b1 · a3 member A of b1 · a4 owner of b2 ·
-- a5 member of b2 only.
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000001914'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@notice.test','',now(),now(),now()
  from unnest(array['a1','a2','a3','a4','a5']) suffix;
insert into public.platform_admins (user_id) values ('00000000-0000-4000-8000-0000001914a1');
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment) values
 ('00000000-0000-4000-8000-0000001914b1','Notice EU','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001914a2','dev'),
 ('00000000-0000-4000-8000-0000001914b2','Notice US','US','USD','America/New_York','00000000-0000-4000-8000-0000001914a4','dev');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000001914c2','00000000-0000-4000-8000-0000001914b1','00000000-0000-4000-8000-0000001914a2',true,true,'active'),
 ('00000000-0000-4000-8000-0000001914c3','00000000-0000-4000-8000-0000001914b1','00000000-0000-4000-8000-0000001914a3',false,false,'active'),
 ('00000000-0000-4000-8000-0000001914c4','00000000-0000-4000-8000-0000001914b2','00000000-0000-4000-8000-0000001914a4',true,true,'active'),
 ('00000000-0000-4000-8000-0000001914c5','00000000-0000-4000-8000-0000001914b2','00000000-0000-4000-8000-0000001914a5',false,false,'active');

create temp table seen(k text primary key, v jsonb);
grant select, insert on seen to authenticated;
create temp table manifests(k text primary key, v jsonb);
grant select on manifests to authenticated;
insert into manifests values
 ('eu', '{"controller":{"name":"Notice EU association","contact":"privacy@eu.test"},"rights_contact":"privacy@eu.test","retention":"see the retention matrix",
          "recipients":[{"name":"Supabase","role":"processor","purpose":"database","legal_basis":"contract","data_categories":["account"],"region":"eu-central-1","transfer_mechanism":"none_needed","essential":true}]}'),
 ('us', '{"controller":{"name":"Notice US LLC","contact":"privacy@us.test"},"rights_contact":"privacy@us.test","retention":"see the retention matrix",
          "recipients":[{"name":"Own Postgres","role":"processor","purpose":"database","legal_basis":"contract","data_categories":["account"],"region":"us-east-1","transfer_mechanism":"scc","essential":true}]}'),
 ('fcm', '{"controller":{"name":"Operator","contact":"ops@op.test"},"rights_contact":"ops@op.test","retention":"see the retention matrix",
          "recipients":[{"name":"Firebase Cloud Messaging","role":"processor","purpose":"push delivery","legal_basis":"contract","data_categories":["device token"],"region":"global","transfer_mechanism":"unknown","essential":false}]}'),
 ('leaky', '{"controller":{"name":"X","contact":"x@x.test"},"rights_contact":"x@x.test","retention":"r","api_token":"CANARY-SECRET",
          "recipients":[]}'),
 ('no_controller', '{"rights_contact":"x@x.test","retention":"r","recipients":[]}');

-- ── the seeded notice ───────────────────────────────────────────────
select ok(exists(select 1 from public.privacy_notices where space_id is null and version = '2026-09-20' and status = 'published'),
  'the notice shipped on 2026-09-20 is the current installation notice');
select ok((select manifest::text from public.privacy_notices where space_id is null and version = '2026-09-20') like '%"transfer_mechanism": "unknown"%',
  'and what the software cannot know is marked unknown, not invented');

-- ── acknowledging the installation notice ───────────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001914a3","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($$select public.accept_privacy_policy('2099-01-01')$$,
  'that is not the current privacy notice of this installation', 'an arbitrary version cannot be acknowledged');
select lives_ok($$select public.accept_privacy_policy('2026-09-20')$$, 'the current version can');
select throws_ok($$select public.publish_privacy_notice(null, '2026-10-01', (select v from manifests where k = 'fcm'))$$,
  'only the operator of this installation publishes its privacy notice', 'a member cannot publish the installation notice');
reset role;
select is((select n.version from public.privacy_notice_acknowledgments a join public.privacy_notices n on n.id = a.notice_id
            where a.user_id = '00000000-0000-4000-8000-0000001914a3' and not a.legacy), '2026-09-20',
  'the acknowledgment is stored against the notice row');
select is((select privacy_accepted_version from public.profiles where id = '00000000-0000-4000-8000-0000001914a3'), '2026-09-20',
  'and the profile the shipped client reads agrees');

-- ── space supplements ───────────────────────────────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001914a2","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.publish_privacy_notice('00000000-0000-4000-8000-0000001914b1', 'eu-1', (select v from manifests where k = 'eu'))$$,
  'the owner publishes the space''s notice');
select throws_like($$select public.publish_privacy_notice('00000000-0000-4000-8000-0000001914b1', 'eu-2', (select v from manifests where k = 'leaky'))$$,
  'a notice names its controller%', 'a credential-shaped key is refused');
select throws_like($$select public.publish_privacy_notice('00000000-0000-4000-8000-0000001914b1', 'eu-3', (select v from manifests where k = 'no_controller'))$$,
  'a notice names its controller%', 'a notice without a controller is refused');
select throws_ok($$select public.publish_privacy_notice('00000000-0000-4000-8000-0000001914b1', 'eu-1', (select v from manifests where k = 'eu'))$$,
  'that version was already published; publish a new one', 'a version is published once');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001914a4","role":"authenticated"}',true);
select lives_ok($$select public.publish_privacy_notice('00000000-0000-4000-8000-0000001914b2', 'us-1', (select v from manifests where k = 'us'))$$,
  'the other owner publishes theirs');
select throws_ok($$select public.publish_privacy_notice('00000000-0000-4000-8000-0000001914b1', 'eu-9', (select v from manifests where k = 'us'))$$,
  'only the owner publishes the privacy notice of a space', 'an owner cannot publish into another space');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001914a3","role":"authenticated"}',true);
select throws_ok($$select public.acknowledge_workspace_notice('00000000-0000-4000-8000-0000001914b1', 'us-1')$$,
  'that is not the current privacy notice of this space', 'another space''s version cannot be acknowledged through this one');
select throws_ok($$select public.acknowledge_workspace_notice('00000000-0000-4000-8000-0000001914b2', 'us-1')$$,
  'only a member acknowledges the notice of a space', 'a non-member acknowledges nothing');
select lives_ok($$select public.acknowledge_workspace_notice('00000000-0000-4000-8000-0000001914b1', 'eu-1')$$,
  'a member acknowledges their space''s notice');
insert into seen values ('a_eu', public.current_privacy_notice('00000000-0000-4000-8000-0000001914b1'));
insert into seen values ('a_us', public.current_privacy_notice('00000000-0000-4000-8000-0000001914b2'));
insert into seen values ('a_export', public.export_my_data('00000000-0000-4000-8000-0000001914b1')->'privacy_notice_acknowledgments');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001914a5","role":"authenticated"}',true);
insert into seen values ('b_us', public.current_privacy_notice('00000000-0000-4000-8000-0000001914b2'));
insert into seen values ('b_reads_acks', to_jsonb((select count(*) from public.privacy_notice_acknowledgments)));
insert into seen values ('b_reads_eu', to_jsonb((select count(*) from public.privacy_notices where space_id = '00000000-0000-4000-8000-0000001914b1')));
reset role;
select is((select v->'workspace'->'manifest'->'recipients'->0->>'region' from seen where k = 'a_eu'), 'eu-central-1',
  'the EU space shows its EU region');
select is((select v->'workspace'->'manifest'->'recipients'->0->>'region' from seen where k = 'b_us'), 'us-east-1',
  'the space with its own US endpoint shows that region and its transfer mechanism');
select ok((select v->'workspace' = 'null'::jsonb from seen where k = 'a_us'), 'a non-member is not shown another space''s notice');
select ok((select v from seen where k = 'a_export') @> '[{"version":"2026-09-20"},{"version":"eu-1"}]', 'the person''s acknowledgments travel in their access export');
select is((select v from seen where k = 'b_reads_acks'), '0'::jsonb, 'nobody reads another person''s acknowledgments');
select is((select v from seen where k = 'b_reads_eu'), '0'::jsonb, 'nor the notice rows of a space they are not in');

-- ── a new installation notice ───────────────────────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001914a1","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.publish_privacy_notice(null, '2026-10-01', (select v from manifests where k = 'fcm'))$$,
  'the operator publishes a new installation notice');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001914a3","role":"authenticated"}',true);
select throws_ok($$select public.accept_privacy_policy('2026-09-20')$$,
  'that is not the current privacy notice of this installation', 'the superseded version can no longer be acknowledged');
reset role;
select is((select status from public.privacy_notices where space_id is null and version = '2026-09-20'), 'superseded',
  'the old notice is kept as superseded history');
select is((select privacy_accepted_version from public.profiles where id = '00000000-0000-4000-8000-0000001914a3'), '2026-09-20',
  'nobody is opted in to the new version');
select is((select count(*)::int from public.privacy_notice_acknowledgments where user_id = '00000000-0000-4000-8000-0000001914a3'), 2,
  'and the earlier acknowledgments stay');
select ok((select v::text from seen where k = 'a_eu') not like '%CANARY-SECRET%', 'the refused credential never reached a published notice');

select * from finish();
rollback;
