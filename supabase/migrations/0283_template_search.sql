-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0283 (#1659) -- templates are searched on the server, a page at a time.
--
-- The gallery read every readable template in full and then inspected
-- each one to answer a capability search: fine for ten templates, not for
-- hundreds. search_workspace_templates returns compact cards (no plan, no
-- configuration), a page at a time (25 by default, 100 at most) with a
-- cursor bound to its query, from the templates the caller may read
-- (workspace_template_readable, the same predicate as the list), so no
-- count, card or cursor reveals a template the caller cannot see.
--
-- Filters are typed, never parsed from text into SQL:
--   * p_query: words matched as plain substrings (no pattern syntax),
--     case- and accent-insensitively, against name, description and tags.
--   * p_required / p_excluded: feature flags by name. A required flag
--     excludes only templates that set it OFF; one that does not say is a
--     candidate, because its answer is conditional and the app's
--     inspection decides it. An excluded flag drops templates that set it
--     ON.
-- Order: name, then id, so ties are stable and pages never repeat.

create or replace function public.template_search_fold(p_text text)
returns text language sql immutable set search_path = public as $fn$
  select translate(lower(coalesce(p_text, '')),
    'àáâäãçèéêëìíîïñòóôöõùúûüýÿ', 'aaaaaceeeeiiiinooooouuuuyy');
$fn$;
revoke execute on function public.template_search_fold(text) from public, anon, authenticated;

create or replace function public.search_workspace_templates(
  p_query text default '', p_required text[] default '{}', p_excluded text[] default '{}',
  p_limit integer default 25, p_cursor text default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 25), 1), 100);
  v_words text[];
  v_key jsonb := jsonb_build_object('q', coalesce(p_query, ''), 'r', to_jsonb(coalesce(p_required, '{}')),
                                    'x', to_jsonb(coalesce(p_excluded, '{}')));
  v_cursor jsonb;
  v_after_name text;
  v_after_id uuid;
  v_rows jsonb;
  v_count integer;
  v_last jsonb;
  v_flag text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  foreach v_flag in array coalesce(p_required, '{}') || coalesce(p_excluded, '{}') loop
    if v_flag !~ '^[a-zA-Z][a-zA-Z0-9]{0,63}$' then
      raise exception using errcode = '22023', message = 'feature name';
    end if;
  end loop;
  if p_cursor is not null then
    begin
      v_cursor := convert_from(decode(p_cursor, 'base64'), 'UTF8')::jsonb;
    exception when others then
      raise exception using errcode = '22023', message = 'cursor';
    end;
    if v_cursor->'k' is distinct from v_key then
      raise exception using errcode = '22023', message = 'cursor';
    end if;
    v_after_name := v_cursor->>'n';
    v_after_id := (v_cursor->>'i')::uuid;
  end if;
  v_words := array(select w from regexp_split_to_table(public.template_search_fold(p_query), '\s+') w where w <> '');
  select coalesce(jsonb_agg(c order by c->>'sort', c->>'id'), '[]'::jsonb) into v_rows from (
    select jsonb_build_object(
             'id', t.id, 'key', t.key, 'name', t.name, 'description', t.description,
             'visibility', t.visibility, 'owner_workspace_id', t.owner_workspace_id,
             'tags', to_jsonb(t.tags), 'entities', to_jsonb(t.entities),
             'schema_version', t.schema_version, 'template_version', t.template_version,
             'regional', t.regional,
             'sort', public.template_search_fold(t.name)) as c
      from public.workspace_templates t
     where public.workspace_template_readable(t.id)
       and (select bool_and(position(w in
                    public.template_search_fold(t.name || ' ' || t.description || ' ' || array_to_string(t.tags, ' '))) > 0)
              from unnest(v_words) w) is not false
       and not exists (select 1 from unnest(coalesce(p_required, '{}')) f
                        where (t.configuration->'workspace'->'feature_flags'->>f) = 'false')
       and not exists (select 1 from unnest(coalesce(p_excluded, '{}')) f
                        where (t.configuration->'workspace'->'feature_flags'->>f) = 'true')
       and (v_after_id is null
            or (public.template_search_fold(t.name), t.id::text) > (v_after_name, v_after_id::text))
     order by public.template_search_fold(t.name), t.id::text
     limit v_limit + 1) q;
  v_count := jsonb_array_length(v_rows);
  if v_count > v_limit then
    v_rows := v_rows - v_limit;
    v_last := v_rows->(v_limit - 1);
    return jsonb_build_object('items', v_rows, 'next_cursor',
      translate(encode(convert_to(jsonb_build_object('k', v_key, 'n', v_last->>'sort', 'i', v_last->>'id')::text, 'UTF8'),
                       'base64'), E'\n', ''));
  end if;
  return jsonb_build_object('items', v_rows, 'next_cursor', null);
end;
$fn$;
revoke execute on function public.search_workspace_templates(text, text[], text[], integer, text) from public, anon;
grant execute on function public.search_workspace_templates(text, text[], text[], integer, text) to authenticated;

select public.set_deskilo_schema_version(283);
