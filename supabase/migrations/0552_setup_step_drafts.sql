-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #2869 — a setup step's unfinished answers, kept on the server so that
-- leaving mid-step, a failed save or another device loses nothing.
--
-- A draft is never configuration: nothing reads it but the step page that
-- wrote it, the step's own command still applies what the owner confirms,
-- and workspace_setup_status never looks at this table. One draft per step
-- and per workspace, shared by everyone who configures the space, so a
-- second administrator sees the first one's answers instead of a blank form.
--
--   * get_setup_step_draft(workspace, step) -> null, or
--     {payload, version, updated_at, updated_by_name}.
--   * save_setup_step_draft(workspace, step, payload, expected_version,
--     request_id) -> {version, updated_at}. The write is made against the
--     version the caller read (null: "there was no draft"); under the row
--     lock a different stored version raises
--         SQLSTATE 40001, message 'setup draft changed: …'
--     and writes nothing, so a concurrent change is reported, never
--     overwritten. The same request_id as the stored draft's last write
--     answers that write again without a second bump: a retry after a lost
--     answer is not a conflict with oneself.
--   * discard_setup_step_draft(workspace, step, expected_version) -> whether
--     a draft was discarded; the same 40001 when it moved since it was read.
--
-- A discarded draft stays as a row without a payload whose version keeps
-- counting: a version number is never handed out twice for a step, so a
-- caller holding version 1 of a draft that was discarded and started again
-- cannot overwrite the new one by matching its number.
--
-- Every function needs manageConfiguration (42501 otherwise) and is native
-- only: an assistant's delegated token never reads or writes a draft.

create table if not exists public.setup_step_drafts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  step text not null,
  -- null: discarded (the row keeps the version counting).
  payload jsonb,
  version int not null default 1 check (version > 0),
  last_request_id uuid,
  updated_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint setup_step_drafts_key unique (workspace_id, step),
  constraint setup_step_drafts_payload_object
    check (payload is null or jsonb_typeof(payload) = 'object')
);
select public.ensure_system_columns('setup_step_drafts');
alter table public.setup_step_drafts enable row level security;
revoke all on table public.setup_step_drafts from anon, authenticated;
drop policy if exists mcp_delegated_deny on public.setup_step_drafts;
create policy mcp_delegated_deny on public.setup_step_drafts
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- The step is one the guide's catalogue names. A trigger rather than a
-- check constraint: a check is re-evaluated when a backup is restored, and
-- a step a later catalogue retires would then refuse its own old rows.
create or replace function public.setup_step_drafts_step_known()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if not public.setup_step_catalogue() @> jsonb_build_array(jsonb_build_object('id', new.step)) then
    raise exception 'the setup guide has no step %', coalesce(new.step, '(none)')
      using errcode = '22023';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.setup_step_drafts_step_known() from public, anon, authenticated;
drop trigger if exists setup_step_drafts_step_known on public.setup_step_drafts;
create trigger setup_step_drafts_step_known
  before insert or update of step on public.setup_step_drafts
  for each row execute function public.setup_step_drafts_step_known();

create or replace function public.get_setup_step_draft(p_workspace_id uuid, p_step text)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v public.setup_step_drafts;
begin
  perform public.mcp_require_native();
  if not public.has_permission(p_workspace_id, 'manageConfiguration') then
    raise exception 'only someone who configures this workspace reads its setup drafts'
      using errcode = '42501';
  end if;
  select * into v from public.setup_step_drafts
   where workspace_id = p_workspace_id and step = p_step and payload is not null;
  if not found then
    return null;
  end if;
  return jsonb_build_object(
    'payload', v.payload,
    'version', v.version,
    'updated_at', v.updated_at,
    'updated_by_name', (select public.profile_full_name(p) from public.profiles p where p.id = v.updated_by));
end;
$fn$;
revoke execute on function public.get_setup_step_draft(uuid, text) from public, anon;
grant execute on function public.get_setup_step_draft(uuid, text) to authenticated;

