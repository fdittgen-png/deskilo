-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0278 (#1656, group 2) -- a template's floor-plan prices travel, in their
-- currency, and land only where that currency is the target's.
--
-- 0229 stripped level, office and desk prices from the published plan:
-- the numbers are the source's commercial choice, and nothing said which
-- currency they are in. They now travel BESIDE the stripped plan
-- (`plan_prices`: the source currency and a tree of prices keyed by the
-- same identity merge_floor_plan uses: level name, then office and desk
-- name, or position when unnamed). Applying a template re-injects them
-- only when the target workspace's currency equals the recorded one; any
-- other currency leaves every target price untouched and says so
-- ('prices': 'currency_mismatch'), because relabelling numbers as another
-- currency would invent a tariff. A template saved before 0278 carries no
-- prices and says 'none'.

alter table public.workspace_templates
  add column if not exists plan_prices jsonb not null default '{}'::jsonb;
alter table public.workspace_templates drop constraint if exists workspace_templates_plan_prices_shape;
alter table public.workspace_templates add constraint workspace_templates_plan_prices_shape check (
  jsonb_typeof(plan_prices) = 'object'
  and (plan_prices = '{}'::jsonb
       or (plan_prices->>'currency' ~ '^[A-Z]{3}$' and jsonb_typeof(plan_prices->'levels') = 'array')));

-- The prices of an exported plan, by identity; zero prices are left out.
create or replace function public.template_plan_price_tree(p_tree jsonb)
returns jsonb language sql immutable set search_path = public as $fn$
  select coalesce(jsonb_agg(l order by ord), '[]'::jsonb) from (
    select lo.ord, jsonb_strip_nulls(jsonb_build_object(
             'name', lv->>'name',
             'price_cents', nullif(coalesce((lv->>'price_cents')::int, 0), 0),
             'offices', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                           'name', o->>'name', 'x', o->'x', 'y', o->'y',
                           'price_cents', nullif(coalesce((o->>'price_cents')::int, 0), 0),
                           'desks', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                                       'name', d->>'name', 'x', d->'x', 'y', d->'y',
                                       'price_cents', nullif(coalesce((d->>'price_cents')::int, 0), 0)))), '[]'::jsonb)
                                       from jsonb_array_elements(coalesce(o->'desks', '[]'::jsonb)) d)))), '[]'::jsonb)
                         from jsonb_array_elements(coalesce(lv->'offices', '[]'::jsonb)) o))) as l
      from jsonb_array_elements(case when jsonb_typeof(p_tree) = 'array' then p_tree else '[]'::jsonb end)
           with ordinality as lo(lv, ord)) q;
$fn$;
revoke execute on function public.template_plan_price_tree(jsonb) from public, anon, authenticated;

-- merge_floor_plan's identity: a name when there is one, else the position.
create or replace function public.template_plan_same(p_a jsonb, p_b jsonb)
returns boolean language sql immutable set search_path = public as $fn$
  select case when coalesce(p_a->>'name', '') <> '' then p_a->>'name' = coalesce(p_b->>'name', '')
              else coalesce(p_b->>'name', '') = '' and p_a->'x' = p_b->'x' and p_a->'y' = p_b->'y' end;
$fn$;
revoke execute on function public.template_plan_same(jsonb, jsonb) from public, anon, authenticated;

