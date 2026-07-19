-- SPDX-License-Identifier: MIT
-- A background image per level — a photo or blueprint of the real
-- working space, rendered behind the seat/desk graphics so the plan
-- reads against the actual room. Applied to the hosted reference
-- project on 2026-07-19.
--
-- The image lives in the private `floor-plans` storage bucket at
-- `<workspace_id>/<level_id>`; the level row keeps the object path.
-- Reads are workspace-scoped, writes owner-only, both enforced by
-- storage.objects RLS that derives the workspace from the first path
-- segment.

alter table public.levels add column background_path text;

-- Storage RLS on the floor-plans bucket. The first folder of the object
-- name is the workspace id; membership / ownership gate access.
create policy floor_plans_select on storage.objects
  for select using (
    bucket_id = 'floor-plans'
    and public.is_member_of((storage.foldername(name))[1]::uuid)
  );

create policy floor_plans_insert on storage.objects
  for insert with check (
    bucket_id = 'floor-plans'
    and public.is_owner_of((storage.foldername(name))[1]::uuid)
  );

create policy floor_plans_update on storage.objects
  for update using (
    bucket_id = 'floor-plans'
    and public.is_owner_of((storage.foldername(name))[1]::uuid)
  );

create policy floor_plans_delete on storage.objects
  for delete using (
    bucket_id = 'floor-plans'
    and public.is_owner_of((storage.foldername(name))[1]::uuid)
  );
