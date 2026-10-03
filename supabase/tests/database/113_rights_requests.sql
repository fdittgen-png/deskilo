-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1915: a rights request is a record with a calendar-month clock. The
-- due date is the same date next month in the workspace's time zone, or
-- the month's last day (31 Jan → 28/29 Feb); the extension adds two
-- further months, is granted once, only within the first month and with
-- a reason, and never moves the receipt or the first deadline. A
-- repeated submission with the same client id returns the same request.
-- Member A's access export carries A's canaries (profile, custom answer,
-- rights request) and not B's, and names what it does not cover. Staff
-- without viewPersonalData and the owner of another space can neither
-- read, extend nor decide A's request. A completed request carries a
-- manifest in which kept data states basis and period, and stays
-- closed. Before erasing, A is told the invoice stays (accounting
-- evidence) and the custom answer goes; after the real authenticated
-- erasure the invoice is still there, the answer is not, and A — now
-- exited — can still file a request.
begin;
select plan(37);

-- a1 owner · a2 member A · a3 member B · a4 plain member C · a5 owner of
-- the foreign space.
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000001915'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@rights.test','',now(),now(),now()
  from unnest(array['a1','a2','a3','a4','a5']) suffix;
update public.profiles set display_name = 'CANARY-A-NAME' where id = '00000000-0000-4000-8000-0000001915a2';
update public.profiles set display_name = 'B-NAME' where id = '00000000-0000-4000-8000-0000001915a3';
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,role_permissions,feature_flags) values
 ('00000000-0000-4000-8000-0000001915b1','Rights','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001915a1','dev','{}','{"customFields":true}'),
 ('00000000-0000-4000-8000-0000001915b2','Foreign rights','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001915a5','dev','{}','{}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000001915c1','00000000-0000-4000-8000-0000001915b1','00000000-0000-4000-8000-0000001915a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000001915c2','00000000-0000-4000-8000-0000001915b1','00000000-0000-4000-8000-0000001915a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000001915c3','00000000-0000-4000-8000-0000001915b1','00000000-0000-4000-8000-0000001915a3',false,false,'active'),
 ('00000000-0000-4000-8000-0000001915c4','00000000-0000-4000-8000-0000001915b1','00000000-0000-4000-8000-0000001915a4',false,false,'active'),
 ('00000000-0000-4000-8000-0000001915c5','00000000-0000-4000-8000-0000001915b2','00000000-0000-4000-8000-0000001915a5',true,true,'active');
insert into public.workspace_field_definitions(id,workspace_id,key,type,personal_data,visibility) values
 ('00000000-0000-4000-8000-0000001915d1','00000000-0000-4000-8000-0000001915b1','emergency','text',false,'self');
insert into public.workspace_field_values(workspace_id,member_id,definition_id,text_value) values
 ('00000000-0000-4000-8000-0000001915b1','00000000-0000-4000-8000-0000001915c2','00000000-0000-4000-8000-0000001915d1','CANARY-A-ANSWER'),
 ('00000000-0000-4000-8000-0000001915b1','00000000-0000-4000-8000-0000001915c3','00000000-0000-4000-8000-0000001915d1','B-ANSWER');
insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                             currency, member_name, workspace_name, issuer_name, signature)
values ('00000000-0000-4000-8000-0000001915b1','00000000-0000-4000-8000-0000001915c2','00000000-0000-4000-8000-0000001915c1',
        'R-1','A','[]'::jsonb,10000,'EUR','A','Rights','Owner','sig');

create temp table seen(k text primary key, v jsonb);
grant select, insert on seen to authenticated;

