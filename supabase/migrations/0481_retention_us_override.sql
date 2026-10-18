-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0481 (#2571) -- a US space says how many years its state asks for.
--
--   retention.us_years   0..30 years, workspace scope, default 0 = "the
--       retention rule applies". When a US space sets it, every class of record
--       is kept that many years from the document date. Never legal advice:
--       the rule rows stay unconfirmed until a person with the authority
--       confirms them, and the owner confirms the period of their state.
--
-- retention_rule_for(workspace, class) is the rule the space is under: the
-- row in force, with the years replaced for a US space that set the override.
-- retention_rule, retention_until and the erasure preview read it.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('retention.us_years', 'int', '0'::jsonb, 0, 30, 'years', 'vat', array['workspace'], 'manageBilling', null, true, null, 'retention_rule_for (0481)', 'Years a US space keeps its records when its state asks for more or less than the federal default of the retention rule. 0 means the rule applies. Never legal advice: confirm the period of your state.')
on conflict (key) do nothing;
-- END GENERATED SEED

create or replace function public.retention_rule_for(p_workspace_id uuid, p_class text)
returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_country text;
  v_rule jsonb;
  v_years int;
begin
  select w.country_code into v_country from public.workspaces w where w.id = p_workspace_id;
  v_rule := public.retention_rule_of(v_country, p_class);
  if v_rule is null then return null; end if;
  if upper(btrim(coalesce(v_country, ''))) = 'US' then
    v_years := coalesce((public.setting_value(p_workspace_id, 'retention.us_years') #>> '{}')::int, 0);
    if v_years > 0 then
      v_rule := v_rule || jsonb_build_object('years', v_years, 'from', 'document_date', 'source',
        'the space''s own setting retention.us_years');
    end if;
  end if;
  return v_rule;
end;
$fn$;
revoke execute on function public.retention_rule_for(uuid, text) from public, anon, authenticated;

create or replace function public.retention_rule(p_workspace_id uuid, p_class text)
returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me public.members := public.my_active_member(p_workspace_id);
begin
  return public.retention_rule_for(p_workspace_id, p_class);
end;
$fn$;
revoke execute on function public.retention_rule(uuid, text) from public, anon;
grant execute on function public.retention_rule(uuid, text) to authenticated;

create or replace function public.retention_until(p_workspace_id uuid, p_class text, p_document_date date)
returns date
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me public.members := public.my_active_member(p_workspace_id);
  v_rule jsonb;
  v_month int := 1;
  v_day int := 1;
  v_start date;
  v_base date;
begin
  if p_document_date is null then return null; end if;
  v_rule := public.retention_rule_for(p_workspace_id, p_class);
  if v_rule is null then return null; end if;
  if v_rule ->> 'from' = 'document_date' then
    v_base := p_document_date;
  else
    select b.fiscal_year_start_month, b.fiscal_year_start_day into v_month, v_day
      from public.book_profiles b
     where b.workspace_id = p_workspace_id and b.effective_from <= p_document_date
     order by b.effective_from desc limit 1;
    v_month := coalesce(v_month, 1);
    v_start := make_date(extract(year from p_document_date)::int, v_month, 1);
    v_start := least(v_start + (coalesce(v_day, 1) - 1), (v_start + interval '1 month')::date - 1);
    if v_start > p_document_date then v_start := v_start - interval '1 year'; end if;
    v_base := (v_start + interval '1 year')::date - 1;
  end if;
  return (v_base + make_interval(years => (v_rule ->> 'years')::int))::date;
end;
$fn$;
revoke execute on function public.retention_until(uuid, text, date) from public, anon;
grant execute on function public.retention_until(uuid, text, date) to authenticated;

-- The erasure preview reads the rule the space is under, not the bare row.
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text language plpgsql as $f$
begin
  if position(p_old in p_def) = 0 then return null; end if;
  return replace(p_def, p_old, p_new);
end
$f$;

do $migration$
declare
  v_def text;
  v_class text;
begin
  select pg_get_functiondef('public.preview_my_erasure(uuid)'::regprocedure) into v_def;
  foreach v_class in array array['invoice', 'books'] loop
    v_def := pg_temp.anchor_replace(v_def,
      format('public.retention_rule_of(v_country, %L)', v_class),
      format('public.retention_rule_for(p_workspace_id, %L)', v_class));
    if v_def is null then raise exception '0481: preview_my_erasure anchor missing for %', v_class; end if;
  end loop;
  execute v_def;
end
$migration$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public, anon;

select public.set_deskilo_schema_version(481);
