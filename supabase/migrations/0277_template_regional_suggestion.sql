-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0277 (#1656, group 1) -- a published template says where it was made.
--
-- A template carries its source workspace's country, currency, timezone
-- and default language as a typed SUGGESTION for creating a new space
-- (`regional`, origin 'source_workspace'). It is captured when the
-- template is saved from a workspace, never from a builtin, and it is
-- never applied to an existing workspace: apply_workspace_template does
-- not read it, so a populated space keeps its currency and identity. The
-- app offers it at creation and only a person's explicit choice uses it.
--
-- Country, currency, timezone and language are not personal data; the
-- address and legal identifiers stay stripped as before (0229).

alter table public.workspace_templates
  add column if not exists regional jsonb not null default '{}'::jsonb;
alter table public.workspace_templates drop constraint if exists workspace_templates_regional_shape;
alter table public.workspace_templates add constraint workspace_templates_regional_shape check (
  jsonb_typeof(regional) = 'object'
  and (not regional ? 'country_code' or regional->>'country_code' ~ '^[A-Z]{2}$')
  and (not regional ? 'currency_code' or regional->>'currency_code' ~ '^[A-Z]{3}$')
  and (not regional ? 'timezone' or char_length(regional->>'timezone') between 1 and 64)
  and (not regional ? 'locale' or regional->>'locale' ~ '^[a-z]{2}$'));

create or replace function public.template_regional_capture()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if new.owner_workspace_id is null then
    return new;
  end if;
  if tg_op = 'INSERT' or new.configuration is distinct from old.configuration
     or new.floor_plan is distinct from old.floor_plan then
    select jsonb_strip_nulls(jsonb_build_object(
             'country_code', case when upper(w.country_code) ~ '^[A-Z]{2}$' then upper(w.country_code) end,
             'currency_code', case when upper(w.currency_code) ~ '^[A-Z]{3}$' then upper(w.currency_code) end,
             'timezone', nullif(w.timezone, ''),
             'locale', case when lower(w.default_locale) ~ '^[a-z]{2}$' then lower(w.default_locale) end))
      into new.regional
      from public.workspaces w where w.id = new.owner_workspace_id;
    if new.regional is null or new.regional = '{}'::jsonb then
      new.regional := '{}'::jsonb;
    else
      new.regional := new.regional || jsonb_build_object('origin', 'source_workspace');
    end if;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.template_regional_capture() from public, anon, authenticated;

drop trigger if exists template_regional_capture on public.workspace_templates;
create trigger template_regional_capture
  before insert or update on public.workspace_templates
  for each row execute function public.template_regional_capture();

select public.set_deskilo_schema_version(277);
