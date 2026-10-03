-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0363 (#2137) -- editing the floor plan is delegable through manageSites.
--
-- The owner's decision: the floor plan is edited by the owner and by
-- whoever holds the existing permission "Manage sites" -- now "Manage
-- sites and edit the floor plan". No new permission; the built-in
-- Administrator's defaults are unchanged (they already include
-- manageSites, so an Administrator edits the plan unless the owner takes
-- the permission off its row of the matrix).
--
--   * the plan tables -- levels, offices, desks, seats, plan images --
--     gain a write policy for manageSites beside the owner's;
--   * the floor-plans storage bucket the same, for the plan's own files
--     (level backgrounds `<ws>/<level>`, plan images `<ws>/img/...`) and
--     not the document images that share the bucket (`<ws>/report/...`);
--   * the definers the editor calls -- delete_plan_object, reorder_levels,
--     import_floor_plan (v1, v2), plan_media_orphans -- accept
--     manageSites beside the owner; import_floor_plan_v3 accepts it beside
--     manageConfiguration.
--
-- The definers are patched at asserted anchors: their live bodies are the
-- replay's (the contract digests match), so each patch changes exactly
-- the authority line.

-- ── the plan tables ────────────────────────────────────────────────────
drop policy if exists levels_write_sites on public.levels;
create policy levels_write_sites on public.levels
  for all
  using (workspace_id in (select public.workspaces_permitting(array['manageSites'])))
  with check (workspace_id in (select public.workspaces_permitting(array['manageSites'])));

drop policy if exists offices_write_sites on public.offices;
create policy offices_write_sites on public.offices
  for all
  using (workspace_id in (select public.workspaces_permitting(array['manageSites'])))
  with check (workspace_id in (select public.workspaces_permitting(array['manageSites'])));

drop policy if exists desks_write_sites on public.desks;
create policy desks_write_sites on public.desks
  for all
  using (workspace_id in (select public.workspaces_permitting(array['manageSites'])))
  with check (workspace_id in (select public.workspaces_permitting(array['manageSites'])));

drop policy if exists seats_write_sites on public.seats;
create policy seats_write_sites on public.seats
  for all
  using (workspace_id in (select public.workspaces_permitting(array['manageSites'])))
  with check (workspace_id in (select public.workspaces_permitting(array['manageSites'])));

drop policy if exists plan_images_write_sites on public.plan_images;
create policy plan_images_write_sites on public.plan_images
  for all
  using (workspace_id in (select public.workspaces_permitting(array['manageSites'])))
  with check (workspace_id in (select public.workspaces_permitting(array['manageSites'])));

-- ── the floor-plans bucket ─────────────────────────────────────────────
drop policy if exists floor_plans_insert_sites on storage.objects;
create policy floor_plans_insert_sites on storage.objects
  for insert with check (
    bucket_id = 'floor-plans'
    and coalesce((storage.foldername(name))[2], '') <> 'report'
    and public.has_permission((storage.foldername(name))[1]::uuid, 'manageSites')
  );

drop policy if exists floor_plans_update_sites on storage.objects;
create policy floor_plans_update_sites on storage.objects
  for update using (
    bucket_id = 'floor-plans'
    and coalesce((storage.foldername(name))[2], '') <> 'report'
    and public.has_permission((storage.foldername(name))[1]::uuid, 'manageSites')
  );

drop policy if exists floor_plans_delete_sites on storage.objects;
create policy floor_plans_delete_sites on storage.objects
  for delete using (
    bucket_id = 'floor-plans'
    and coalesce((storage.foldername(name))[2], '') <> 'report'
    and public.has_permission((storage.foldername(name))[1]::uuid, 'manageSites')
  );

-- ── the editor's definers ──────────────────────────────────────────────
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text language plpgsql as $f$
begin
  if position(p_old in p_def) = 0 then return null; end if;
  return replace(p_def, p_old, p_new);
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
  v_patched text;
  v_missing text[] := '{}';
begin
  v_def := pg_get_functiondef('public.delete_plan_object(text, uuid)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$if not public.is_owner_of(v_workspace_id) then$a$,
    $a$if not (public.is_owner_of(v_workspace_id)
          or public.has_permission(v_workspace_id, 'manageSites')) then$a$);
  if v_patched is null then v_missing := v_missing || 'delete_plan_object'::text;
  else execute v_patched; end if;

  v_def := pg_get_functiondef('public.import_floor_plan(uuid, jsonb)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$if not public.is_owner_of(p_workspace_id) then$a$,
    $a$if not (public.is_owner_of(p_workspace_id)
          or public.has_permission(p_workspace_id, 'manageSites')) then$a$);
  if v_patched is null then v_missing := v_missing || 'import_floor_plan'::text;
  else execute v_patched; end if;

  v_def := pg_get_functiondef('public.import_floor_plan_v2(uuid, jsonb, jsonb)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$if not public.is_owner_of(p_workspace_id) then$a$,
    $a$if not (public.is_owner_of(p_workspace_id)
          or public.has_permission(p_workspace_id, 'manageSites')) then$a$);
  if v_patched is null then v_missing := v_missing || 'import_floor_plan_v2'::text;
  else execute v_patched; end if;

  v_def := pg_get_functiondef('public.import_floor_plan_v3(uuid, jsonb, jsonb)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$if not public.has_permission(p_workspace_id, 'manageConfiguration') then$a$,
    $a$if not (public.has_permission(p_workspace_id, 'manageConfiguration')
          or public.has_permission(p_workspace_id, 'manageSites')) then$a$);
  if v_patched is null then v_missing := v_missing || 'import_floor_plan_v3'::text;
  else execute v_patched; end if;

  v_def := pg_get_functiondef('public.plan_media_orphans(uuid, integer)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$where public.is_owner_of(p_workspace_id)$a$,
    $a$where (public.is_owner_of(p_workspace_id)
          or public.has_permission(p_workspace_id, 'manageSites'))$a$);
  if v_patched is null then v_missing := v_missing || 'plan_media_orphans'::text;
  else execute v_patched; end if;

  v_def := pg_get_functiondef('public.reorder_levels(uuid, uuid[], uuid[])'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$if p_workspace_id is null or not public.is_owner_of(p_workspace_id) then$a$,
    $a$if p_workspace_id is null or not (public.is_owner_of(p_workspace_id)
          or public.has_permission(p_workspace_id, 'manageSites')) then$a$);
  if v_patched is null then v_missing := v_missing || 'reorder_levels'::text;
  else execute v_patched; end if;

  if cardinality(v_missing) > 0 then
    raise exception '0363: anchors did not match: %', array_to_string(v_missing, ', ');
  end if;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(363);
