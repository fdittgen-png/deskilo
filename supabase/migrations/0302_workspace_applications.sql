-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- #1791: an admission outcome and its discussion survive refused membership.
-- Existing member_join events remain the authoritative application/history.
create table public.workspace_applications (
  event_id uuid primary key references public.events(id) on delete cascade,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  applicant_user_id uuid references auth.users(id) on delete set null
);
select public.ensure_system_columns('workspace_applications');
create index workspace_applications_account_idx on public.workspace_applications(applicant_user_id,event_id);
alter table public.workspace_applications enable row level security;
revoke all on public.workspace_applications from public,anon,authenticated;
create policy mcp_delegated_deny on public.workspace_applications
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
insert into public.workspace_applications(event_id,workspace_id,applicant_user_id)
  select e.id,e.workspace_id,m.user_id from public.events e
    join public.members m on m.id=e.subject_member_id where e.type='member_join';
create function public.capture_workspace_application() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  if new.type='member_join' then
    insert into public.workspace_applications(event_id,workspace_id,applicant_user_id)
      select new.id,new.workspace_id,user_id from public.members where id=new.subject_member_id;
  end if;
  return new;
end;
$$;
revoke execute on function public.capture_workspace_application() from public,anon,authenticated;
create trigger capture_workspace_application after insert on public.events
  for each row execute function public.capture_workspace_application();

create table public.workspace_application_messages (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  event_id uuid not null references public.events(id) on delete cascade,
  author_user_id uuid references auth.users(id) on delete set null,
  kind text not null default 'discussion' check (kind in ('discussion','accepted','refused')),
  body text not null default '' check (char_length(body)<=4000),
  created_at timestamptz not null default now()
);
select public.ensure_system_columns('workspace_application_messages');
create index workspace_application_messages_thread_idx
  on public.workspace_application_messages(event_id,created_at,id);
alter table public.workspace_application_messages enable row level security;
revoke all on public.workspace_application_messages from public,anon,authenticated;
create policy mcp_delegated_deny on public.workspace_application_messages
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
insert into public.workspace_application_messages(workspace_id,event_id,author_user_id,kind,created_at)
  select e.workspace_id,e.id,m.user_id,case when d.decision='accept' then 'accepted' else 'refused' end,d.decided_at
  from public.event_decisions d join public.events e on e.id=d.event_id
    join public.members m on m.id=d.member_id where e.type='member_join';

