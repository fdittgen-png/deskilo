-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0281 (#1657, validation) -- a validation policy keeps its meaning when
-- it travels.
--
-- Two gaps. `min_amount_cents` (the threshold below which a request needs
-- no validation) was not exported, so a copied policy validated every
-- amount. And a policy restricted to NAMED validators (eligible_admin_ids)
-- carried nothing of that restriction: the ids are the source's people
-- and never travel, and the imported row then meant "any admin" -- a
-- restriction silently widened. A mirror deployment even deleted the
-- target's own restriction and re-created it open.
--
-- Now the threshold travels, and a named-validator policy travels as a
-- flag (`named_validators`, no identities). Import never writes such a
-- policy: the target keeps what it has (a mirror keeps it too), the apply
-- result names the event types left for local choice
-- (`validation_blocked`), and the template's local needs list them. The
-- owner chooses the validators in the existing validation settings, the
-- native writer; nothing here picks anyone, lowers a quorum or opens a
-- policy to everyone.

do $migration$
declare
  v_exp text := pg_get_functiondef('public.export_workspace_configuration(uuid)'::regprocedure);
  v_imp text := pg_get_functiondef('public.import_workspace_configuration(uuid,jsonb,text)'::regprocedure);
  v_apply text := pg_get_functiondef('public.apply_workspace_template(uuid,uuid,text[])'::regprocedure);
begin
  if position('named_validators' in v_exp) = 0 then
    if position($a$'sequential', v.sequential)$a$ in v_exp) = 0 then
      raise exception 'export_workspace_configuration no longer has the policy shape 0281 extends';
    end if;
    execute replace(v_exp, $a$'sequential', v.sequential)$a$,
      $a$'sequential', v.sequential, 'min_amount_cents', v.min_amount_cents,
          'named_validators', cardinality(coalesce(v.eligible_admin_ids, '{}')) > 0)$a$);
  end if;

  if position('named_validators' in v_imp) = 0 then
    if position($a$if p_mode = 'mirror' then delete from public.validation_policies where workspace_id = p_workspace_id; end if;$a$ in v_imp) = 0
       or position($a$owner_may_self_validate, sequential)$a$ in v_imp) = 0
       or position($a$coalesce((e.value->>'sequential')::boolean, false)
      from jsonb_array_elements(v_t->'validation_policies') e$a$ in v_imp) = 0
       or position($a$sequential = excluded.sequential;$a$ in v_imp) = 0 then
      raise exception 'import_workspace_configuration no longer has the policy shape 0281 extends';
    end if;
    v_imp := replace(v_imp,
      $a$if p_mode = 'mirror' then delete from public.validation_policies where workspace_id = p_workspace_id; end if;$a$,
      $a$if p_mode = 'mirror' then delete from public.validation_policies where workspace_id = p_workspace_id
      and event_type not in (select e.value->>'event_type' from jsonb_array_elements(v_t->'validation_policies') e
                              where coalesce((e.value->>'named_validators')::boolean, false)); end if;$a$);
    v_imp := replace(v_imp, $a$owner_may_self_validate, sequential)$a$,
      $a$owner_may_self_validate, sequential, min_amount_cents)$a$);
    v_imp := replace(v_imp, $a$coalesce((e.value->>'sequential')::boolean, false)
      from jsonb_array_elements(v_t->'validation_policies') e$a$,
      $a$coalesce((e.value->>'sequential')::boolean, false), coalesce((e.value->>'min_amount_cents')::int, 0)
      from jsonb_array_elements(v_t->'validation_policies') e
     where not coalesce((e.value->>'named_validators')::boolean, false)$a$);
    -- An existing row takes a threshold only when the template carries
    -- one: a template from before 0281 says nothing, and nothing changes.
    v_imp := replace(v_imp, $a$sequential = excluded.sequential;$a$,
      $a$sequential = excluded.sequential;
    update public.validation_policies v set min_amount_cents = (e.value->>'min_amount_cents')::int
      from jsonb_array_elements(v_t->'validation_policies') e
     where v.workspace_id = p_workspace_id and v.event_type = e.value->>'event_type'
       and e.value ? 'min_amount_cents' and not coalesce((e.value->>'named_validators')::boolean, false);$a$);
    execute v_imp;
  end if;

  if position('validation_blocked' in v_apply) = 0 then
    if position($a$'compatibility', v_compat->>'status',$a$ in v_apply) = 0 then
      raise exception 'apply_workspace_template no longer has the result shape 0281 extends';
    end if;
    execute replace(v_apply, $a$'compatibility', v_compat->>'status',$a$,
      $a$'compatibility', v_compat->>'status',
                               'validation_blocked', public.template_blocked_validations(v_snapshot->'tables', v_selected),$a$);
  end if;
end
$migration$;

-- The event types whose named validators are left for local choice.
create or replace function public.template_blocked_validations(p_tables jsonb, p_selected text[])
returns jsonb language sql immutable set search_path = public as $fn$
  select case when not ('validation_rules' = any (coalesce(p_selected, '{}'))) then '[]'::jsonb
    else coalesce((select jsonb_agg(e->>'event_type' order by e->>'event_type')
                     from jsonb_array_elements(coalesce(p_tables->'validation_policies', '[]'::jsonb)) e
                    where coalesce((e->>'named_validators')::boolean, false)), '[]'::jsonb) end;
$fn$;
revoke execute on function public.template_blocked_validations(jsonb, text[]) from public, anon, authenticated;

-- Local needs: a named-validator policy is a slot per event type.
create or replace function public.template_local_needs(p_template_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_tpl public.workspace_templates;
  v_flags jsonb;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.workspace_template_readable(p_template_id) then
    raise exception 'unknown template';
  end if;
  select * into v_tpl from public.workspace_templates where id = p_template_id;
  v_flags := coalesce(v_tpl.configuration->'workspace'->'feature_flags', '{}'::jsonb);
  return coalesce((select jsonb_agg(s order by ord)
                     from jsonb_array_elements(public.template_local_slot_catalogue()) with ordinality c(s, ord)
                    where coalesce((v_flags->>(s->>'feature'))::boolean, false)), '[]'::jsonb)
      || coalesce((select jsonb_agg(jsonb_build_object('slot', 'named_validators', 'event_type', e->>'event_type',
                                    'required', true, 'route', '/validation', 'fields',
                                    jsonb_build_array('tables.validation_policies[].eligible_admin_ids'))
                                    order by e->>'event_type')
                     from jsonb_array_elements(coalesce(v_tpl.configuration->'tables'->'validation_policies', '[]'::jsonb)) e
                    where coalesce((e->>'named_validators')::boolean, false)), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.template_local_needs(uuid) from public, anon;
grant execute on function public.template_local_needs(uuid) to authenticated;

-- The registry: the threshold travels; the flag replaces the identities.
do $registry$
declare
  v_def text := pg_get_functiondef('public.template_field_registry()'::regprocedure);
  v_old text := $a$"portability":"unsupported","absent":"inherit","key":"event_type","reason":"the export does not carry it yet (#1655)"$a$;
  v_new text := $a$"portability":"literal","absent":"inherit","key":"event_type","reason":"the threshold below which no validation is needed (0281)"$a$;
begin
  if position(v_new in v_def) > 0 then return; end if;
  if position(v_old in v_def) = 0 then
    raise exception 'template_field_registry no longer has the min_amount_cents entry 0281 reclassifies';
  end if;
  execute replace(v_def, v_old, v_new);
end
$registry$;

select public.set_deskilo_schema_version(281);
