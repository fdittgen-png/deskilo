-- SPDX-License-Identifier: 0BSD
-- 0215 — #1316: storage reads on `floor-plans` belong to the workspace's members,
-- and the bucket they read from is finally created by a migration.
--
-- The hosted reference deployment carried a policy no migration ever
-- wrote:
--
--   floor_plans_read  SELECT on storage.objects
--                     using (bucket_id = 'floor-plans'
--                            and auth.role() = 'authenticated')
--
-- Storage policies are permissive and OR together, so it sat beside
-- 0036's `floor_plans_select` — which asks `is_member_of` the workspace
-- folder — and won. Any signed-in person could read, and list, every
-- workspace's plan backgrounds, plan images and document images
-- (`<workspace>/report/…`). Found by comparing the live `pg_policies`
-- with the policies a replay of these migrations produces: it was the
-- only difference, and no recorded migration mentions it, so it was
-- created by hand.
--
-- Harnessed on the dev project in a rolled-back transaction before this
-- file was applied: a signed-in non-member saw 3 of one workspace's
-- objects and listed 3 workspace folders; after the drop, 0 and 0; a
-- member of that workspace still saw its own 3.
--
-- Nothing the app does needs the broad read. Every client read of the
-- bucket is by a member: level backgrounds and plan images
-- (`supabase_floor_plan_repository.dart`), document images
-- (`supabase_money_repository.dart`), the kiosk, and the deployment
-- copy between two workspaces the same owner belongs to. Edge functions
-- use the service role and are unaffected.
--
-- `if exists` makes this a no-op on every instance built from these
-- files — the policy never existed there — and the fix on the one that
-- has it. `supabase/tests/database/12_storage_tenancy.sql` keeps the
-- property from here on.
--
-- The bucket, while here. No migration ever created it: 0036 wrote the
-- `floor-plans` policies and assumed the bucket, which on the hosted
-- project was made by hand as well. Every instance built from these
-- files — the new-instance wizard (#977), CI's replay — has had no
-- `floor-plans` bucket, so level backgrounds, plan images and document
-- images could not be stored there, and the doctor's bucket check would
-- say so. Same idiom as 0038's `avatars`: private, idempotent, a no-op
-- where it already exists.
--
-- With the hosted bucket's own limits, read from it rather than invented:
-- 10 MiB, and PNG, JPEG or WebP only. Everything the app stores here is
-- one of those three, and an instance should not get a looser bucket than
-- the deployment it was modelled on.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('floor-plans', 'floor-plans', false, 10485760,
        array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do nothing;

drop policy if exists floor_plans_read on storage.objects;
