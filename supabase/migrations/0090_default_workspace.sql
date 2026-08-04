-- SPDX-License-Identifier: 0BSD
-- Server-synced default workspace (#458): the #322 default-profile
-- choice was device-local shared prefs, so it vanished on reinstall and
-- never followed the user across platforms. It is the USER's choice —
-- stored on their profile row (profiles_update RLS is already
-- self-only; profiles_select lets co-members read it, which leaks
-- nothing but a workspace id they share anyway). Deleting the workspace
-- clears the pointer instead of breaking the profile.
alter table public.profiles
  add column if not exists default_workspace_id uuid
    references public.workspaces(id) on delete set null;