-- No workspace-data grant: eligibility covers only this application thread.
-- A reviewer may continue their own discussion after leaving the workspace;
-- they gain no access to any other applicant or workspace data by doing so.
create function public.can_discuss_workspace_application(p_event_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select auth.uid() is not null and not public.mcp_is_delegated() and exists (
    select 1 from public.events e join public.workspace_applications applicant on applicant.event_id=e.id
    where e.id=p_event_id and e.type='member_join' and (
      applicant.applicant_user_id=auth.uid()
      or exists (select 1 from public.members reviewer where reviewer.workspace_id=e.workspace_id
        and reviewer.user_id=auth.uid() and reviewer.status='active'
        and (reviewer.is_owner or reviewer.is_admin))
      or exists (select 1 from public.workspace_application_messages message
        where message.event_id=e.id and message.author_user_id=auth.uid()
          and message.kind in ('accepted','refused'))
    ));
$$;
revoke execute on function public.can_discuss_workspace_application(uuid) from public,anon;
grant execute on function public.can_discuss_workspace_application(uuid) to authenticated;

-- Capture actual decisions from BOTH the quick action and validation centre.
-- Discussion rows never determine access, and cannot manufacture a reviewer.
create function public.record_workspace_application_decision() returns trigger
language plpgsql security definer set search_path=public as $$
declare v_event public.events;
begin
  select * into v_event from public.events where id=new.event_id and type='member_join';
  if v_event.id is not null then
    insert into public.workspace_application_messages(workspace_id,event_id,author_user_id,kind)
      select v_event.workspace_id,v_event.id,user_id,
        case when new.decision='accept' then 'accepted' else 'refused' end
      from public.members where id=new.member_id;
  end if;
  return new;
end;
$$;
revoke execute on function public.record_workspace_application_decision() from public,anon,authenticated;
create trigger record_workspace_application_decision after insert on public.event_decisions
  for each row execute function public.record_workspace_application_decision();

create function public.decide_workspace_application(p_member_id uuid,p_approve boolean,p_comment text default '',p_expected_account uuid default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_event uuid; v_workspace uuid;
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_expected_account is not null and p_expected_account<>auth.uid() then raise exception 'account changed'; end if;
  if p_approve is null or p_comment is null or char_length(p_comment)>4000 then
    raise exception 'invalid admission decision';
  end if;
  select e.id,e.workspace_id into v_event,v_workspace from public.events e
    join public.members m on m.id=e.subject_member_id
    where m.id=p_member_id and m.status='pending' and e.type='member_join' and e.status='pending'
    order by e.created_at desc,e.id desc limit 1 for update of e,m;
  if v_event is null then raise exception 'application is not pending'; end if;
  -- The same quorum and eligibility as the validation centre, also for old clients.
  perform public.respond_to_event(v_event,p_approve);
  if btrim(p_comment)<>'' then
    insert into public.workspace_application_messages(workspace_id,event_id,author_user_id,body)
      values(v_workspace,v_event,auth.uid(),btrim(p_comment));
  end if;
end;
$$;
revoke execute on function public.decide_workspace_application(uuid,boolean,text,uuid) from public,anon;
grant execute on function public.decide_workspace_application(uuid,boolean,text,uuid) to authenticated;

create or replace function public.decide_member_join(p_member_id uuid,p_approve boolean)
returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  perform public.decide_workspace_application(p_member_id,p_approve,'');
end;
$$;
revoke execute on function public.decide_member_join(uuid,boolean) from public,anon;
grant execute on function public.decide_member_join(uuid,boolean) to authenticated;

create function public.my_workspace_applications(p_before_at timestamptz default null,p_before_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public as $$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if (p_before_at is null)<>(p_before_id is null) then raise exception 'invalid cursor'; end if;
  return coalesce((select jsonb_agg(entry order by entry.created_at desc,entry.id desc) from (
    select e.id,e.workspace_id,w.name as workspace_name,e.subject_member_id as member_id,
      coalesce(p.display_name,'') as applicant_name,application.applicant_user_id=auth.uid() as is_applicant,
      e.status,e.created_at,e.decided_at
    from public.events e join public.workspaces w on w.id=e.workspace_id
      join public.workspace_applications application on application.event_id=e.id
      left join public.profiles p on p.id=application.applicant_user_id
    where e.type='member_join' and public.can_discuss_workspace_application(e.id)
      and (p_before_at is null or (e.created_at,e.id)<(p_before_at,p_before_id))
    order by e.created_at desc,e.id desc limit 50
  ) entry),'[]'::jsonb);
end;
$$;
revoke execute on function public.my_workspace_applications(timestamptz,uuid) from public,anon;
grant execute on function public.my_workspace_applications(timestamptz,uuid) to authenticated;

create function public.workspace_application_thread(p_event_id uuid,p_before_at timestamptz default null,p_before_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public as $$
begin
  perform public.mcp_require_native();
  if not public.can_discuss_workspace_application(p_event_id) then raise exception 'application unavailable'; end if;
  if (p_before_at is null)<>(p_before_id is null) then raise exception 'invalid cursor'; end if;
  return coalesce((select jsonb_agg(entry order by entry.created_at desc,entry.id desc) from (
    select message.id,message.kind,message.body,message.created_at,
      coalesce(p.display_name,'') as author_name,message.author_user_id=auth.uid() as is_mine
    from public.workspace_application_messages message
      left join public.profiles p on p.id=message.author_user_id
    where message.event_id=p_event_id
      and (p_before_at is null or (message.created_at,message.id)<(p_before_at,p_before_id))
    order by message.created_at desc,message.id desc limit 50
  ) entry),'[]'::jsonb);
end;
$$;
revoke execute on function public.workspace_application_thread(uuid,timestamptz,uuid) from public,anon;
grant execute on function public.workspace_application_thread(uuid,timestamptz,uuid) to authenticated;

create function public.send_workspace_application_message(p_event_id uuid,p_body text,p_expected_account uuid default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_workspace uuid;
begin
  perform public.mcp_require_native();
  if p_expected_account is not null and p_expected_account is distinct from auth.uid() then raise exception 'account changed'; end if;
  if not public.can_discuss_workspace_application(p_event_id) then raise exception 'application unavailable'; end if;
  if p_body is null or char_length(btrim(p_body)) not between 1 and 4000 then raise exception 'invalid message'; end if;
  select workspace_id into strict v_workspace from public.events where id=p_event_id;
  insert into public.workspace_application_messages(workspace_id,event_id,author_user_id,body)
    values(v_workspace,p_event_id,auth.uid(),btrim(p_body));
end;
$$;
revoke execute on function public.send_workspace_application_message(uuid,text,uuid) from public,anon;
grant execute on function public.send_workspace_application_message(uuid,text,uuid) to authenticated;

do $export$
declare v_def text; v_anchor text := $a$    'exported_at', now(),$a$;
begin
  v_def := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  if position(v_anchor in v_def)=0 then raise exception '0302: export anchor missing'; end if;
  execute replace(v_def,v_anchor,$a$    'exported_at', now(),
    'application_messages', (select coalesce(jsonb_agg(to_jsonb(message)),'[]'::jsonb)
      from public.workspace_application_messages message where message.workspace_id=p_workspace_id
        and (message.author_user_id=auth.uid() or exists (select 1 from public.workspace_applications application
          where application.event_id=message.event_id and application.applicant_user_id=auth.uid()))),
    'workspace_applications', (select coalesce(jsonb_agg(to_jsonb(application)),'[]'::jsonb)
      from public.workspace_applications application where application.workspace_id=p_workspace_id
        and application.applicant_user_id=auth.uid()),$a$);
end;
$export$;

notify pgrst,'reload schema';
select public.set_deskilo_schema_version(302);
