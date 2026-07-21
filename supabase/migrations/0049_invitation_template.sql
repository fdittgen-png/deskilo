-- SPDX-License-Identifier: 0BSD
-- Owner-configurable invitation message template. NOT YET applied to the
-- hosted reference project — the orchestrator applies it after review.
--
-- The template is plain text with {tag} placeholders filled client-side
-- ({firstName}, {lastName}, {phone}, {workspaceName}, {workspaceId},
-- {inviteLink}, {downloadUrl}, {role}). Empty means "use the app's
-- localized default message". Rides the existing owner-only
-- workspaces_update RLS — no new policies (0029 shape).

alter table public.workspaces add column if not exists invitation_template
  text not null default ''
  check (char_length(invitation_template) <= 2000);
