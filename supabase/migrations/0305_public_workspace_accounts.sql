-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- #1791: deliberately published projections, account contacts and employment.
create table public.account_contact_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  available boolean not null default false
);
select public.ensure_system_columns('account_contact_settings');
alter table public.account_contact_settings enable row level security;
revoke all on public.account_contact_settings from public,anon,authenticated;
create policy mcp_delegated_deny on public.account_contact_settings as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create table public.member_public_contact (
  member_id uuid primary key references public.members(id) on delete cascade,
  visible boolean not null default false
);
select public.ensure_system_columns('member_public_contact');
alter table public.member_public_contact enable row level security;
revoke all on public.member_public_contact from public,anon,authenticated;
create policy mcp_delegated_deny on public.member_public_contact as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create table public.member_employment (
  member_id uuid primary key references public.members(id) on delete cascade,
  employed boolean not null default false
);
select public.ensure_system_columns('member_employment');
alter table public.member_employment enable row level security;
revoke all on public.member_employment from public,anon,authenticated;
create policy mcp_delegated_deny on public.member_employment as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create table public.workspace_public_pages (
 workspace_id uuid primary key references public.workspaces(id) on delete cascade,
 published boolean not null default false,
 document jsonb not null default '{}'::jsonb
);
select public.ensure_system_columns('workspace_public_pages');
alter table public.workspace_public_pages enable row level security;
revoke all on public.workspace_public_pages from public,anon,authenticated;
create policy mcp_delegated_deny on public.workspace_public_pages as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
-- Contains ONLY the projection approved for public display. No invitation code,
-- private floor plan, occupancy, salary, account email or operator stamps.
create table public.public_workspace_cards (
 workspace_id uuid primary key references public.workspaces(id) on delete cascade,
 name text not null, search_text text not null, document jsonb not null,
 updated_at timestamptz not null default now()
);
select public.ensure_system_columns('public_workspace_cards');
alter table public.public_workspace_cards enable row level security;
revoke all on public.public_workspace_cards from public,anon,authenticated;
grant select(workspace_id,name,search_text,document,updated_at) on public.public_workspace_cards to anon,authenticated;
create policy published_cards on public.public_workspace_cards for select to anon,authenticated using(true);
create policy mcp_delegated_deny on public.public_workspace_cards as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create index public_workspace_cards_name_idx on public.public_workspace_cards(lower(name),workspace_id);

-- A directory records public API endpoints, never sessions or private listing
-- copies. Clients obtain the current projection directly, so withdrawal is live.
create table public.public_directory_sources (
 origin text primary key check (origin ~ '^https://[a-zA-Z0-9][a-zA-Z0-9.-]+(:[0-9]+)?$' and length(origin)<=512),
 publishable_key text not null check (length(publishable_key) between 1 and 4096),
 registered_by uuid references auth.users(id) on delete set null
);
select public.ensure_system_columns('public_directory_sources');
alter table public.public_directory_sources enable row level security;
revoke all on public.public_directory_sources from public,anon,authenticated;
grant select(origin,publishable_key) on public.public_directory_sources to anon,authenticated;
create policy public_directory_read on public.public_directory_sources for select to anon,authenticated using(true);
create policy mcp_delegated_deny on public.public_directory_sources as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create function public.public_workspace_document(p_workspace uuid) returns jsonb
language sql stable security definer set search_path=public as $$
 select page.document || jsonb_build_object('name',w.name,'currency',w.currency_code,
  'booking_unit',coalesce(w.booking_rules->>'granularity','flexible'),
  'contacts',coalesce((select jsonb_agg(jsonb_build_object('user_id',m.user_id,
    'name',coalesce(p.display_name,m.managed_name,''),'owner',m.is_owner,
    'available',coalesce(s.available,false)) order by m.is_owner desc,m.id)
   from public.members m left join public.profiles p on p.id=m.user_id
   left join public.account_contact_settings s on s.user_id=m.user_id
   left join public.member_public_contact c on c.member_id=m.id
   where m.workspace_id=w.id and m.status='active' and
    (m.is_owner or (m.is_admin and c.visible))), '[]'::jsonb))
 from public.workspace_public_pages page join public.workspaces w on w.id=page.workspace_id
 where page.workspace_id=p_workspace;