-- ── the clock: calendar months, not 30 days ─────────────────────────
select is(public.rights_due_on('2025-01-31 12:00+00','Europe/Paris',1), '2025-02-28'::date, 'received 31 January: due on the last day of February');
select is(public.rights_due_on('2024-01-31 12:00+00','Europe/Paris',1), '2024-02-29'::date, 'in a leap year, on 29 February');
select is(public.rights_due_on('2024-02-29 10:00+00','Europe/Paris',1), '2024-03-29'::date, 'received 29 February: due on 29 March');
select is(public.rights_due_on('2025-12-15 10:00+00','Europe/Paris',1), '2026-01-15'::date, 'the month runs over the year end');
select is(public.rights_due_on('2025-03-31 23:30+00','Europe/Paris',1), '2025-05-01'::date, '23:30 UTC on 31 March is already 1 April in Paris');
select is(public.rights_due_on('2025-03-31 23:30+00','UTC',1), '2025-04-30'::date, 'and still 31 March in UTC');
select is(public.rights_due_on('2025-01-31 12:00+00','Europe/Paris',3), '2025-04-30'::date, 'the extension counts three months from the receipt');

-- ── A asks ──────────────────────────────────────────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001915a2","role":"authenticated"}',true);
set local role authenticated;
insert into seen values ('first', public.submit_rights_request('00000000-0000-4000-8000-0000001915b1','access','CANARY-A-REQUEST','00000000-0000-4000-8000-000000191501'));
insert into seen values ('again', public.submit_rights_request('00000000-0000-4000-8000-0000001915b1','access','CANARY-A-REQUEST','00000000-0000-4000-8000-000000191501'));
select throws_ok($$select public.submit_rights_request('00000000-0000-4000-8000-0000001915b2','access','x')$$,
  'you have no membership in this space; contact its controller directly', 'a space the person never belonged to is refused');
insert into seen values ('export', public.export_my_data('00000000-0000-4000-8000-0000001915b1'));
reset role;
select is((select v->>'status' from seen where k = 'first'), 'received', 'the request is received');
select is((select (v->>'due_on')::date from seen where k = 'first'),
          public.rights_due_on((select (v->>'received_at')::timestamptz from seen where k = 'first'), 'Europe/Paris', 1),
          'and due one calendar month after receipt, in the space''s time zone');
select is((select v->>'id' from seen where k = 'again'), (select v->>'id' from seen where k = 'first'), 'a repeated submission returns the same request');
select is((select count(*)::int from public.rights_requests where workspace_id = '00000000-0000-4000-8000-0000001915b1'), 1, 'and creates no second row');

-- ── the access export ───────────────────────────────────────────────
select ok((select v::text from seen where k = 'export') like '%CANARY-A-NAME%', 'A''s export carries the profile canary');
select ok((select v::text from seen where k = 'export') like '%CANARY-A-ANSWER%', 'the custom-answer canary');
select ok((select v::text from seen where k = 'export') like '%CANARY-A-REQUEST%', 'and the rights-request canary');
select ok((select v::text from seen where k = 'export') not like '%B-NAME%' and (select v::text from seen where k = 'export') not like '%B-ANSWER%', 'and nothing of B');
select is(jsonb_array_length((select v->'coverage'->'not_covered' from seen where k = 'export')), 3, 'it names what it does not cover instead of claiming completeness');

-- ── who may see and decide ──────────────────────────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001915a4","role":"authenticated"}',true);
set local role authenticated;
insert into seen values ('plain_reads', to_jsonb((select count(*) from public.rights_requests)));
select throws_ok(format($$select public.extend_rights_request(%L,'Too many requests this month')$$, (select v->>'id' from seen where k = 'first')),
  'only the space''s controller extends a rights request', 'a member without viewPersonalData cannot extend it');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001915a5","role":"authenticated"}',true);
insert into seen values ('foreign_reads', to_jsonb((select count(*) from public.rights_requests)));
select throws_ok(format($$select public.complete_rights_request(%L,'{"removed":[{"store":"profile"}]}'::jsonb)$$, (select v->>'id' from seen where k = 'first')),
  'only the space''s controller decides a rights request', 'the owner of another space cannot decide it by its id');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001915a1","role":"authenticated"}',true);
insert into seen values ('owner_reads', to_jsonb((select count(*) from public.rights_requests)));
reset role;
select is((select v from seen where k = 'plain_reads'), '0'::jsonb, 'a plain member reads no request of another');
select is((select v from seen where k = 'foreign_reads'), '0'::jsonb, 'nor does the owner of another space');
select is((select v from seen where k = 'owner_reads'), '1'::jsonb, 'the controller reads it');

