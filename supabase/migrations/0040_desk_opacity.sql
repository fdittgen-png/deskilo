-- SPDX-License-Identifier: 0BSD
-- Configurable desk transparency: the owner can make desk fills
-- translucent so a level's background photo shows through the drawn
-- tables. Applied to the hosted reference project on 2026-07-20.
--
-- Stored as an opacity percentage (100 = solid, the historical look;
-- lower = more see-through). Clamped 20..100 so desks never fully vanish.
-- Owner-writable via the existing workspaces_update RLS.

alter table public.workspaces
  add column desk_opacity smallint not null default 100
    check (desk_opacity between 20 and 100);
