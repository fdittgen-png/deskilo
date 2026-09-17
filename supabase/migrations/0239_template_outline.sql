-- SPDX-License-Identifier: 0BSD
-- risk: additive
--
-- 0239 (#1303 S3) — before a workspace exists, say what a template will
-- set up, and whether this server can apply it.
--
-- `preview_workspace_template` compares a template with a workspace that
-- already runs. Onboarding has no workspace yet, so its confirm step named
-- the template and nothing more: the member confirmed a scope they could
-- not see, and a template this server cannot apply was only refused after
-- they pressed Create.
--
-- `template_outline(template)` answers from the same two sources creation
-- uses — `template_compatibility(template, null)` and
-- `deployable_entities()` — so the outline and the apply cannot disagree:
--
--   { compatibility: supported | partial | not_supported,
--     reason:        text | null,
--     groups:        [{ group, entities: [key, …] }, …] }   -- registry order
--
-- Readable by whoever may read the template (`workspace_template_readable`),
-- which needs a signed-in caller; anon has no execute.

create or replace function public.template_outline(p_template_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tpl public.workspace_templates;
  v_compat jsonb;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.workspace_template_readable(p_template_id) then
    raise exception 'unknown template';
  end if;
  select * into v_tpl from public.workspace_templates where id = p_template_id;
  v_compat := public.template_compatibility(v_tpl, null);
  return jsonb_build_object(
    'compatibility', v_compat->>'status',
    'reason', v_compat->'reason',
    'groups', coalesce((
      select jsonb_agg(jsonb_build_object('group', s.grp, 'entities', s.keys) order by s.first_ord)
        from (select e.value->>'group' as grp,
                     jsonb_agg(e.value->>'key' order by e.ord) as keys,
                     min(e.ord) as first_ord
                from jsonb_array_elements(public.deployable_entities()) with ordinality e(value, ord)
               where (e.value->>'key') in (select jsonb_array_elements_text(v_compat->'selected'))
               group by e.value->>'group') s), '[]'::jsonb));
end $$;

revoke execute on function public.template_outline(uuid) from public, anon;
grant execute on function public.template_outline(uuid) to authenticated;

select public.set_deskilo_schema_version(239);