$$;
revoke execute on function public.public_workspace_document(uuid) from public,anon,authenticated;
create function public.refresh_public_workspace_card(p_workspace uuid) returns void
language plpgsql security definer set search_path=public as $$
begin
 if exists(select 1 from public.workspace_public_pages where workspace_id=p_workspace and published)
    and public.feature_effective(p_workspace,'publicListings') then
  insert into public.public_workspace_cards(workspace_id,name,search_text,document)
   select w.id,w.name,w.name || ' ' || coalesce(public.public_workspace_document(w.id)->>'address',''),public.public_workspace_document(w.id) from public.workspaces w where w.id=p_workspace
   on conflict(workspace_id) do update set name=excluded.name,search_text=excluded.search_text,document=excluded.document,updated_at=now();
 else delete from public.public_workspace_cards where workspace_id=p_workspace; end if;
end;
$$;
revoke execute on function public.refresh_public_workspace_card(uuid) from public,anon,authenticated;
create function public.refresh_public_profile_cards() returns trigger
language plpgsql security definer set search_path=public as $$
declare v_workspace uuid; v_row jsonb;
begin
 v_row:=case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
 if tg_table_name='workspaces' then
  perform public.refresh_public_workspace_card((v_row->>'id')::uuid);
 elsif tg_table_name in ('workspace_public_pages','members') then
  perform public.refresh_public_workspace_card((v_row->>'workspace_id')::uuid);
 else
  for v_workspace in select distinct workspace_id from public.members where
   (tg_table_name='member_public_contact' and id=(v_row->>'member_id')::uuid)
   or (tg_table_name='account_contact_settings' and user_id=(v_row->>'user_id')::uuid)
   or (tg_table_name='profiles' and user_id=(v_row->>'id')::uuid) loop
   perform public.refresh_public_workspace_card(v_workspace);
  end loop;
 end if;
 return null;
end;
$$;
revoke execute on function public.refresh_public_profile_cards() from public,anon,authenticated;
create trigger refresh_public_page after insert or update or delete on public.workspace_public_pages
 for each row execute function public.refresh_public_profile_cards();
create trigger refresh_public_members after insert or update or delete on public.members
 for each row execute function public.refresh_public_profile_cards();
create trigger refresh_public_profile after update of display_name on public.profiles
 for each row execute function public.refresh_public_profile_cards();
create trigger refresh_public_workspace after update of name,feature_flags,booking_rules,currency_code on public.workspaces
 for each row execute function public.refresh_public_profile_cards();
create trigger refresh_public_contact after insert or update or delete on public.account_contact_settings
 for each row execute function public.refresh_public_profile_cards();
create trigger refresh_public_admin after insert or update or delete on public.member_public_contact
 for each row execute function public.refresh_public_profile_cards();

