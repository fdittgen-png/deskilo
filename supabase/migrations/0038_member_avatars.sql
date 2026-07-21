-- SPDX-License-Identifier: 0BSD
-- Member profile photos (avatars): each user may set one photo, shown on
-- their directory row and detail sheet, on calendar/timeline blocks and
-- everywhere the initial avatar renders today. Applied to the hosted
-- reference project on 2026-07-19.
--
-- The photo lives in a private `avatars` storage bucket at
-- `<user_id>/avatar`; the profile row keeps the object path. Reads follow
-- the profile's own visibility (self + anyone sharing a workspace, exactly
-- like profiles_select, 0002), writes are self-only — both enforced by
-- storage.objects RLS deriving the owner from the first path segment.

alter table public.profiles add column avatar_path text;

-- Private bucket for avatars (id = name; created idempotently).
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false)
on conflict (id) do nothing;

-- The first folder of the object name is the owner's user id.
create policy avatars_select on storage.objects
  for select using (
    bucket_id = 'avatars'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.shares_workspace_with((storage.foldername(name))[1]::uuid)
    )
  );

create policy avatars_insert on storage.objects
  for insert with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy avatars_update on storage.objects
  for update using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy avatars_delete on storage.objects
  for delete using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
