-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one table, two rows of the settings registry, one trigger; no existing
-- function or policy changes)
--
-- #3549 -- a business says what it is. DesKilo serves small service
-- businesses side by side (owner, 2026-11-10): coworking spaces, studios,
-- practices, salons and other service businesses. The kind is data, never an
-- enum in business code:
--
--  * public.business_kinds -- the kinds the platform knows, with the feature
--    profile each one proposes (#3550 reads it). Readable by everyone signed
--    in; written by migrations only. Seeded: coworking, studio (classes and
--    courses), practice (appointments: massage, therapy, coaching), salon
--    (beauty, hair, tattoo), service (any other service business).
--  * business.kind        text, workspace, default 'coworking'
--  * business.more_kinds  text, workspace, default '' (comma-separated codes)
--    -- settings of the registry, edited with manageConfiguration. Every
--    existing workspace reads 'coworking' and nothing changes for it.
--  * business_kind_setting_check -- a value of either setting names active
--    kinds only, and more_kinds never repeats the primary kind or itself.
--
-- Nothing reads the kind yet but the app's BusinessProfile.

create table if not exists public.business_kinds (
  code text primary key check (code ~ '^[a-z][a-z_]{1,31}$'),
  sort_order integer not null,
  active boolean not null default true,
  feature_profile jsonb not null default '{}'::jsonb
    check (jsonb_typeof(feature_profile) = 'object')
);
select public.ensure_system_columns('business_kinds');

alter table public.business_kinds enable row level security;
revoke all on public.business_kinds from public, anon;
revoke insert, update, delete on public.business_kinds from authenticated;
grant select on public.business_kinds to authenticated;
drop policy if exists business_kinds_select on public.business_kinds;
create policy business_kinds_select on public.business_kinds
  for select to authenticated using (true);
drop policy if exists mcp_delegated_deny on public.business_kinds;
create policy mcp_delegated_deny on public.business_kinds as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

insert into public.business_kinds (code, sort_order) values
  ('coworking', 10),
  ('studio', 20),
  ('practice', 30),
  ('salon', 40),
  ('service', 50)
on conflict (code) do nothing;

-- ── a kind setting names known kinds ─────────────────────────────────────
create or replace function public.business_kind_setting_check()
returns trigger language plpgsql set search_path = public as $fn$
declare
  v_code text;
  v_codes text[];
  v_primary text;
begin
  if new.key = 'business.kind' then
    v_code := new.value #>> '{}';
    if not exists (select 1 from public.business_kinds k where k.code = v_code and k.active) then
      raise exception 'unknown business kind: %', v_code using errcode = '22023';
    end if;
  elsif new.key = 'business.more_kinds' then
    v_codes := array(select btrim(c) from unnest(string_to_array(coalesce(new.value #>> '{}', ''), ',')) c
                      where btrim(c) <> '');
    if exists (select 1 from unnest(v_codes) c
                where not exists (select 1 from public.business_kinds k where k.code = c and k.active)) then
      raise exception 'unknown business kind in %', new.value #>> '{}' using errcode = '22023';
    end if;
    if cardinality(v_codes) <> (select count(distinct c) from unnest(v_codes) c) then
      raise exception 'a business kind is listed twice' using errcode = '22023';
    end if;
    select v.value #>> '{}' into v_primary from public.setting_values v
     where v.key = 'business.kind' and v.scope = new.scope
       and v.workspace_id is not distinct from new.workspace_id and v.valid_to is null
     order by v.valid_from desc limit 1;
    if coalesce(v_primary, 'coworking') = any (v_codes) then
      raise exception 'the primary business kind is not a further kind' using errcode = '22023';
    end if;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.business_kind_setting_check() from public, anon, authenticated;

drop trigger if exists business_kind_setting_check on public.setting_values;
create trigger business_kind_setting_check
  before insert or update of value on public.setting_values
  for each row when (new.key in ('business.kind', 'business.more_kinds'))
  execute function public.business_kind_setting_check();

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('business.kind', 'text', '"coworking"'::jsonb, null, 32, '', 'business', array['workspace'], 'manageConfiguration', null, true, null, 'business kinds (#3549)', 'What kind of business the workspace is, as a code of public.business_kinds (coworking, studio, practice, salon, service). It proposes the features and words a business needs; coworking keeps every existing workspace as it was.'),
('business.more_kinds', 'text', '""'::jsonb, null, 200, '', 'business', array['workspace'], 'manageConfiguration', null, true, null, 'business kinds (#3549)', 'Further kinds the business also is, as comma-separated codes of public.business_kinds, never the primary one again. Empty means one kind only.')
on conflict (key) do nothing;
-- END GENERATED SEED

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(703);