create function public.save_workspace_public_page(p_workspace uuid,p_document jsonb,p_published boolean)
returns jsonb language plpgsql security definer set search_path=public as $$
declare k text; v jsonb;
begin
 perform public.mcp_require_native();
 if auth.uid() is null or not public.is_owner_of(p_workspace) then raise exception 'owner required'; end if;
 if p_document is null or jsonb_typeof(p_document)<>'object' or octet_length(p_document::text)>20000
  or p_published is null then raise exception 'invalid public page'; end if;
 for k,v in select * from jsonb_each(p_document) loop
  if k not in ('host_type','description','address','email','phone','website','image_url','plan_url','plans','latitude','longitude')
   or jsonb_typeof(v)<>'string' or length(v #>> '{}')>4000 then raise exception 'invalid public field'; end if;
  if k in ('website','image_url','plan_url') and v #>> '{}'<>'' and v #>> '{}' !~ '^https://[^[:space:]@]+$'
   then raise exception 'public links require HTTPS'; end if;
 end loop;
 if coalesce(p_document->>'host_type','') not in ('association','company','person') then raise exception 'invalid host type'; end if;
 if coalesce(p_document->>'latitude','')<>'' or coalesce(p_document->>'longitude','')<>'' then
  if (p_document->>'latitude')::numeric not between -90 and 90 or (p_document->>'longitude')::numeric not between -180 and 180
   or nullif(p_document->>'latitude','') is null or nullif(p_document->>'longitude','') is null then raise exception 'invalid coordinates'; end if;
 end if;
 insert into public.workspace_public_pages(workspace_id,document,published) values(p_workspace,p_document,p_published)
 on conflict(workspace_id) do update set document=excluded.document,published=excluded.published;
 update public.workspaces set feature_flags=feature_flags || jsonb_build_object('publicListings',p_published) where id=p_workspace;
 if not p_published then delete from public.public_workspace_cards where workspace_id=p_workspace; end if;
 return public.public_workspace_document(p_workspace);
end;
$$;
revoke execute on function public.save_workspace_public_page(uuid,jsonb,boolean) from public,anon;
grant execute on function public.save_workspace_public_page(uuid,jsonb,boolean) to authenticated;
create function public.my_workspace_public_page(p_workspace uuid) returns jsonb
language plpgsql stable security definer set search_path=public as $$
begin
 perform public.mcp_require_native();
 if auth.uid() is null or not public.is_owner_of(p_workspace) then raise exception 'owner required'; end if;
 return coalesce((select jsonb_build_object('published',published,'document',public.public_workspace_document(p_workspace))
 from public.workspace_public_pages where workspace_id=p_workspace),jsonb_build_object('published',false,'document','{}'::jsonb));
end;
$$;
revoke execute on function public.my_workspace_public_page(uuid) from public,anon;
grant execute on function public.my_workspace_public_page(uuid) to authenticated;

create function public.register_public_directory(p_origin text,p_key text) returns void
language plpgsql security definer set search_path=public as $$
declare v_payload jsonb;
begin
 perform public.mcp_require_native();
 if auth.uid() is null then raise exception 'not authenticated'; end if;
 if p_key like 'sb_publishable_%' then null;
 elsif p_key ~ '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$' then
  begin
   v_payload:=convert_from(decode(translate(split_part(p_key,'.',2),'-_','+/') || repeat('=',(4-length(split_part(p_key,'.',2))%4)%4),'base64'),'UTF8')::jsonb;
  exception when others then raise exception 'publishable key required'; end;
  if v_payload->>'role' is distinct from 'anon' or v_payload ? 'sub' then raise exception 'publishable key required'; end if;
 else raise exception 'publishable key required'; end if;
 if (select count(*) from public.public_directory_sources where registered_by=auth.uid())>=20
  and not exists(select 1 from public.public_directory_sources where origin=p_origin and registered_by=auth.uid())
  then raise exception 'directory limit reached'; end if;
 insert into public.public_directory_sources(origin,publishable_key,registered_by) values(p_origin,p_key,auth.uid())
 on conflict(origin) do update set publishable_key=excluded.publishable_key
 where public.public_directory_sources.registered_by=auth.uid();
end;
$$;
revoke execute on function public.register_public_directory(text,text) from public,anon;
grant execute on function public.register_public_directory(text,text) to authenticated;

create function public.my_contact_availability() returns boolean language plpgsql stable security definer set search_path=public as $$
begin
 perform public.mcp_require_native(); if auth.uid() is null then raise exception 'not authenticated'; end if;
 return coalesce((select available from public.account_contact_settings where user_id=auth.uid()),false);
end;
$$;
revoke execute on function public.my_contact_availability() from public,anon;
grant execute on function public.my_contact_availability() to authenticated;
create function public.set_contact_availability(p_available boolean) returns void language plpgsql security definer set search_path=public as $$
begin
 perform public.mcp_require_native(); if auth.uid() is null then raise exception 'not authenticated'; end if;
 insert into public.account_contact_settings(user_id,available) values(auth.uid(),p_available)
 on conflict(user_id) do update set available=excluded.available;
end;
$$;
revoke execute on function public.set_contact_availability(boolean) from public,anon;
grant execute on function public.set_contact_availability(boolean) to authenticated;
create function public.my_admin_visibility(p_workspace uuid,p_visible boolean default null) returns boolean
language plpgsql security definer set search_path=public as $$
declare v_member uuid;
begin
 perform public.mcp_require_native(); if auth.uid() is null then raise exception 'not authenticated'; end if;
 select id into v_member from public.members where workspace_id=p_workspace and user_id=auth.uid() and status='active' and (is_admin or is_owner);
 if v_member is null then raise exception 'administrator required'; end if;
 if p_visible is not null then
  insert into public.member_public_contact(member_id,visible) values(v_member,p_visible)
  on conflict(member_id) do update set visible=excluded.visible;
 end if;
 return coalesce((select visible from public.member_public_contact where member_id=v_member),false);
end;
$$;
revoke execute on function public.my_admin_visibility(uuid,boolean) from public,anon;
grant execute on function public.my_admin_visibility(uuid,boolean) to authenticated;
create function public.member_employment_status(p_member uuid,p_employed boolean default null) returns boolean
language plpgsql security definer set search_path=public as $$
declare v_member public.members;
begin
 perform public.mcp_require_native(); if auth.uid() is null then raise exception 'not authenticated'; end if;
 select * into v_member from public.members where id=p_member;
 if v_member.id is null or not (coalesce(v_member.user_id=auth.uid(),false) or public.is_owner_of(v_member.workspace_id)) then raise exception 'employment unavailable'; end if;
 if p_employed is not null then
  if not public.is_owner_of(v_member.workspace_id) then raise exception 'owner required'; end if;
  insert into public.member_employment(member_id,employed) values(p_member,p_employed)
  on conflict(member_id) do update set employed=excluded.employed;
 end if;
 return coalesce((select employed from public.member_employment where member_id=p_member),false);
end;
$$;
revoke execute on function public.member_employment_status(uuid,boolean) from public,anon;
grant execute on function public.member_employment_status(uuid,boolean) to authenticated;

create table public.account_conversations (
 id uuid primary key default gen_random_uuid(),
 user_a uuid references auth.users(id) on delete set null,
 user_b uuid references auth.users(id) on delete set null,
 updated_at timestamptz not null default now(),
 check(user_a<user_b), unique(user_a,user_b)
);
select public.ensure_system_columns('account_conversations');
alter table public.account_conversations enable row level security;
revoke all on public.account_conversations from public,anon,authenticated;
create policy mcp_delegated_deny on public.account_conversations as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create index account_conversations_a_idx on public.account_conversations(user_a,updated_at,id);
create index account_conversations_b_idx on public.account_conversations(user_b,updated_at,id);
create table public.account_messages (
 id uuid primary key default gen_random_uuid(),
 conversation_id uuid not null references public.account_conversations(id) on delete cascade,
 author_id uuid references auth.users(id) on delete set null,
 body text not null check(length(btrim(body)) between 1 and 4000),
 created_at timestamptz not null default now()
);
select public.ensure_system_columns('account_messages');
alter table public.account_messages enable row level security;
revoke all on public.account_messages from public,anon,authenticated;
create policy mcp_delegated_deny on public.account_messages as restrictive for all to authenticated
 using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create index account_messages_thread_idx on public.account_messages(conversation_id,created_at,id);
create function public.search_available_accounts(p_query text,p_before uuid default null) returns jsonb
language plpgsql stable security definer set search_path=public as $$
begin
 perform public.mcp_require_native(); if auth.uid() is null then raise exception 'not authenticated'; end if;
 if p_query is null or length(btrim(p_query)) not between 2 and 100 then return '[]'::jsonb; end if;
 return coalesce((select jsonb_agg(x) from (select p.id,p.display_name as name from public.profiles p
 join public.account_contact_settings s on s.user_id=p.id and s.available
 where p.id<>auth.uid() and position(lower(btrim(p_query)) in lower(p.display_name))>0
 and (p_before is null or p.id>p_before) order by p.id limit 50) x),'[]'::jsonb);
end;
$$;
revoke execute on function public.search_available_accounts(text,uuid) from public,anon;
grant execute on function public.search_available_accounts(text,uuid) to authenticated;
create function public.send_account_message(p_recipient uuid,p_body text,p_expected_account uuid) returns uuid
language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_a uuid; v_b uuid;
begin
 perform public.mcp_require_native();
 if auth.uid() is null or p_expected_account is distinct from auth.uid() then raise exception 'account changed'; end if;
 if p_recipient is null or p_recipient=auth.uid() or p_body is null or length(btrim(p_body)) not between 1 and 4000 then raise exception 'invalid message'; end if;
 v_a:=least(auth.uid(),p_recipient);v_b:=greatest(auth.uid(),p_recipient);
 perform pg_advisory_xact_lock(hashtextextended(v_a::text||v_b::text,1791));
 select id into v_id from public.account_conversations where user_a=v_a and user_b=v_b;
 if v_id is null then
  if not coalesce((select available from public.account_contact_settings where user_id=p_recipient),false) then raise exception 'recipient unavailable'; end if;
  insert into public.account_conversations(user_a,user_b) values(v_a,v_b) returning id into v_id;
 end if;
 -- Bounded native inbox traffic. No public listing or messaging role grants.
 if (select count(*) from public.account_messages where author_id=auth.uid() and created_at>now()-interval '1 minute')>=30 then raise exception 'message limit reached'; end if;
 insert into public.account_messages(conversation_id,author_id,body) values(v_id,auth.uid(),btrim(p_body));
 update public.account_conversations set updated_at=now() where id=v_id;
 return v_id;
end;
$$;
revoke execute on function public.send_account_message(uuid,text,uuid) from public,anon;
grant execute on function public.send_account_message(uuid,text,uuid) to authenticated;
create index account_messages_author_time_idx on public.account_messages(author_id,created_at);
create function public.my_account_conversations(p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path=public as $$
begin
 perform public.mcp_require_native(); if auth.uid() is null then raise exception 'not authenticated'; end if;
 if (p_before_at is null)<>(p_before_id is null) then raise exception 'invalid cursor'; end if;
 return coalesce((select jsonb_agg(x order by x.updated_at desc,x.id desc) from (
 select c.id,c.updated_at,case when c.user_a=auth.uid() then c.user_b else c.user_a end as recipient,
 coalesce(p.display_name,'') as name from public.account_conversations c left join public.profiles p
 on p.id=case when c.user_a=auth.uid() then c.user_b else c.user_a end
 where auth.uid() in(c.user_a,c.user_b) and (p_before_at is null or (c.updated_at,c.id)<(p_before_at,p_before_id))
 order by c.updated_at desc,c.id desc limit 50) x),'[]'::jsonb);
end;
$$;
revoke execute on function public.my_account_conversations(timestamptz,uuid) from public,anon;
grant execute on function public.my_account_conversations(timestamptz,uuid) to authenticated;
create function public.my_account_messages(p_conversation uuid,p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path=public as $$
begin
 perform public.mcp_require_native();
 if auth.uid() is null or not exists(select 1 from public.account_conversations where id=p_conversation and auth.uid() in(user_a,user_b)) then raise exception 'conversation unavailable'; end if;
 if (p_before_at is null)<>(p_before_id is null) then raise exception 'invalid cursor'; end if;
 return coalesce((select jsonb_agg(x order by x.created_at desc,x.id desc) from (
 select id,body,created_at,author_id=auth.uid() as is_mine from public.account_messages where conversation_id=p_conversation
 and (p_before_at is null or (created_at,id)<(p_before_at,p_before_id)) order by created_at desc,id desc limit 50) x),'[]'::jsonb);
end;
$$;
revoke execute on function public.my_account_messages(uuid,timestamptz,uuid) from public,anon;
grant execute on function public.my_account_messages(uuid,timestamptz,uuid) to authenticated;

-- Workspace exports exclude account conversations, but a person's own data
-- export includes their correspondence and private contact/employment settings.
do $export$
declare v_def text; v_anchor text := $a$    'exported_at', now(),$a$;
begin
 v_def:=pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
 if position(v_anchor in v_def)=0 then raise exception '0305: export anchor missing'; end if;
 execute replace(v_def,v_anchor,$a$    'exported_at', now(),
    'public_directory_sources',(select coalesce(jsonb_agg(to_jsonb(s)),'[]'::jsonb) from public.public_directory_sources s where registered_by=auth.uid()),
    'account_contact_settings',(select to_jsonb(s) from public.account_contact_settings s where user_id=auth.uid()),
    'member_public_contact',(select coalesce(jsonb_agg(to_jsonb(s)),'[]'::jsonb) from public.member_public_contact s join public.members m on m.id=s.member_id where m.user_id=auth.uid()),
    'member_employment',(select coalesce(jsonb_agg(to_jsonb(s)),'[]'::jsonb) from public.member_employment s join public.members m on m.id=s.member_id where m.user_id=auth.uid()),
    'account_conversations',(select coalesce(jsonb_agg(to_jsonb(c)),'[]'::jsonb) from public.account_conversations c where auth.uid() in(user_a,user_b)),
    'account_messages',(select coalesce(jsonb_agg(to_jsonb(m)),'[]'::jsonb) from public.account_messages m join public.account_conversations c on c.id=m.conversation_id where auth.uid() in(c.user_a,c.user_b)),$a$);
end;
$export$;
-- Public admission still enters the ordinary quorum-controlled member_join
-- flow. Knowing a public workspace ID does not activate membership.
create function public.request_public_workspace_profile(p_workspace uuid) returns void
language plpgsql security definer set search_path=public as $$
declare v_code text;
begin
 perform public.mcp_require_native(); if auth.uid() is null then raise exception 'not authenticated'; end if;
 if not exists(select 1 from public.public_workspace_cards where workspace_id=p_workspace) then raise exception 'workspace not published'; end if;
 select invite_code into strict v_code from public.workspaces where id=p_workspace;
 perform public.join_workspace(v_code);
end;
$$;
revoke execute on function public.request_public_workspace_profile(uuid) from public,anon;
grant execute on function public.request_public_workspace_profile(uuid) to authenticated;
create function public.my_account_conversation_with(p_recipient uuid) returns uuid
language plpgsql stable security definer set search_path=public as $$
begin
 perform public.mcp_require_native(); if auth.uid() is null then raise exception 'not authenticated'; end if;
 return (select id from public.account_conversations where user_a=least(auth.uid(),p_recipient) and user_b=greatest(auth.uid(),p_recipient));
end;
$$;
revoke execute on function public.my_account_conversation_with(uuid) from public,anon;
grant execute on function public.my_account_conversation_with(uuid) to authenticated;

create or replace function public.feature_registry()
returns jsonb
language sql
immutable
set search_path = public
as $registry$
  select '{
    "calendarTab": {"parent": null, "default": true, "core": true},
    "eventsTab": {"parent": null, "default": true, "core": true},
    "moneyTab": {"parent": null, "default": true, "core": true},
    "services": {"parent": "moneyTab", "default": true, "core": true},
    "accessorySupplements": {"parent": "moneyTab", "default": false, "core": false},
    "onlinePayments": {"parent": "moneyTab", "default": false, "core": false},
    "invoicing": {"parent": "moneyTab", "default": true, "core": true},
    "adminInvoicing": {"parent": "invoicing", "default": false, "core": false},
    "pdfExport": {"parent": null, "default": true, "core": true},
    "seriesBooking": {"parent": null, "default": true, "core": true},
    "bookForOthers": {"parent": null, "default": true, "core": true},
    "pushNotifications": {"parent": null, "default": true, "core": true},
    "adminSeatBlocking": {"parent": null, "default": false, "core": false},
    "levelBooking": {"parent": null, "default": false, "core": false},
    "adminLevelAssign": {"parent": "levelBooking", "default": false, "core": false},
    "kioskMode": {"parent": null, "default": true, "core": false},
    "nfcBadges": {"parent": "kioskMode", "default": true, "core": false},
    "membersDirectory": {"parent": null, "default": true, "core": true},
    "whatsappIntegration": {"parent": "membersDirectory", "default": true, "core": false},
    "spaceQrCodes": {"parent": null, "default": true, "core": true},
    "coOwner": {"parent": null, "default": true, "core": false},
    "autoCheckInOut": {"parent": null, "default": false, "core": false},
    "dataExport": {"parent": null, "default": true, "core": true},
    "workingHours": {"parent": null, "default": true, "core": true},
    "invoicePdfTemplate": {"parent": "invoicing", "default": true, "core": false},
    "invoiceAddressWindow": {"parent": "invoicing", "default": true, "core": false},
    "memberNotifications": {"parent": null, "default": true, "core": true},
    "documents": {"parent": null, "default": true, "core": true},
    "dunning": {"parent": "invoicing", "default": true, "core": false},
    "memberReports": {"parent": "moneyTab", "default": true, "core": false},
    "deletionRequests": {"parent": null, "default": true, "core": true},
    "roleManagement": {"parent": null, "default": true, "core": true},
    "vatManagement": {"parent": "invoicing", "default": true, "core": false},
    "vatDeclarations": {"parent": "vatManagement", "default": true, "core": false},
    "einvoiceCustomerDelivery": {"parent": "invoicing", "default": true, "core": false},
    "planObjectDelete": {"parent": null, "default": true, "core": true},
    "notificationGrouping": {"parent": "eventsTab", "default": true, "core": true},
    "bookingPolicies": {"parent": null, "default": true, "core": true},
    "bookingGate": {"parent": "bookingPolicies", "default": true, "core": true},
    "nfcSeatTags": {"parent": null, "default": true, "core": false},
    "qrBadges": {"parent": "kioskMode", "default": true, "core": false},
    "kioskMemberPhotos": {"parent": "kioskMode", "default": true, "core": false},
    "subscriptionInvoices": {"parent": "invoicing", "default": true, "core": false},
    "usageInvoices": {"parent": "invoicing", "default": true, "core": false},
    "invoiceSettlement": {"parent": "invoicing", "default": true, "core": false},
    "invoiceJourney": {"parent": "invoicing", "default": true, "core": false},
    "messageGestures": {"parent": null, "default": true, "core": true},
    "uniqueMonograms": {"parent": null, "default": true, "core": true},
    "planMemberPhotos": {"parent": null, "default": true, "core": false},
    "regionalFormats": {"parent": null, "default": true, "core": true},
    "calendarHub": {"parent": null, "default": true, "core": true},
    "calendarViews": {"parent": "calendarHub", "default": true, "core": true},
    "messagesHub": {"parent": null, "default": true, "core": true},
    "reportDesigner": {"parent": "invoicePdfTemplate", "default": true, "core": false},
    "memberPage": {"parent": "membersDirectory", "default": true, "core": true},
    "invoicingWizard": {"parent": "invoicing", "default": true, "core": false},
    "expenseRepartition": {"parent": "invoicing", "default": true, "core": false},
    "settlementFold": {"parent": "invoiceSettlement", "default": true, "core": false},
    "configurationTransfer": {"parent": "dataExport", "default": true, "core": false},
    "navigationStyle": {"parent": null, "default": true, "core": true},
    "demoMode": {"parent": null, "default": true, "core": false},
    "instanceWizard": {"parent": null, "default": true, "core": false},
    "dataAccessLog": {"parent": "moneyTab", "default": true, "core": false},
    "memberDataExport": {"parent": null, "default": true, "core": true},
    "financeFaces": {"parent": "moneyTab", "default": true, "core": true},
    "paymentReminders": {"parent": "dunning", "default": true, "core": false},
    "supplyExpenses": {"parent": "services", "default": true, "core": false},
    "validationScopes": {"parent": null, "default": true, "core": false},
    "validationChain": {"parent": null, "default": true, "core": false},
    "richMessageRefs": {"parent": "memberNotifications", "default": true, "core": true},
    "calendarValidations": {"parent": "calendarHub", "default": true, "core": false},
    "usageRecords": {"parent": "invoicing", "default": true, "core": false},
    "reportDesignExchange": {"parent": "reportDesigner", "default": true, "core": false},
    "reportLayouts": {"parent": "reportDesigner", "default": true, "core": false},
    "personalInfo": {"parent": null, "default": true, "core": true},
    "managedProfiles": {"parent": "membersDirectory", "default": true, "core": false},
    "numberSequences": {"parent": "invoicing", "default": false, "core": false},
    "workspaceStatus": {"parent": "invoicing", "default": false, "core": false},
    "expenseRepartitionWizard": {"parent": "expenseRepartition", "default": false, "core": false},
    "multiSite": {"parent": null, "default": false, "core": false},
    "siteDocuments": {"parent": "multiSite", "default": false, "core": false},
    "vatGroups": {"parent": "vatManagement", "default": false, "core": false},
    "vatRateHistory": {"parent": "vatManagement", "default": false, "core": false},
    "vatCounterparty": {"parent": "vatManagement", "default": false, "core": false},
    "environmentPairs": {"parent": null, "default": true, "core": false},
    "deployments": {"parent": "environmentPairs", "default": true, "core": false},
    "managedProfileAccess": {"parent": "managedProfiles", "default": false, "core": false},
    "seatDayTimeline": {"parent": null, "default": true, "core": true},
    "memberPaymentTerms": {"parent": "invoicing", "default": true, "core": false},
    "usageReport": {"parent": "usageRecords", "default": true, "core": false},
    "reportTexts": {"parent": "reportDesigner", "default": true, "core": false},
    "letterStandard": {"parent": "reportLayouts", "default": true, "core": false},
    "vatReport": {"parent": "vatDeclarations", "default": true, "core": false},
    "priceNegotiations": {"parent": "moneyTab", "default": true, "core": false},
    "scheduledExpenses": {"parent": "moneyTab", "default": true, "core": false},
    "badgeSignIn": {"parent": "nfcBadges", "default": false, "core": false},
    "formHelpHints": {"parent": null, "default": true, "core": true},
    "uiAnimations": {"parent": null, "default": true, "core": true},
    "memberOrigin": {"parent": "membersDirectory", "default": false, "core": false},
    "memberEnvironments": {"parent": "environmentPairs", "default": false, "core": false},
    "workspaceLibrary": {"parent": null, "default": false, "core": false},
    "singleRoomLevelNames": {"parent": null, "default": true, "core": true},
    "publicHolidays": {"parent": null, "default": false, "core": false},
    "workspaceVocabulary": {"parent": null, "default": false, "core": false},
    "carnets": {"parent": "invoicing", "default": false, "core": false},
    "publicListings": {"parent": null, "default": false, "core": true},
    "workspaceBranding": {"parent": null, "default": false, "core": false},
    "customRoles": {"parent": null, "default": false, "core": false},
    "customFields": {"parent": null, "default": false, "core": false},
    "decisionSurface": {"parent": null, "default": false, "core": false},
    "recordingPrivacy": {"parent": null, "default": false, "core": false},
    "memberAccountMenu": {"parent": null, "default": false, "core": false},
    "mcpAccess": {"parent": null, "default": false, "core": false},
    "calendarFileExport": {"parent": null, "default": true, "core": true},
    "memberGettingStarted": {"parent": null, "default": true, "core": true}
  }'::jsonb
$registry$;

revoke execute on function public.feature_registry() from public,anon;
grant execute on function public.feature_registry() to authenticated;


notify pgrst,'reload schema';
select public.set_deskilo_schema_version(305);
