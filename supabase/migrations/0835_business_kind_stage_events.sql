-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one append-only table and one function; the guarded writers it calls,
-- set_business_kind (0710) and set_feature_flags (0765), are not changed)
--
-- #4168 (A1) -- what a kind's confirmation actually did, observed on the server.
--
--  * configuration_choice_events: one row per stage of a confirmation (`kind`,
--    `flags`) and request, append-only. It records the OUTCOME the server saw
--    (applied, no_change, refused), who confirmed, which reviewed source it was
--    (kind, profile version, profile digest), the fields that changed with their
--    raw before and after (absent, true or false are distinct), a fingerprint of
--    the target after the stage and the typed refusal. It is never a client's
--    claim, and never written by a client.
--  * apply_business_kind_v1: the narrowly versioned stage adapter around the two
--    existing guarded writers. Under manageConfiguration, for one request id it
--    (1) refuses, writing nothing, a profile that is no longer the one reviewed
--    (version and digest), (2) saves the kind and records that stage, (3) writes
--    the confirmed features against the read-set and records that stage, a
--    refused write recorded as refused while the kind stays saved. The same
--    request answers the same recorded outcome and writes nothing again.
--    The existing RPC signatures are untouched: an older app keeps using them and
--    its writes simply have no recorded provenance (unknown, never invented).

create table public.configuration_choice_events (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  request_id uuid not null,
  stage text not null check (stage in ('kind', 'flags')),
  outcome text not null check (outcome in ('applied', 'no_change', 'refused')),
  actor_user_id uuid not null,
  source jsonb not null check (jsonb_typeof(source) = 'object'),
  changed jsonb not null default '{}'::jsonb check (jsonb_typeof(changed) = 'object'),
  target_fingerprint text not null default '',
  refusal text not null default '' check (char_length(refusal) <= 120),
  unique (workspace_id, request_id, stage)
);
select public.ensure_system_columns('configuration_choice_events');

-- A stage is never changed, and never deleted while its business exists; it
-- goes with the business (`workspace_id` cascades): the pattern of
-- `stock_movements_append_only` (0747). Without it a business that confirmed a
-- kind could never be deleted, nor its data erased.
create or replace function public.configuration_choice_events_append_only() returns trigger
language plpgsql set search_path = public as $fn$
begin
  if tg_op = 'DELETE' and not exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
    return old;
  end if;
  raise exception 'a recorded configuration stage is never changed or deleted' using errcode = 'DKK02';
end
$fn$;
revoke execute on function public.configuration_choice_events_append_only() from public, anon, authenticated;
create trigger configuration_choice_events_append_only
  before update or delete on public.configuration_choice_events
  for each row execute function public.configuration_choice_events_append_only();

alter table public.configuration_choice_events enable row level security;
revoke all on public.configuration_choice_events from public, anon, authenticated;
grant select on public.configuration_choice_events to authenticated;
create policy configuration_choice_events_read on public.configuration_choice_events
  for select to authenticated
  using (public.has_permission(workspace_id, 'manageConfiguration'));
