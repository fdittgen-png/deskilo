-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1847 B: the public network descriptor and server-side revalidation of the
-- negotiated operation version (`x-deskilo-operation: <id>@<version>`).
-- The descriptor is anonymous and names only protocol, capabilities and
-- operation versions; management is not advertised. A request with no
-- header is a client from before negotiation (the captured released shape)
-- and means the operation's unlabelled version. A version the server does
-- not list, a claim for another operation or a malformed claim is refused
-- by name; a claim grants nothing. Retiring a version (simulated by
-- replacing the descriptor inside this transaction) refuses both the
-- unlabelled client and a stale negotiated one, while the current version
-- is accepted.
begin;
select plan(21);
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000001847'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@negotiation.test','',now(),now(),now() from unnest(array['d1','d3']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment)
values('00000000-0000-4000-8000-0000001847e1','Negotiated office','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001847d1','dev'),
('00000000-0000-4000-8000-0000001847e2','Unpublished office','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001847d1','dev'),
('00000000-0000-4000-8000-0000001847e3','Second negotiated office','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001847d1','dev');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status)
values('00000000-0000-4000-8000-0000001847f1','00000000-0000-4000-8000-0000001847e1','00000000-0000-4000-8000-0000001847d1',true,true,'active'),
('00000000-0000-4000-8000-0000001847f2','00000000-0000-4000-8000-0000001847e2','00000000-0000-4000-8000-0000001847d1',true,true,'active'),
('00000000-0000-4000-8000-0000001847f3','00000000-0000-4000-8000-0000001847e3','00000000-0000-4000-8000-0000001847d1',true,true,'active');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001847d1","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.save_workspace_public_page('00000000-0000-4000-8000-0000001847e1','{"host_type":"company"}',true)$$,'the owner publishes the first office');
select lives_ok($$select public.save_workspace_public_page('00000000-0000-4000-8000-0000001847e3','{"host_type":"company"}',true)$$,'the owner publishes the second office');
reset role;

-- network.descriptor.read: anonymous, external operations only.
select set_config('request.jwt.claims','{}',true);
set local role anon;
select is(public.public_network_descriptor()->>'protocol','deskilo.public-network','network.descriptor.read: anonymous reads the descriptor');
select ok(public.public_network_descriptor()->'operations' @> '[{"id":"workspace.profile.request","versions":[1],"unlabelled":1}]','the descriptor names the participant operation, its versions and its unlabelled version');
select ok(public.public_network_descriptor()::text !~ '(publication\.page|my_workspace_public_page|save_workspace_public_page)','management operations are not advertised');
select ok(not (public.public_network_descriptor() ?| array['schema_version','build','flags','lifecycle','configuration']),'no configuration, build, schema level, flag or invented lifecycle');
select throws_ok($$select public.public_network_require('workspace.profile.request')$$,'42501',null,'the revalidation helper is not callable by a client');
select set_config('request.headers','{"x-deskilo-operation":"workspace.profile.request@1"}',true);
select throws_ok($$select public.request_public_workspace_profile('00000000-0000-4000-8000-0000001847e1')$$,'42501',null,'a version claim does not let anonymous act as a participant');
reset role;
-- workspace.profile.request: the server revalidates the claim.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001847d3","role":"authenticated"}',true);
set local role authenticated;
select set_config('request.headers','{}',true);
select lives_ok($$select public.request_public_workspace_profile('00000000-0000-4000-8000-0000001847e1')$$,'a client from before negotiation (no header) is the unlabelled version and is accepted');
select set_config('request.headers','{"x-deskilo-operation":"workspace.profile.request@1"}',true);
select lives_ok($$select public.request_public_workspace_profile('00000000-0000-4000-8000-0000001847e3')$$,'a client that negotiated version 1 is accepted');
select set_config('request.headers','{"x-deskilo-operation":"workspace.profile.request@2"}',true);
select throws_ok($$select public.request_public_workspace_profile('00000000-0000-4000-8000-0000001847e3')$$,'P0001','unsupported public network version','a version the server does not list is refused by name');
select set_config('request.headers','{"x-deskilo-operation":"directory.sources.register@1"}',true);
select throws_ok($$select public.request_public_workspace_profile('00000000-0000-4000-8000-0000001847e3')$$,'P0001','unsupported public network version','a claim for another operation is refused');
select set_config('request.headers','{"x-deskilo-operation":"workspace.profile.request"}',true);
select throws_ok($$select public.request_public_workspace_profile('00000000-0000-4000-8000-0000001847e3')$$,'P0001','unsupported public network version','a malformed claim is refused');
select set_config('request.headers','{"x-deskilo-operation":"workspace.profile.request@1"}',true);
select throws_ok($$select public.request_public_workspace_profile('00000000-0000-4000-8000-0000001847e2')$$,'P0001','workspace not published','a negotiated version grants nothing: a draft stays unpublished');
select ok(not public.is_member_of('00000000-0000-4000-8000-0000001847e1'),'the accepted request still grants no membership');

-- directory.sources.register: the same revalidation.
select set_config('request.headers','{"x-deskilo-operation":"directory.sources.register@1"}',true);
select lives_ok($$select public.register_public_directory('https://negotiated-1847.example','sb_publishable_negotiation_1847')$$,'directory.sources.register: version 1 is accepted');
select set_config('request.headers','{"x-deskilo-operation":"directory.sources.register@9"}',true);
select throws_ok($$select public.register_public_directory('https://negotiated-1847.example','sb_publishable_negotiation_1847')$$,'P0001','unsupported public network version','directory.sources.register: an unknown version is refused');
reset role;
-- A retired version: the descriptor (replaced inside this transaction)
-- keeps only version 2 of directory.sources.register.
create or replace function public.public_network_descriptor() returns jsonb language sql immutable set search_path = public as $retired$
  select '{"protocol":"deskilo.public-network","protocol_versions":[1],"capabilities":["operation_header"],"operations":[{"id":"directory.sources.register","versions":[2],"requires":[],"unlabelled":1},{"id":"workspace.profile.request","versions":[1],"requires":[],"unlabelled":1}]}'::jsonb
$retired$;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001847d3","role":"authenticated"}',true);
set local role authenticated;
select set_config('request.headers','{}',true);
select throws_ok($$select public.register_public_directory('https://negotiated-1847.example','sb_publishable_negotiation_1847')$$,'P0001','unsupported public network version','after version 1 is retired, a client from before negotiation receives the named refusal');
select set_config('request.headers','{"x-deskilo-operation":"directory.sources.register@1"}',true);
select throws_ok($$select public.register_public_directory('https://negotiated-1847.example','sb_publishable_negotiation_1847')$$,'P0001','unsupported public network version','a stale negotiated version 1 is refused after retirement');
select set_config('request.headers','{"x-deskilo-operation":"directory.sources.register@2"}',true);
select lives_ok($$select public.register_public_directory('https://negotiated-1847.example','sb_publishable_negotiation_1847')$$,'the current version is accepted after retirement');
reset role;
select is((select count(*) from public.public_directory_sources where origin='https://negotiated-1847.example'),1::bigint,'one registration however many attempts');
select * from finish();
rollback;
