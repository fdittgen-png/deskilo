-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0320 (#2010) -- a level reorder is one command: the whole new order, or
-- nothing.
--
-- The editor wrote one `update levels set sort_order = i` per level over
-- HTTP. A failure half-way left a partial order on the server, and a
-- second editor saving at the same time interleaved the two permutations.
--
-- `reorder_levels(workspace, ordered ids, expected ids)`:
--   * the caller must be allowed to write the workspace's levels today
--     (`levels_write`: the owner);
--   * `p_level_ids` is a PERMUTATION of every level of the workspace: no
--     duplicate, no foreign or unknown id, none missing;
--   * `p_expected` is the order the editor read; when the levels have
--     moved since, the answer is `conflict` with the current order, and
--     nothing is written;
--   * the levels are locked in id order, then every sort_order is written
--     in this one transaction.
-- A delegated assistant token is refused, like every plan write.

create or replace function public.reorder_levels(
  p_workspace_id uuid,
  p_level_ids uuid[],
  p_expected uuid[]
) returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_current uuid[];
  v_count int;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if public.mcp_is_delegated() then raise exception 'levels are arranged in the Deskilo app'; end if;
  if p_workspace_id is null or not public.is_owner_of(p_workspace_id) then
    raise exception 'only the owner arranges the levels';
  end if;

  -- Lock every level of the workspace in a deterministic order first.
  perform 1 from public.levels where workspace_id = p_workspace_id order by id for update;

  select coalesce(array_agg(id order by sort_order, id), '{}') into v_current
    from public.levels where workspace_id = p_workspace_id;

  if p_expected is distinct from v_current then
    return jsonb_build_object('status', 'conflict', 'current', to_jsonb(v_current));
  end if;

  select count(distinct x) into v_count from unnest(coalesce(p_level_ids, '{}')) x;
  if v_count <> coalesce(cardinality(p_level_ids), 0)
     or v_count <> cardinality(v_current)
     or exists (select 1 from unnest(p_level_ids) x where x <> all (v_current)) then
    return jsonb_build_object('status', 'refused', 'reason', 'not_a_permutation');
  end if;

  update public.levels l
     set sort_order = o.ord - 1
    from unnest(p_level_ids) with ordinality as o(id, ord)
   where l.id = o.id and l.workspace_id = p_workspace_id;

  return jsonb_build_object('status', 'saved', 'order', to_jsonb(p_level_ids));
end;
$fn$;
revoke execute on function public.reorder_levels(uuid, uuid[], uuid[]) from public, anon;
grant execute on function public.reorder_levels(uuid, uuid[], uuid[]) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(320);
