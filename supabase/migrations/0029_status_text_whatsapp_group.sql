-- SPDX-License-Identifier: 0BSD
-- DesKilo member-directory upgrade (epic #229, issue #231). NOT YET
-- applied to the hosted reference project — the orchestrator applies it
-- after review.
--
-- profiles gains one column:
--  * status_text — a short self-set status line ("In a call · back at
--    14:00"), shown next to the member in the directory (#232). '' means
--    "no status" (mirrors display_name's not-null-empty convention from
--    0001). The check caps it at 40 characters — the same limit the
--    client enforces via StatusTextRules.maxLength (cross-pinned by
--    test).
--
-- workspaces gains one column:
--  * whatsapp_group — the owner-set invite link of the community's
--    WhatsApp group. '' means "no group configured". The check accepts
--    only real chat.whatsapp.com invite links (prefix-anchored), so a
--    raw write can never smuggle in an arbitrary URL that members would
--    then be asked to open.
--
-- RLS: deliberately NO new policies.
--  * profiles.status_text rides 0002's existing policies exactly like
--    0028's whatsapp column did: profiles_select exposes whole rows to
--    self + shares_workspace_with(id) — precisely the directory readers
--    (#232) — and profiles_update stays self-only, which covers the
--    status editor.
--  * workspaces.whatsapp_group rides 0002's workspaces_select
--    (`using (public.is_member_of(id))` — every member reads whole
--    workspace rows, so the link reaches the directory) and
--    workspaces_update (`is_owner_of` — only the owner can set it).

alter table public.profiles
  add column status_text text not null default ''
    check (char_length(status_text) <= 40);

alter table public.workspaces
  add column whatsapp_group text not null default ''
    check (whatsapp_group = '' or whatsapp_group ~ '^https://chat\.whatsapp\.com/');
