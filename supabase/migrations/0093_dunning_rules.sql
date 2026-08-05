-- SPDX-License-Identifier: 0BSD
-- Mahnwesen (#472): parameterizable dunning rules per workspace. The
-- client derives reminder SUGGESTIONS from them; nothing fires
-- automatically — a human always sends. Keys (client-defined, defaults
-- in DunningRules): levels (max reminders, default 3), first_after_days
-- (days after issue before level 1 is suggested, default 14),
-- between_days (days between levels, default 14). RLS: workspaces_update
-- already restricts writes to the owner.
alter table public.workspaces
  add column if not exists dunning_rules jsonb not null
    default '{}'::jsonb;
