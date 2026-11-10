-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (five nullable or defaulted columns on public.services and their checks; no
-- policy, function or charge path changes)
--
-- #3552 -- a service worth publishing. A service business is its services;
-- to show them to a stranger they need more than a name and a price:
--
--  * description       text, at most 2000 characters;
--  * duration_minutes  int, null = not time-based, else 5..1440;
--  * category          text, free, at most 40 characters, never blank;
--  * is_public         boolean, default false: shown on the public page only
--                      when the business says so;
--  * sort_order        int, default 0: the order within its category.
--
-- Writes go through the existing services_write_permitted policy (0361:
-- manageServices), so is_public is writable exactly by whoever edits services
-- today. Charging (record_service_charge) reads none of these columns.

alter table public.services
  add column if not exists description text,
  add column if not exists duration_minutes integer,
  add column if not exists category text,
  add column if not exists is_public boolean not null default false,
  add column if not exists sort_order integer not null default 0;

alter table public.services
  drop constraint if exists services_description_length,
  add constraint services_description_length
    check (description is null or char_length(description) <= 2000),
  drop constraint if exists services_duration_range,
  add constraint services_duration_range
    check (duration_minutes is null or duration_minutes between 5 and 1440),
  drop constraint if exists services_category_shape,
  add constraint services_category_shape
    check (category is null or (char_length(category) between 1 and 40 and btrim(category) <> '')),
  drop constraint if exists services_sort_order_range,
  add constraint services_sort_order_range
    check (sort_order between 0 and 100000);

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(711);
