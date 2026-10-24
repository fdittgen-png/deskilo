-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- Additive: one client RPC and four internal helpers; the common audience
-- writer (0392's write_account_audience) is restated whole so that it
-- takes the per-account lock and writes through the reference writer. No
-- table, column, policy or row changes.
--
-- #2558 C2 -- the personal home's checked privacy writer.
--
-- `set_visibility_if_unchanged_network_v1(field, audience, workspace_refs,
-- expected)` changes one field of MY saved policy only if that field is
-- still what I last read (`expected` = {audience, workspace_refs}):
--
--   verify the native first-party caller (mcp_require_native)
--   -> lock my account (one transaction advisory lock)
--   -> canonicalize the expected field and the intended chosen spaces
--      (network references, deduplicated and sorted)
--   -> read the current field through the shared policy (account_audience_of
--      and the saved references)
--   -> current <> expected: `visibility_conflict` (SQLSTATE PT409, the
--      current field in DETAIL), nothing written
--   -> every chosen space the field does not already hold must be one I am
--      related to NOW: a local active/paused membership on this
--      installation, or a membership fact in force (#2563 C2, 0569). A space
--      kept from the saved choice is not re-verified -- keeping it widens
--      nothing -- and a stale one is never re-added
--   -> write through the common writer under the same (re-entrant) lock
--   -> answer {schema_version: 1, visibility: my_visibility_network_v1()}
--      from the same transaction.
--
-- One lock for every writer: `account_visibility_lock(user)` takes
-- pg_advisory_xact_lock(hashtextextended('account-visibility:' || user, 0));
-- the reference writer and the legacy UUID writer (set_visibility,
-- set_contact_availability) both take it, so a legacy write and a checked
-- one serialize, and the checked one then sees the legacy result and
-- conflicts. A hash collision only serializes two accounts, harmlessly.
-- Legacy writers keep their last-write behaviour: they are not made
-- optimistic.
--
-- The legacy UUID writer converts its local workspace ids to network ids
-- through this installation's own workspaces before the common writer; an
-- id this installation does not host is refused, never guessed.
-- No local workspace row is needed for a reference to another
-- installation. No revision counter: the comparison IS the saved value.

-- ── the per-account lock ─────────────────────────────────────────────
create or replace function public.account_visibility_lock(p_user uuid)
returns void language plpgsql volatile security definer set search_path = public as $fn$
begin
  perform pg_advisory_xact_lock(hashtextextended('account-visibility:' || p_user::text, 0));
end;
$fn$;
revoke execute on function public.account_visibility_lock(uuid)
  from public, anon, authenticated, service_role;

-- ── the common writer, by network reference ──────────────────────────
create or replace function public.write_account_audience_refs(
  p_user uuid, p_field text, p_audience text, p_refs text[]
) returns void language plpgsql volatile security definer set search_path = public as $fn$
begin
  if p_user is null or p_user is distinct from auth.uid() then
    raise exception 'not authenticated';
  end if;
  perform public.account_visibility_lock(p_user);
  if p_field in ('contact_channels', 'presence') and p_audience = 'signed_in' then
    raise exception 'this field never goes beyond your spaces';
  end if;
  insert into public.account_field_audience (user_id, field, audience)
  values (p_user, p_field, p_audience)
  on conflict (user_id, field) do update set audience = excluded.audience;
  delete from public.account_field_audience_spaces
   where user_id = p_user and field = p_field;
  if p_audience = 'chosen_spaces' then
    -- The stamp trigger (0566) maps a reference of this installation to its
    -- local id and refuses an unknown one; another installation's keeps none.
    insert into public.account_field_audience_spaces (user_id, field, workspace_network_id)
    select distinct p_user, p_field, r from unnest(p_refs) r where r is not null;
  end if;
  if p_field = 'reachability' then
    insert into public.account_contact_settings (user_id, available)
    values (p_user, p_audience = 'signed_in')
    on conflict (user_id) do update set available = excluded.available
     where public.account_contact_settings.available is distinct from excluded.available;
  end if;
end;
$fn$;
revoke execute on function public.write_account_audience_refs(uuid, text, text, text[])
  from public, anon, authenticated, service_role;

-- 0392's legacy writer, restated whole: local ids become this
-- installation's network ids, then the common writer, under the same lock.
create or replace function public.write_account_audience(
  p_user uuid, p_field text, p_audience text, p_workspaces uuid[]
) returns void language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_refs text[];
begin
  if p_user is null or p_user is distinct from auth.uid() then
    raise exception 'not authenticated';
  end if;
  perform public.account_visibility_lock(p_user);
  if p_audience = 'chosen_spaces' and coalesce(cardinality(p_workspaces), 0) > 0 then
    select array_agg(w.network_id order by w.network_id) into v_refs
      from public.workspaces w
     where w.id in (select x from unnest(p_workspaces) x);
    if coalesce(cardinality(v_refs), 0)
       <> (select count(distinct x) from unnest(p_workspaces) x where x is not null) then
      raise exception 'unknown workspace' using errcode = '22023';
    end if;
  end if;
  perform public.write_account_audience_refs(p_user, p_field, p_audience, v_refs);
end;
$fn$;
revoke execute on function public.write_account_audience(uuid, text, text, uuid[])
  from public, anon, authenticated, service_role;

-- ── what is saved, and what may be added ─────────────────────────────
-- One field as the checked writer compares it: the audience the shared
-- policy reads (defaults and the legacy switch included) and the saved
-- references, sorted bytewise.
create or replace function public.account_visibility_saved_field(p_user uuid, p_field text)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  return jsonb_build_object(
    'audience', public.account_audience_of(p_user, p_field),
    'workspace_refs', coalesce((select jsonb_agg(s.workspace_network_id
                                                 order by s.workspace_network_id collate "C")
                                  from public.account_field_audience_spaces s
                                 where s.user_id = p_user and s.field = p_field), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.account_visibility_saved_field(uuid, text)
  from public, anon, authenticated, service_role;

-- Whether [p_user] is related to the space [p_ref] now: an active or paused
-- membership here, or a membership fact in force from its own installation.
create or replace function public.account_space_eligible(p_user uuid, p_ref text)
returns boolean language plpgsql stable security definer set search_path = public as $fn$
begin
  if p_user is null or not coalesce(public.workspace_network_ref_valid(p_ref), false) then
    return false;
  end if;
  if split_part(p_ref, ':', 1) = public.installation_id()::text then
    return exists (select 1 from public.workspaces w
                     join public.members m on m.workspace_id = w.id
                    where w.network_id = p_ref and m.user_id = p_user
                      and m.status in ('active', 'paused'));
  end if;
  return public.membership_fact_in_force(p_user, p_ref, array['active', 'paused']);
end;
$fn$;
revoke execute on function public.account_space_eligible(uuid, text)
  from public, anon, authenticated, service_role;

-- ── the checked writer ───────────────────────────────────────────────
create or replace function public.set_visibility_if_unchanged_network_v1(
  p_field text, p_audience text, p_workspace_refs text[], p_expected jsonb
) returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_audiences constant text[] := array['nobody', 'my_spaces', 'chosen_spaces', 'signed_in'];
  v_expected_refs text[];
  v_expected jsonb;
  v_current jsonb;
  v_refs text[];
begin
  perform public.mcp_require_native();
  v_me := auth.uid();
  if p_field is null or p_field not in
     ('identity', 'about', 'contact_channels', 'presence', 'reachability') then
    raise exception 'unknown field' using errcode = '22023';
  end if;
  if p_audience is null or not (p_audience = any (v_audiences)) then
    raise exception 'unknown audience' using errcode = '22023';
  end if;
  if p_field in ('contact_channels', 'presence') and p_audience = 'signed_in' then
    raise exception 'this field never goes beyond your spaces' using errcode = '22023';
  end if;

  -- The expected field: exactly {audience, workspace_refs}, well formed.
  if jsonb_typeof(p_expected) is distinct from 'object' then
    raise exception 'malformed expected visibility' using errcode = '22023';
  end if;
  if (select count(*) from jsonb_object_keys(p_expected)) <> 2
     or not (p_expected ? 'audience') or not (p_expected ? 'workspace_refs') then
    raise exception 'malformed expected visibility' using errcode = '22023';
  end if;
  if jsonb_typeof(p_expected->'audience') is distinct from 'string'
     or jsonb_typeof(p_expected->'workspace_refs') is distinct from 'array' then
    raise exception 'malformed expected visibility' using errcode = '22023';
  end if;
  if not ((p_expected->>'audience') = any (v_audiences))
     or jsonb_array_length(p_expected->'workspace_refs') > 200
     or exists (select 1 from jsonb_array_elements(p_expected->'workspace_refs') e
                 where jsonb_typeof(e) <> 'string') then
    raise exception 'malformed expected visibility' using errcode = '22023';
  end if;
  v_expected_refs := array(select distinct r
                             from jsonb_array_elements_text(p_expected->'workspace_refs') r
                            order by r collate "C");
  if exists (select 1 from unnest(v_expected_refs) r
              where not coalesce(public.workspace_network_ref_valid(r), false))
     or ((p_expected->>'audience') <> 'chosen_spaces' and cardinality(v_expected_refs) > 0) then
    raise exception 'malformed expected visibility' using errcode = '22023';
  end if;
  v_expected := jsonb_build_object('audience', p_expected->>'audience',
                                   'workspace_refs', to_jsonb(v_expected_refs));

  -- The intended chosen spaces: qualified references only, at least one.
  if p_audience = 'chosen_spaces' then
    if exists (select 1 from unnest(p_workspace_refs) r
                where r is null or not coalesce(public.workspace_network_ref_valid(r), false)) then
      raise exception 'malformed workspace reference' using errcode = '22023';
    end if;
    v_refs := array(select distinct r from unnest(p_workspace_refs) r order by r collate "C");
    if coalesce(cardinality(v_refs), 0) = 0 then
      raise exception 'choose at least one space' using errcode = '22023';
    end if;
    if cardinality(v_refs) > 200 then
      raise exception 'choose at most 200 spaces' using errcode = '22023';
    end if;
  elsif coalesce(cardinality(p_workspace_refs), 0) > 0 then
    raise exception 'spaces are chosen only with chosen spaces' using errcode = '22023';
  end if;

  perform public.account_visibility_lock(v_me);
  v_current := public.account_visibility_saved_field(v_me, p_field);
  if v_current is distinct from v_expected then
    raise exception 'visibility_conflict' using errcode = 'PT409', detail = v_current::text;
  end if;
  if p_audience = 'chosen_spaces' and exists (
       select 1 from unnest(v_refs) r
        where not ((v_current->>'audience') = 'chosen_spaces' and (v_current->'workspace_refs') ? r)
          and not public.account_space_eligible(v_me, r)) then
    raise exception 'choose spaces you belong to';
  end if;
  perform public.write_account_audience_refs(v_me, p_field, p_audience, v_refs);
  return jsonb_build_object('schema_version', 1,
                            'visibility', public.my_visibility_network_v1());
end;
$fn$;
revoke execute on function public.set_visibility_if_unchanged_network_v1(text, text, text[], jsonb)
  from public, anon;
grant execute on function public.set_visibility_if_unchanged_network_v1(text, text, text[], jsonb)
  to authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(9998);
