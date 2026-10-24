-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- Additive: one new writer; no table, column, policy or existing function
-- changes.
--
-- 9999 (#2554) -- the favourite heart of My spaces is kept on the account.
--
-- My spaces names every workspace by its qualified reference
-- (`<installation id>:<local id>`, #2561/#2563), but the only server
-- writer of a favourite, `set_workspace_favorite(uuid, boolean)` (0376),
-- takes a LOCAL workspace id, so a space hosted by another installation
-- could only be marked on the device. 0566 already moved
-- `workspace_favorites` to the reference; this is its writer.
--
-- set_workspace_favorite_ref_v1(p_ref, p_on) sets (p_on true) or clears
-- (p_on false) the caller's own favourite by reference. Authenticated,
-- first-party sessions only (`mcp_require_native`). A reference may be
-- marked when it names
--   * a workspace of THIS installation that the caller may already mark
--     with the legacy writer: one they belong to, or a listed one (0376's
--     rule, unchanged); or
--   * a workspace of another installation the caller holds a membership
--     fact in force for (0569's `membership_fact_in_force`, statuses
--     active, paused or pending) -- received under the source's enrolment
--     in force and inside its deadline.
-- Anything else is refused and nothing is written: a malformed or unknown
-- local reference 22023, a reference the caller has no relationship with
-- 42501. Clearing a favourite the caller already holds is always allowed:
-- removing one's own mark grants nothing, and a lapsed fact must not
-- leave a heart that cannot be taken off. Clearing a reference the caller
-- holds no favourite for follows the marking rule, so an unrelated
-- reference is refused either way.
--
-- The row is written as 0566's stamp expects: a local workspace by its id
-- (the stamp writes its stored network id), another installation's by
-- reference alone (no local id). The answer is the reference and whether
-- it is now a favourite -- what `my_personal_workspace_refs_v1` then
-- reads as `is_favorite`.
--
-- My review stays on the device: #2554 keeps "existing personal
-- preferences ... (or their explicitly existing device-local store)" and
-- excludes a rating engine rewrite and cloud preference expansion, so no
-- rating table by reference is added here.

create or replace function public.set_workspace_favorite_ref_v1(p_ref text, p_on boolean default true)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid := auth.uid();
  v_local uuid;
  v_held boolean;
begin
  perform public.mcp_require_native();
  if p_ref is null or not public.workspace_network_ref_valid(p_ref) then
    raise exception 'malformed workspace reference' using errcode = '22023';
  end if;
  -- null for another installation; 22023 for an unknown reference here.
  v_local := public.local_workspace_of_ref(p_ref);
  v_held := exists (select 1 from public.workspace_favorites f
                     where f.user_id = v_me and f.workspace_network_id = p_ref);
  if not (coalesce(p_on, true) is false and v_held) then
    if (case when v_local is not null
             then not (public.is_member_of(v_local)
                       or exists (select 1 from public.workspaces w
                                   where w.id = v_local and w.visibility_set_at is not null))
             else not public.membership_fact_in_force(
                        v_me, p_ref, array['active', 'paused', 'pending']::text[])
        end) then
      raise exception 'no relationship with this workspace' using errcode = '42501';
    end if;
  end if;
  if coalesce(p_on, true) then
    if v_local is not null then
      insert into public.workspace_favorites (user_id, workspace_id)
      values (v_me, v_local)
      on conflict do nothing;
    else
      insert into public.workspace_favorites (user_id, workspace_network_id)
      values (v_me, p_ref)
      on conflict do nothing;
    end if;
  else
    delete from public.workspace_favorites
     where user_id = v_me and workspace_network_id = p_ref;
  end if;
  return jsonb_build_object(
    'network_id', p_ref,
    'is_favorite', exists (select 1 from public.workspace_favorites f
                            where f.user_id = v_me and f.workspace_network_id = p_ref));
end;
$fn$;
revoke execute on function public.set_workspace_favorite_ref_v1(text, boolean) from public, anon;
grant execute on function public.set_workspace_favorite_ref_v1(text, boolean) to authenticated;
comment on function public.set_workspace_favorite_ref_v1(text, boolean) is
  '#2554 -- sets or clears the caller''s favourite by qualified workspace '
  'reference: a workspace here they may mark, or one they hold a membership '
  'fact in force for; anything else is refused (22023/42501), nothing written.';

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(577);
