-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
--
-- #4479 -- two audit items on the units of measure.
--   * Conversion provenance: a conversion is GENERATED (the link of two units of one dimension, 0968) or AUTHORED (written by a
--     person with `unit_conversion_save_v1`). Editing the dimension or factor of an unused unit used to delete every conversion row
--     of the unit and write the defaults again, the authored ones with them. Now only generated rows are rewritten; an authored row
--     is kept and marked `needs_review`, because it was written for the unit as it was. Saving it again clears the mark. Rows that
--     exist are told apart by what they are: one whose factor is the one the two units give is generated, any other is authored.
--     The resolver is untouched: direct or inverse, an item's own before the general, never chained.
--   * The UN/ECE code of a unit is one of a maintained list (Recommendation 20 / 21, `unece_unit_known`), not any code of the right
--     shape. A code is checked when it is given or changed; the code a unit already holds stays until it is changed. The list is
--     pinned to the app's by test/parity/unece_unit_codes_parity_test.dart.
-- A refusal is the stock configuration's own (DKG11): `ece_invalid` (a code outside the list).

create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    raise exception '0990: % is not found exactly once', p_what using errcode = 'P0001';
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_once(text, text, text, text) from public;

-- ── 1. provenance ───────────────────────────────────────────────────────
-- audience: all row readers
alter table public.unit_conversions
  add column if not exists authored boolean not null default false,
  add column if not exists needs_review boolean not null default false;

-- what exists: a row is generated when its factor is the one its two units give (same dimension, no packaging), else authored
update public.unit_conversions c set authored = true
 where not exists (
   select 1 from public.workspace_units a
     join public.workspace_units b on b.workspace_id = a.workspace_id and b.code = c.to_unit
    where a.workspace_id = c.workspace_id and a.code = c.from_unit
      and a.dimension = b.dimension and a.dimension <> 'package'
      and c.factor_num::numeric * a.factor_den::numeric * b.factor_num::numeric
        = c.factor_den::numeric * a.factor_num::numeric * b.factor_den::numeric);

-- restates 0968
create or replace function public.workspace_units_relink()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if tg_op = 'UPDATE' then
    -- the generated rows of the unit are written again; an authored row is kept and asked to be looked at
    delete from public.unit_conversions
     where workspace_id = new.workspace_id and (from_unit = new.code or to_unit = new.code) and not authored;
    update public.unit_conversions set needs_review = true
     where workspace_id = new.workspace_id and (from_unit = new.code or to_unit = new.code) and authored;
  end if;
  if new.dimension <> 'package' then
    perform public.unit_conversions_link(new.workspace_id, new.code);
  end if;
  return new;
end;
$fn$;
revoke execute on function public.workspace_units_relink() from public, anon, authenticated;

-- a conversion a person writes is authored, and reviewed by being written
create or replace function pg_temp.replace_statement(p_def text, p_pattern text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (select count(*) from regexp_matches(p_def, p_pattern, 'g')) <> 1 then
    raise exception '0990: % is not found exactly once', p_what using errcode = 'P0001';
  end if;
  return regexp_replace(p_def, p_pattern, replace(p_new, '\', '\\'));
end
$f$;
revoke execute on function pg_temp.replace_statement(text, text, text, text) from public;

-- ── 2. the UN/ECE list ──────────────────────────────────────────────────
create or replace function public.unece_unit_known(p_code text)
returns boolean language sql immutable set search_path = public as $fn$
  select p_code = any(array[
    'ACR', 'ACT', 'AMP', 'ANN', 'ARE', 'BA', 'BE', 'BG', 'BL', 'BO',
    'BX', 'C62', 'CA', 'CLT', 'CMK', 'CMQ', 'CMT', 'CR', 'CS', 'CT',
    'DAY', 'DLT', 'DMQ', 'DMT', 'DR', 'DZN', 'E48', 'EA', 'FOT', 'FTK',
    'GLI', 'GLL', 'GRM', 'GRO', 'H87', 'HAR', 'HLT', 'HUR', 'INH', 'INK',
    'JOU', 'JR', 'KGM', 'KJO', 'KMK', 'KMT', 'KWH', 'KWT', 'LBR', 'LPA',
    'LS', 'LTR', 'MGM', 'MIN', 'MLT', 'MMK', 'MMQ', 'MMT', 'MON', 'MTK',
    'MTQ', 'MTR', 'MWH', 'NAR', 'NIU', 'NPR', 'ONZ', 'P1', 'PA', 'PF',
    'PK', 'PL', 'PR', 'PT', 'QT', 'RO', 'SA', 'SEC', 'SET', 'SMI',
    'ST', 'TN', 'TNE', 'TU', 'VLT', 'WEE', 'WTT', 'YDK', 'YRD', 'ZZ'
  ]::text[]);
$fn$;
revoke execute on function public.unece_unit_known(text) from public, anon, authenticated;

do $patch$
declare
  v_def text;
begin
  select pg_get_functiondef('public.unit_conversion_save_v1(uuid,uuid,jsonb)'::regprocedure) into v_def;
  if position('authored' in v_def) = 0 then
    v_def := pg_temp.replace_statement(v_def,
      'insert into public\.unit_conversions \(workspace_id, from_unit, to_unit, factor_num, factor_den\)\s+values \(p_workspace_id, v_from, v_to, v_num, v_den\);',
      $n$insert into public.unit_conversions (workspace_id, from_unit, to_unit, factor_num, factor_den, authored)
  values (p_workspace_id, v_from, v_to, v_num, v_den, true);$n$, 'the written conversion');
    execute v_def;
  end if;

  select pg_get_functiondef('public.workspace_unit_save_v1(uuid,uuid,jsonb)'::regprocedure) into v_def;
  if position('unece_unit_known' in v_def) = 0 then
    v_def := pg_temp.replace_statement(v_def,
      'if v_ece is not null and v_ece !~ ''\^\[A-Z0-9\]\{2,3\}\$'' then',
      $n$if v_ece is not null and (v_ece !~ '^[A-Z0-9]{2,3}$'
     or (v_ece is distinct from v_row.un_ece_code and not public.unece_unit_known(v_ece))) then$n$, 'the UN/ECE check');
    execute v_def;
  end if;
end
$patch$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(990);
