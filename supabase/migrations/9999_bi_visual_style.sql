-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 9999 (#2580) -- a report visual may carry how it is presented.
--
--   Style. bi_report_valid accepts an optional `style` object on a visual:
--       a visible title (1 to 80 characters) and description (1 to 200),
--       plain text on one line; legend, value labels and the source note
--       (booleans); a permitted palette (standard | contrast | mono) and the
--       axis of a line (zero | fit). Nothing else: no colour value, HTML,
--       script, formula, figure or link. A style never changes what a visual
--       reads, so no read path changes.
--   How. An anchored patch of bi_report_valid's visual check (two anchors,
--       each asserted to occur exactly once), so it holds whichever earlier
--       restatement of the function is live (0588's, or a later one that
--       keeps the visual check as written).

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

do $patch$
declare
  v_def text := pg_get_functiondef('public.bi_report_valid(jsonb)'::regprocedure);
  v_old text[] := array[
    $a$'drill', 'text'))$a$,
    $a$and jsonb_typeof(v_vis -> 'layout') = 'object'$a$];
  v_new text[] := array[
    $a$'drill', 'text', 'style'))$a$,
    $a$-- presentation only (#2580): a heading, a description, the legend,
           -- value labels, a permitted palette, a line's axis, the source note
           and (coalesce(v_vis -> 'style', 'null'::jsonb) = 'null'::jsonb or (
                  jsonb_typeof(v_vis -> 'style') = 'object'
                  and not exists (select 1 from jsonb_object_keys(v_vis -> 'style') k
                                   where k not in ('title', 'description', 'legend', 'labels',
                                                   'palette', 'axis', 'note'))
                  and coalesce(jsonb_typeof(v_vis -> 'style' -> 'title'), 'string') = 'string'
                  and char_length(coalesce(v_vis -> 'style' ->> 'title', 'x')) between 1 and 80
                  and coalesce(v_vis -> 'style' ->> 'title', '') !~ '[\x01-\x1f\x7f]'
                  and coalesce(jsonb_typeof(v_vis -> 'style' -> 'description'), 'string') = 'string'
                  and char_length(coalesce(v_vis -> 'style' ->> 'description', 'x')) between 1 and 200
                  and coalesce(v_vis -> 'style' ->> 'description', '') !~ '[\x01-\x1f\x7f]'
                  and coalesce(jsonb_typeof(v_vis -> 'style' -> 'legend'), 'boolean') = 'boolean'
                  and coalesce(jsonb_typeof(v_vis -> 'style' -> 'labels'), 'boolean') = 'boolean'
                  and coalesce(jsonb_typeof(v_vis -> 'style' -> 'note'), 'boolean') = 'boolean'
                  and coalesce(v_vis -> 'style' ->> 'palette', 'standard') in ('standard', 'contrast', 'mono')
                  and coalesce(v_vis -> 'style' ->> 'axis', 'zero') in ('zero', 'fit')))
           and jsonb_typeof(v_vis -> 'layout') = 'object'$a$];
  v_next text;
  i int;
begin
  for i in 1 .. cardinality(v_old) loop
    if position(v_old[i] in v_def) = 0
       or (length(v_def) - length(replace(v_def, v_old[i], ''))) <> length(v_old[i]) then
      raise exception '9999: anchor % missing or repeated in bi_report_valid', i;
    end if;
    v_next := pg_temp.anchor_replace(v_def, v_old[i], v_new[i]);
    if v_next is null or v_next = v_def then
      raise exception '9999: anchor % not replaced in bi_report_valid', i;
    end if;
    v_def := v_next;
  end loop;
  execute v_def;
end
$patch$;
revoke execute on function public.bi_report_valid(jsonb) from public, anon;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(9999);
