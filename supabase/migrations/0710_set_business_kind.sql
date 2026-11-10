-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one new RPC; no table, policy or existing function changes)
--
-- #3549/#3550 -- a workspace says what kind of business it is, from its
-- first setup step on. business.kind and business.more_kinds are registry
-- settings (0703), but set_setting writes a workspace value only while the
-- platform feature configurableSettings is on, and a new space has it off.
-- set_business_kind writes the pair without that gate:
--
--  * the caller is signed in, not a delegated assistant (set_setting's own
--    rule), and holds manageConfiguration in the workspace;
--  * both keys in one transaction, the primary first: a further kind equal
--    to the new primary is dropped from the further kinds, and when the
--    stored further kinds hold the new primary they are cleared first, so
--    business_kind_setting_check (0703/0704) always sees a consistent pair
--    and a swap (primary <-> further kind) succeeds;
--  * every write goes through store_setting: versioned and audited like any
--    setting. Unknown or inactive kinds are refused by the same trigger.

create or replace function public.set_business_kind(
  p_workspace uuid, p_kind text, p_more_kinds text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_more text;
  v_stored_more text;
  v_changed boolean := false;
begin
  if auth.uid() is null or public.mcp_is_delegated() then raise exception 'not allowed'; end if;
  if p_workspace is null or p_kind is null then
    raise exception 'a business kind names its workspace and its kind' using errcode = '22023';
  end if;
  if not public.has_permission(p_workspace, 'manageConfiguration') then
    raise exception 'not allowed to change this setting';
  end if;
  v_more := array_to_string(array(
    select distinct on (btrim(c)) btrim(c)
      from unnest(string_to_array(coalesce(p_more_kinds, ''), ',')) with ordinality as t(c, n)
     where btrim(c) <> '' and btrim(c) <> p_kind
     order by btrim(c), n), ',');
  v_stored_more := public.setting_value(p_workspace, 'business.more_kinds') #>> '{}';
  if p_kind = any (string_to_array(coalesce(v_stored_more, ''), ',')) then
    v_changed := public.store_setting(p_workspace, 'business.more_kinds', '""'::jsonb, '', auth.uid()) or v_changed;
  end if;
  v_changed := public.store_setting(p_workspace, 'business.kind', to_jsonb(p_kind), '', auth.uid()) or v_changed;
  v_changed := public.store_setting(p_workspace, 'business.more_kinds', to_jsonb(v_more), '', auth.uid()) or v_changed;
  if v_changed then
    insert into public.database_authority_audit (installation_id, action, actor, detail)
    values (public.installation_id(), 'setting_set', 'member:' || auth.uid(),
            jsonb_build_object('key', 'business.kind', 'workspace_id', p_workspace,
                               'value', jsonb_build_object('kind', p_kind, 'more_kinds', v_more)));
  end if;
  return jsonb_build_object('status', case when v_changed then 'saved' else 'unchanged' end,
                            'kind', p_kind, 'more_kinds', v_more);
end;
$fn$;
revoke execute on function public.set_business_kind(uuid, text, text) from public, anon;
grant execute on function public.set_business_kind(uuid, text, text) to authenticated;

select public.set_deskilo_schema_version(710);
