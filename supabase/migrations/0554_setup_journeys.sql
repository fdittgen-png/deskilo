-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #2868 — the owner's answers to the setup questions and the level of each
-- process they applied, kept on the server so the levels screen reopens
-- with them on any device and a second configurer sees the first one's.
--
-- A journey is never configuration: the features are what applying the
-- levels wrote (set_feature_flags, against its read-set), and nothing reads
-- this table to decide what a space does — not the feature gates, not
-- workspace_setup_status. It remembers why. One journey per workspace,
-- shared by everyone who configures it.
--
--   * get_setup_journey(workspace) -> null, or
--     {answers, levels, version, updated_at, updated_by_name}.
--   * save_setup_journey(workspace, answers, levels, expected_version,
--     request_id) -> {version, updated_at}. answers is an object of
--     question -> boolean, levels an object of process -> level id (the
--     app's own table names them; the server keeps what it was given). The
--     write is made against the version the caller read (null: "nothing
--     was saved yet"); under the row lock a different stored version raises
--         SQLSTATE 40001, message 'setup journey changed: …'
--     and writes nothing, so a concurrent change is reported, never
--     overwritten. The same request_id as the stored journey's last write
--     answers that write again without a second bump: a retry after a lost
--     answer is not a conflict with oneself.
--
-- Both functions need manageConfiguration (42501 otherwise) and are native
-- only: an assistant's delegated token never reads or writes a journey.

create table if not exists public.workspace_setup_journeys (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  answers jsonb not null default '{}'::jsonb,
  levels jsonb not null default '{}'::jsonb,
  version int not null default 1 check (version > 0),
  last_request_id uuid,
  updated_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint workspace_setup_journeys_key unique (workspace_id),
  constraint workspace_setup_journeys_answers_object check (jsonb_typeof(answers) = 'object'),
  constraint workspace_setup_journeys_levels_object check (jsonb_typeof(levels) = 'object')
);
select public.ensure_system_columns('workspace_setup_journeys');
alter table public.workspace_setup_journeys enable row level security;
revoke all on table public.workspace_setup_journeys from anon, authenticated;
drop policy if exists mcp_delegated_deny on public.workspace_setup_journeys;
create policy mcp_delegated_deny on public.workspace_setup_journeys
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create or replace function public.get_setup_journey(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v public.workspace_setup_journeys;
begin
  perform public.mcp_require_native();
  if not public.has_permission(p_workspace_id, 'manageConfiguration') then
    raise exception 'only someone who configures this workspace reads its setup answers'
      using errcode = '42501';
  end if;
  select * into v from public.workspace_setup_journeys where workspace_id = p_workspace_id;
  if not found then
    return null;
  end if;
  return jsonb_build_object(
    'answers', v.answers,
    'levels', v.levels,
    'version', v.version,
    'updated_at', v.updated_at,
    'updated_by_name', (select public.profile_full_name(p) from public.profiles p where p.id = v.updated_by));
end;
$fn$;
revoke execute on function public.get_setup_journey(uuid) from public, anon;
grant execute on function public.get_setup_journey(uuid) to authenticated;

create or replace function public.save_setup_journey(
  p_workspace_id uuid,
  p_answers jsonb,
  p_levels jsonb,
  p_expected_version int,
  p_request_id uuid
) returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v public.workspace_setup_journeys;
begin
  perform public.mcp_require_native();
  if not public.has_permission(p_workspace_id, 'manageConfiguration') then
    raise exception 'only someone who configures this workspace saves its setup answers'
      using errcode = '42501';
  end if;
  if p_answers is null or jsonb_typeof(p_answers) <> 'object'
     or exists (select 1 from jsonb_each(p_answers) a
                 where jsonb_typeof(a.value) <> 'boolean' or a.key !~ '^[a-z][a-z_]*$') then
    raise exception 'setup answers are an object of question -> true or false'
      using errcode = '22023';
  end if;
  if p_levels is null or jsonb_typeof(p_levels) <> 'object'
     or exists (select 1 from jsonb_each(p_levels) l
                 where jsonb_typeof(l.value) <> 'string' or l.key !~ '^[a-z][a-z_]*$'
                    or (l.value #>> '{}') !~ '^[a-z][a-z_]*$') then
    raise exception 'setup levels are an object of process -> level'
      using errcode = '22023';
  end if;
  if p_request_id is null then
    raise exception 'saving setup answers needs a request id' using errcode = '22023';
  end if;

  -- The lock is the atomicity: the comparison and the write happen on the
  -- same row version, and a concurrent writer waits here.
  select * into v from public.workspace_setup_journeys
   where workspace_id = p_workspace_id for update;

  if found and v.last_request_id = p_request_id then
    return jsonb_build_object('version', v.version, 'updated_at', v.updated_at);
  end if;
  if (case when found then v.version end) is distinct from p_expected_version then
    raise exception using
      errcode = '40001',
      message = format('setup journey changed: the answers are at version %s, the save expected %s',
                       coalesce(case when found then v.version::text end, 'none'),
                       coalesce(p_expected_version::text, 'none'));
  end if;

  if v.id is null then
    insert into public.workspace_setup_journeys
      (workspace_id, answers, levels, version, last_request_id, updated_by, updated_at)
    values (p_workspace_id, p_answers, p_levels, 1, p_request_id, auth.uid(), now())
    on conflict on constraint workspace_setup_journeys_key do nothing
    returning * into v;
    if v.id is null then
      -- Another configurer saved between the read and the insert.
      raise exception using
        errcode = '40001',
        message = 'setup journey changed: someone else saved the answers first';
    end if;
  else
    update public.workspace_setup_journeys
       set answers = p_answers, levels = p_levels, version = v.version + 1,
           last_request_id = p_request_id, updated_by = auth.uid(), updated_at = now()
     where id = v.id
    returning * into v;
  end if;
  return jsonb_build_object('version', v.version, 'updated_at', v.updated_at);
end;
$fn$;
revoke execute on function public.save_setup_journey(uuid, jsonb, jsonb, int, uuid) from public, anon;
grant execute on function public.save_setup_journey(uuid, jsonb, jsonb, int, uuid) to authenticated;

select public.set_deskilo_schema_version(554);
