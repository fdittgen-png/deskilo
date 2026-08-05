-- SPDX-License-Identifier: 0BSD
-- Workspace language + translated invitation templates (#486).
--
-- default_locale: the workspace's own language ('' = unset → the
-- sender's app language). Invitations default to it; any UI may follow.
-- invitation_templates: per-locale CUSTOM templates keyed by language
-- code ({"fr": "...", "de": "..."}); an absent key falls back to the
-- legacy single invitation_template (0049), then to the app's built-in
-- localized message. RLS: workspaces_update already restricts writes to
-- the owner.
alter table public.workspaces
  add column if not exists default_locale text not null default ''
    check (char_length(default_locale) <= 5),
  add column if not exists invitation_templates jsonb not null
    default '{}'::jsonb;