create or replace function public.save_setup_step_draft(
  p_workspace_id uuid,
  p_step text,
  p_payload jsonb,
  p_expected_version int,
  p_request_id uuid
) returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v public.setup_step_drafts;
begin
  perform public.mcp_require_native();
  if not public.has_permission(p_workspace_id, 'manageConfiguration') then
    raise exception 'only someone who configures this workspace saves a setup draft'
      using errcode = '42501';
  end if;
  if not public.setup_step_catalogue() @> jsonb_build_array(jsonb_build_object('id', p_step)) then
    raise exception 'the setup guide has no step %', coalesce(p_step, '(none)')
      using errcode = '22023';
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'a setup draft is an object of answers' using errcode = '22023';
  end if;
  if p_request_id is null then
    raise exception 'a setup draft save needs a request id' using errcode = '22023';
  end if;

  -- The lock is the atomicity: the comparison and the write happen on the
  -- same row version, and a concurrent writer waits here.
  select * into v from public.setup_step_drafts
   where workspace_id = p_workspace_id and step = p_step for update;

  if found and v.last_request_id = p_request_id then
    return jsonb_build_object('version', v.version, 'updated_at', v.updated_at);
  end if;
  if (case when found and v.payload is not null then v.version end)
     is distinct from p_expected_version then
    raise exception using
      errcode = '40001',
      message = format('setup draft changed: %s is at version %s, the save expected %s',
                       p_step,
                       coalesce(case when v.payload is not null then v.version::text end, 'none'),
                       coalesce(p_expected_version::text, 'none'));
  end if;

  if v.id is null then
    insert into public.setup_step_drafts
      (workspace_id, step, payload, version, last_request_id, updated_by, updated_at)
    values (p_workspace_id, p_step, p_payload, 1, p_request_id, auth.uid(), now())
    on conflict on constraint setup_step_drafts_key do nothing
    returning * into v;
    if v.id is null then
      -- Another configurer created it between the read and the insert.
      raise exception using
        errcode = '40001',
        message = format('setup draft changed: %s was started by someone else', p_step);
    end if;
  else
    update public.setup_step_drafts
       set payload = p_payload, version = v.version + 1, last_request_id = p_request_id,
           updated_by = auth.uid(), updated_at = now()
     where id = v.id
    returning * into v;
  end if;
  return jsonb_build_object('version', v.version, 'updated_at', v.updated_at);
end;
$fn$;
revoke execute on function public.save_setup_step_draft(uuid, text, jsonb, int, uuid) from public, anon;
grant execute on function public.save_setup_step_draft(uuid, text, jsonb, int, uuid) to authenticated;

create or replace function public.discard_setup_step_draft(
  p_workspace_id uuid,
  p_step text,
  p_expected_version int
) returns boolean language plpgsql volatile security definer set search_path = public as $fn$
declare
  v public.setup_step_drafts;
begin
  perform public.mcp_require_native();
  if not public.has_permission(p_workspace_id, 'manageConfiguration') then
    raise exception 'only someone who configures this workspace discards a setup draft'
      using errcode = '42501';
  end if;
  select * into v from public.setup_step_drafts
   where workspace_id = p_workspace_id and step = p_step for update;
  if not found or v.payload is null then
    return false;
  end if;
  if v.version is distinct from p_expected_version then
    raise exception using
      errcode = '40001',
      message = format('setup draft changed: %s is at version %s, the discard expected %s',
                       p_step, v.version, coalesce(p_expected_version::text, 'none'));
  end if;
  update public.setup_step_drafts
     set payload = null, version = v.version + 1, last_request_id = null,
         updated_by = auth.uid(), updated_at = now()
   where id = v.id;
  return true;
end;
$fn$;
revoke execute on function public.discard_setup_step_draft(uuid, text, int) from public, anon;
grant execute on function public.discard_setup_step_draft(uuid, text, int) to authenticated;

select public.set_deskilo_schema_version(552);