create policy mcp_delegated_deny on public.configuration_choice_events as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create or replace function public.apply_business_kind_v1(
  p_workspace uuid, p_request_id uuid, p_kind text, p_more_kinds text,
  p_reviewed_version integer, p_reviewed_digest text,
  p_flags jsonb default '{}'::jsonb, p_expected jsonb default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_row public.business_kinds;
  v_source jsonb;
  v_kind jsonb;
  v_flags_before jsonb;
  v_flags_after jsonb;
  v_kind_outcome text;
  v_flags_outcome text := 'none';
  v_refusal text := '';
  v_changed jsonb := '{}'::jsonb;
  v_key text;
  v_before text;
  v_after text;
  v_prior jsonb;
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not coalesce(public.has_permission(p_workspace, 'manageConfiguration'), false) then
    raise exception 'not allowed to change this setting' using errcode = '42501';
  end if;
  if p_request_id is null or p_kind is null then
    raise exception 'a kind confirmation names its request and its kind' using errcode = '22023';
  end if;
  -- the same request answers what it recorded and writes nothing again
  select jsonb_object_agg(e.stage, e.outcome) into v_prior
    from public.configuration_choice_events e
   where e.workspace_id = p_workspace and e.request_id = p_request_id;
  if v_prior is not null then
    return jsonb_build_object('request_id', p_request_id, 'replayed', true,
      'kind_stage', v_prior ->> 'kind', 'flags_stage', coalesce(v_prior ->> 'flags', 'none'));
  end if;
  select * into v_row from public.business_kinds k where k.code = p_kind and k.active;
  if v_row.code is null then
    raise exception 'unknown business kind: %', p_kind using errcode = '22023';
  end if;
  v_source := jsonb_build_object('source', 'business_kind', 'kind', v_row.code,
    'profile_version', v_row.profile_version, 'profile_digest', v_row.profile_digest);
  -- a profile that is no longer the one the owner reviewed: nothing is written
  if v_row.profile_version is distinct from p_reviewed_version
     or v_row.profile_digest is distinct from p_reviewed_digest then
    insert into public.configuration_choice_events
      (workspace_id, request_id, stage, outcome, actor_user_id, source, refusal)
    values (p_workspace, p_request_id, 'kind', 'refused', auth.uid(), v_source, 'profile_changed');
    return jsonb_build_object('request_id', p_request_id, 'replayed', false,
      'kind_stage', 'refused', 'flags_stage', 'none', 'refusal', 'profile_changed');
  end if;
  -- the kind stage
  v_before := public.setting_value(p_workspace, 'business.kind') #>> '{}';
  v_kind := public.set_business_kind(p_workspace, p_kind, p_more_kinds);
  v_kind_outcome := case when v_kind ->> 'status' = 'saved' then 'applied' else 'no_change' end;
  v_after := p_kind;
  insert into public.configuration_choice_events
    (workspace_id, request_id, stage, outcome, actor_user_id, source, changed, target_fingerprint)
  values (p_workspace, p_request_id, 'kind', v_kind_outcome, auth.uid(), v_source,
    case when v_kind_outcome = 'applied'
         then jsonb_build_object('business.kind', jsonb_build_object('before', to_jsonb(v_before), 'after', to_jsonb(v_after)),
                                 'business.more_kinds', jsonb_build_object('after', to_jsonb(v_kind ->> 'more_kinds')))
         else '{}'::jsonb end,
    md5(v_kind::text));
  -- the flags stage
  if p_flags is not null and p_flags <> '{}'::jsonb then
    select coalesce(feature_flags, '{}'::jsonb) into v_flags_before from public.workspaces where id = p_workspace;
    begin
      perform public.set_feature_flags(p_workspace, p_flags, p_expected);
      select coalesce(feature_flags, '{}'::jsonb) into v_flags_after from public.workspaces where id = p_workspace;
      for v_key in select jsonb_object_keys(p_flags) loop
        if public.feature_raw(v_flags_before, v_key) is distinct from public.feature_raw(v_flags_after, v_key)
           or (v_flags_before -> v_key) is distinct from (v_flags_after -> v_key) then
          v_changed := v_changed || jsonb_build_object(v_key, jsonb_build_object(
            'before', v_flags_before -> v_key, 'before_present', v_flags_before ? v_key,
            'after', v_flags_after -> v_key, 'after_present', v_flags_after ? v_key));
        end if;
      end loop;
      v_flags_outcome := case when v_changed = '{}'::jsonb then 'no_change' else 'applied' end;
    exception when sqlstate 'DK409' then
      v_flags_outcome := 'refused';
      v_refusal := 'DK409';
      v_flags_after := v_flags_before;
    end;
    insert into public.configuration_choice_events
      (workspace_id, request_id, stage, outcome, actor_user_id, source, changed, target_fingerprint, refusal)
    values (p_workspace, p_request_id, 'flags', v_flags_outcome, auth.uid(), v_source, v_changed,
            md5(v_flags_after::text), v_refusal);
  end if;
  return jsonb_build_object('request_id', p_request_id, 'replayed', false,
    'kind_stage', v_kind_outcome, 'flags_stage', v_flags_outcome);
end;
$fn$;
revoke execute on function public.apply_business_kind_v1(uuid, uuid, text, text, integer, text, jsonb, jsonb) from public, anon;
grant execute on function public.apply_business_kind_v1(uuid, uuid, text, text, integer, text, jsonb, jsonb) to authenticated;

select public.set_deskilo_schema_version(835);
