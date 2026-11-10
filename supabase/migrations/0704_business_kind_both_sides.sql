-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (re-creates one trigger function of 0703; no table or policy changes)
--
-- #3549 -- the kind check holds from both sides. 0703 refused a further kind
-- that repeats the primary one, but setting business.kind to a code already
-- listed in business.more_kinds passed. Now the primary kind may not be one of
-- the workspace's current further kinds either.

create or replace function public.business_kind_setting_check()
returns trigger language plpgsql set search_path = public as $fn$
declare
  v_code text;
  v_codes text[];
  v_primary text;
  v_more text;
begin
  if new.key = 'business.kind' then
    v_code := new.value #>> '{}';
    if not exists (select 1 from public.business_kinds k where k.code = v_code and k.active) then
      raise exception 'unknown business kind: %', v_code using errcode = '22023';
    end if;
    select v.value #>> '{}' into v_more from public.setting_values v
     where v.key = 'business.more_kinds' and v.scope = new.scope
       and v.workspace_id is not distinct from new.workspace_id and v.valid_to is null
     order by v.valid_from desc limit 1;
    if v_code = any (array(select btrim(c) from unnest(string_to_array(coalesce(v_more, ''), ',')) c)) then
      raise exception 'the business kind % is already a further kind', v_code using errcode = '22023';
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

select public.set_deskilo_schema_version(704);
