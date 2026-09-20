-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0241 (#1451) — the Workspace settings Save is one transaction.
--
-- One visible Save used to send eight independent requests: locale,
-- WhatsApp group, address, per-language invitation templates, the legacy
-- template, the workspace language, desk transparency and the new-member
-- defaults. A failure on the fifth left the first four committed, the
-- screen said "something went wrong", and nothing told the owner which
-- half had been saved.
--
-- `save_workspace_settings(workspace, expected_modified, settings)`:
--
--   * SECURITY INVOKER — `workspaces_update` RLS still decides who writes
--     the row (owners and active co-owners), and `set_billing_rule` keeps
--     its own permission check for the keyed rule;
--   * locks the row and compares its `modified_datetime` with the one the
--     form was opened on. A different stamp is a CONFLICT (SQLSTATE DK409)
--     — unless the row already holds exactly this payload, which is a
--     retried Save whose first answer was lost: that answers `unchanged`
--     and writes nothing, so a retry never reports a different result;
--   * writes the seven columns and the keyed `new_member_defaults` rule in
--     one statement sequence: any refusal (a column check, a billing-rule
--     validation, a permission) rolls back every field;
--   * keys absent from `settings` keep their stored value; every other
--     billing rule survives (`set_billing_rule` merges, #1089);
--   * returns `{status: saved|unchanged, workspace: <row>}` — the
--     authoritative state the client re-reads from.

create or replace function public.save_workspace_settings(
  p_workspace_id uuid,
  p_expected_modified timestamptz,
  p_settings jsonb
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_row public.workspaces;
  v_templates jsonb;
  v_same boolean;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if jsonb_typeof(p_settings) is distinct from 'object' then
    raise exception 'workspace settings are an object';
  end if;
  if p_settings ? 'invitation_templates' then
    select coalesce(jsonb_object_agg(e.key, btrim(e.value)), '{}'::jsonb)
      into v_templates
      from jsonb_each_text(coalesce(p_settings->'invitation_templates', '{}'::jsonb)) e
     where btrim(e.value) <> '';
  end if;

  select * into v_row from public.workspaces where id = p_workspace_id for update;
  if v_row.id is null then
    raise exception 'only the owner and co-owners change the workspace settings';
  end if;

  if p_expected_modified is not null
     and v_row.modified_datetime is distinct from p_expected_modified then
    v_same :=
          v_row.country_code = coalesce(upper(p_settings->>'country_code'), v_row.country_code)
      and v_row.currency_code = coalesce(upper(p_settings->>'currency_code'), v_row.currency_code)
      and v_row.timezone = coalesce(p_settings->>'timezone', v_row.timezone)
      and coalesce(v_row.whatsapp_group, '') = coalesce(btrim(p_settings->>'whatsapp_group'), v_row.whatsapp_group, '')
      and coalesce(v_row.address, '') = coalesce(btrim(p_settings->>'address'), v_row.address, '')
      and coalesce(v_row.default_locale, '') = coalesce(btrim(p_settings->>'default_locale'), v_row.default_locale, '')
      and v_row.desk_opacity = coalesce((p_settings->>'desk_opacity')::int, v_row.desk_opacity)
      and (v_templates is null or coalesce(v_row.invitation_templates, '{}'::jsonb) = v_templates)
      and (not p_settings ? 'invitation_templates' or coalesce(v_row.invitation_template, '') = '')
      and (not p_settings ? 'new_member_defaults'
           or coalesce(v_row.billing_rules, '{}'::jsonb)->'new_member_defaults' = p_settings->'new_member_defaults');
    if v_same then
      return jsonb_build_object('status', 'unchanged', 'workspace', to_jsonb(v_row));
    end if;
    raise exception using
      errcode = 'DK409',
      message = 'the workspace settings changed since they were opened';
  end if;

  update public.workspaces set
    country_code = coalesce(upper(p_settings->>'country_code'), country_code),
    currency_code = coalesce(upper(p_settings->>'currency_code'), currency_code),
    timezone = coalesce(p_settings->>'timezone', timezone),
    whatsapp_group = coalesce(btrim(p_settings->>'whatsapp_group'), whatsapp_group),
    address = coalesce(btrim(p_settings->>'address'), address),
    default_locale = coalesce(btrim(p_settings->>'default_locale'), default_locale),
    desk_opacity = coalesce((p_settings->>'desk_opacity')::int, desk_opacity),
    invitation_templates = coalesce(v_templates, invitation_templates),
    -- #486 — the per-language templates replace the legacy single one.
    invitation_template = case when v_templates is null then invitation_template else '' end
   where id = p_workspace_id
  returning * into v_row;
  if v_row.id is null then
    raise exception 'only the owner and co-owners change the workspace settings';
  end if;

  if p_settings ? 'new_member_defaults' then
    perform public.set_billing_rule(p_workspace_id, 'new_member_defaults',
      p_settings->'new_member_defaults');
    select * into v_row from public.workspaces where id = p_workspace_id;
  end if;

  return jsonb_build_object('status', 'saved', 'workspace', to_jsonb(v_row));
end $$;

revoke execute on function public.save_workspace_settings(uuid, timestamptz, jsonb) from public, anon;
grant execute on function public.save_workspace_settings(uuid, timestamptz, jsonb) to authenticated;

select public.set_deskilo_schema_version(241);
