-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #3278 (reviewer finding on #3296): 0669 moved the birthday off
-- public.profiles and patched the workspace export_my_data, but the account
-- export export_my_personal_data_v1 (0566, Me › personal export) still read
-- to_jsonb(profiles) only, so a person's account export lost their birthday,
-- with or without a workspace. Its profile entry now carries it from
-- profile_birthdays, appended with || like 0616's presence (#3123).

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.export_my_personal_data_v1()'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$jsonb_build_object('presence', (select to_jsonb(pr) from public.presence pr where pr.user_id = v_me))$a$,
    $a$jsonb_build_object('presence', (select to_jsonb(pr) from public.presence pr where pr.user_id = v_me))
      || jsonb_build_object('birthday', (select b.birthday from public.profile_birthdays b where b.user_id = v_me))$a$);
  if v_def is null then raise exception '0670: export_my_personal_data_v1 presence anchor missing'; end if;
  execute v_def;
end
$migration$;

select public.set_deskilo_schema_version(670);