-- The stripped plan with its prices put back, when the currencies match.
-- An ambiguous identity (two siblings answering to it) gets no price.
create or replace function public.template_priced_plan(
  p_tpl public.workspace_templates, p_workspace_id uuid, p_tree jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_prices jsonb := p_tpl.plan_prices;
  v_out jsonb := '[]'::jsonb;
  v_l jsonb; v_o jsonb; v_d jsonb; v_pl jsonb; v_po jsonb; v_pd jsonb;
  v_offices jsonb; v_desks jsonb;
begin
  if p_tree is null or jsonb_typeof(p_tree) <> 'array' or v_prices = '{}'::jsonb
     or v_prices->>'currency' is distinct from
        (select upper(currency_code) from public.workspaces where id = p_workspace_id) then
    return p_tree;
  end if;
  for v_l in select value from jsonb_array_elements(p_tree) loop
    select value into v_pl from jsonb_array_elements(v_prices->'levels') p
     where p->>'name' = v_l->>'name'
       and (select count(*) from jsonb_array_elements(v_prices->'levels') q where q->>'name' = v_l->>'name') = 1;
    v_offices := '[]'::jsonb;
    for v_o in select value from jsonb_array_elements(coalesce(v_l->'offices', '[]'::jsonb)) loop
      v_po := null;
      if v_pl is not null then
        select value into v_po from jsonb_array_elements(coalesce(v_pl->'offices', '[]'::jsonb)) p
         where public.template_plan_same(v_o, p)
           and (select count(*) from jsonb_array_elements(v_pl->'offices') q where public.template_plan_same(v_o, q)) = 1;
      end if;
      v_desks := '[]'::jsonb;
      for v_d in select value from jsonb_array_elements(coalesce(v_o->'desks', '[]'::jsonb)) loop
        v_pd := null;
        if v_po is not null then
          select value into v_pd from jsonb_array_elements(coalesce(v_po->'desks', '[]'::jsonb)) p
           where public.template_plan_same(v_d, p)
             and (select count(*) from jsonb_array_elements(v_po->'desks') q where public.template_plan_same(v_d, q)) = 1;
        end if;
        v_desks := v_desks || jsonb_build_array(case when v_pd ? 'price_cents'
          then v_d || jsonb_build_object('price_cents', v_pd->'price_cents') else v_d end);
      end loop;
      v_o := (v_o - 'desks') || jsonb_build_object('desks', v_desks);
      v_offices := v_offices || jsonb_build_array(case when v_po ? 'price_cents'
        then v_o || jsonb_build_object('price_cents', v_po->'price_cents') else v_o end);
    end loop;
    v_l := (v_l - 'offices') || jsonb_build_object('offices', v_offices);
    v_out := v_out || jsonb_build_array(case when v_pl ? 'price_cents'
      then v_l || jsonb_build_object('price_cents', v_pl->'price_cents') else v_l end);
  end loop;
  return v_out;
end;
$fn$;
revoke execute on function public.template_priced_plan(public.workspace_templates, uuid, jsonb) from public, anon, authenticated;

-- What happened to the prices, for the apply result.
create or replace function public.template_price_outcome(p_tpl public.workspace_templates, p_workspace_id uuid)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object('prices', case
    when p_tpl.plan_prices = '{}'::jsonb then 'none'
    when p_tpl.plan_prices->>'currency' = (select upper(currency_code) from public.workspaces where id = p_workspace_id)
      then 'applied'
    else 'currency_mismatch' end);
$fn$;
revoke execute on function public.template_price_outcome(public.workspace_templates, uuid) from public, anon, authenticated;

-- Capture: when a template is saved from a workspace, its plan's prices
-- come from that workspace's own plan, in its currency.
create or replace function public.template_regional_capture()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_currency text;
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
             'locale', case when lower(w.default_locale) ~ '^[a-z]{2}$' then lower(w.default_locale) end)),
           case when upper(w.currency_code) ~ '^[A-Z]{3}$' then upper(w.currency_code) end
      into new.regional, v_currency
      from public.workspaces w where w.id = new.owner_workspace_id;
    if new.regional is null or new.regional = '{}'::jsonb then
      new.regional := '{}'::jsonb;
    else
      new.regional := new.regional || jsonb_build_object('origin', 'source_workspace');
    end if;
    new.plan_prices := '{}'::jsonb;
    if v_currency is not null and 'floor_plan' = any (new.entities) then
      new.plan_prices := jsonb_build_object('currency', v_currency, 'levels',
        public.template_plan_price_tree(public.export_floor_plan(new.owner_workspace_id)));
    end if;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.template_regional_capture() from public, anon, authenticated;

-- Apply puts the prices back, and says what it did with them.
do $migration$
declare
  v_def text := pg_get_functiondef('public.apply_workspace_template(uuid,uuid,text[])'::regprocedure);
  v_old text := $a$public.merge_floor_plan(p_workspace_id, v_snapshot->'tables'->'floor_plan')$a$;
begin
  if position('template_priced_plan' in v_def) > 0 then
    raise notice 'apply already prices the plan';
    return;
  end if;
  if position(v_old in v_def) = 0 then
    raise exception 'apply_workspace_template no longer has the shape 0278 patches';
  end if;
  execute replace(v_def, v_old,
    $a$public.merge_floor_plan(p_workspace_id,
        public.template_priced_plan(v_tpl, p_workspace_id, v_snapshot->'tables'->'floor_plan'))
      || public.template_price_outcome(v_tpl, p_workspace_id)$a$);
end
$migration$;

-- The registry (#1655) says what the prices now do.
do $registry$
declare
  v_def text := pg_get_functiondef('public.template_field_registry()'::regprocedure);
  v_old text := $a$"type":"cents","portability":"never","absent":"inherit","key":"name","reason":"stripped by strip_template_plan"$a$;
  v_new text := $a$"type":"cents","portability":"literal","absent":"inherit","key":"name","reason":"travels beside the stripped plan in its currency (0278); applied only where the target's currency is the same"$a$;
begin
  if position(v_new in v_def) > 0 then
    return;
  end if;
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 3 then
    raise exception 'template_field_registry no longer has the three plan-price entries 0278 reclassifies';
  end if;
  execute replace(v_def, v_old, v_new);
end
$registry$;

select public.set_deskilo_schema_version(278);