-- ── the extension ───────────────────────────────────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001915a1","role":"authenticated"}',true);
set local role authenticated;
insert into seen values ('extended', public.extend_rights_request((select (v->>'id')::uuid from seen where k = 'first'), 'Several archived stores must be searched'));
select throws_ok(format($$select public.extend_rights_request(%L,'Another reason entirely')$$, (select v->>'id' from seen where k = 'first')),
  'only an open request that was never extended can be extended', 'a request is extended once');
insert into seen values ('late', public.record_rights_request('00000000-0000-4000-8000-0000001915b1','00000000-0000-4000-8000-0000001915c3','erasure','By letter', now() - interval '40 days'));
select throws_ok(format($$select public.extend_rights_request(%L,'Several archived stores must be searched')$$, (select v->>'id' from seen where k = 'late')),
  'an extension is notified within the first month, not after it', 'an extension after the first month is refused');
reset role;
select is((select (v->>'extended_due_on')::date from seen where k = 'extended'),
          public.rights_due_on((select (v->>'received_at')::timestamptz from seen where k = 'first'), 'Europe/Paris', 3),
          'the extension runs two further months');
select ok((select extended_due_on is null and due_on = public.rights_due_on(received_at, timezone, 1)
             from public.rights_requests where id = (select (v->>'id')::uuid from seen where k = 'late')),
  'the late request keeps its original history');
select throws_ok(format($$update public.rights_requests set due_on = due_on + 30 where id = %L$$, (select v->>'id' from seen where k = 'first')),
  'a rights request keeps its receipt and its first deadline', 'nobody moves the first deadline, not even the database owner');

-- ── the outcome ─────────────────────────────────────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001915a1","role":"authenticated"}',true);
set local role authenticated;
select throws_like(format($$select public.complete_rights_request(%L,'{"retained":[{"store":"invoices"}]}'::jsonb)$$, (select v->>'id' from seen where k = 'first')),
  'an outcome names each store%', 'kept data without basis and period is refused');
select lives_ok(format($$select public.complete_rights_request(%L,'{"removed":[{"store":"custom_answers"}],"retained":[{"store":"invoices","basis":"accounting evidence","period":"10 years"}],"pending_external":[{"store":"other_installations"}]}'::jsonb)$$, (select v->>'id' from seen where k = 'first')),
  'the controller completes it with a manifest');
select throws_ok(format($$select public.complete_rights_request(%L,'{"removed":[{"store":"profile"}]}'::jsonb)$$, (select v->>'id' from seen where k = 'first')),
  'a closed rights request stays closed', 'a completed request stays closed');
reset role;

-- ── erasure: what goes and what stays ───────────────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001915a2","role":"authenticated"}',true);
set local role authenticated;
insert into seen values ('preview', public.preview_my_erasure('00000000-0000-4000-8000-0000001915b1'));
select lives_ok($$select public.erase_my_membership('00000000-0000-4000-8000-0000001915b1')$$, 'A erases');
insert into seen values ('after', public.submit_rights_request('00000000-0000-4000-8000-0000001915b1','erasure','Please confirm what was kept'));
insert into seen values ('mine', public.my_rights_requests());
reset role;
select ok((select v->'removed' from seen where k = 'preview') @> '[{"store":"custom_answers","count":1}]', 'the preview says the custom answer goes');
select ok((select v->'retained' from seen where k = 'preview') @> '[{"store":"invoices","count":1}]', 'and the invoice stays');
select ok((select v->'retained' from seen where k = 'preview') @> '[{"store":"membership_row"}]'
          and (select v::text from seen where k = 'preview') like '%pseudonymous%', 'and the membership row is called pseudonymous, not anonymous');
select is((select count(*)::int from public.invoices where member_id = '00000000-0000-4000-8000-0000001915c2'), 1, 'after erasure the invoice is still there');
select is((select count(*)::int from public.workspace_field_values where member_id = '00000000-0000-4000-8000-0000001915c2'), 0, 'and the answer is not');
select is(jsonb_array_length((select v from seen where k = 'mine')), 2, 'A, now exited, still files a request and sees both');

select * from finish();
rollback;
