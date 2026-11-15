-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one function restated; anchored patches; comments)
--
-- #4042 -- public.plans is retired. A business's tariffs are its fee bands;
-- plans have no screen and no writer. Nothing here deletes a row or drops a
-- column: the table stays, read by what still names it, until the owner's
-- CLI drops it after production has been checked for rows that use it.
--
-- * Plans no longer travel: they leave the tariffs entity, the
--   configuration export and the business's records workbook, and a
--   configuration that still holds them applies everything else.
-- * A house created abroad carries no plan and fences no plan amount.
-- * A business is priced by its fee bands (or its subscription levels).
-- * A rented room no longer opens to a plan: a plan the room's audience or
--   fees did not name already is refused (DKP02); the ones it names keep
--   working until they are removed.
-- * members.plan_id stays, read by nothing, until the drop.

comment on table public.plans is
  '#4042 -- retired: tariffs are fee bands; no screen writes a plan and none travels. Kept until the owner''s CLI drops it, after production has no room-rental audience or fee row with a plan and no member with plan_id.';
comment on column public.members.plan_id is
  '#4042 -- retired with public.plans: read by nothing; kept until the plans table is dropped.';

-- ── the house command's fenced amounts, without plans ───────────────────
create or replace function public.organisation_house_fenced_amounts()
returns jsonb language sql immutable set search_path = public as $fn$
  select '{"services": ["price_cents"],
           "packages": ["price_cents"],
           "validation_policies": ["min_amount_cents"],
           "closure_days": []}'::jsonb
$fn$;
revoke execute on function public.organisation_house_fenced_amounts() from public, anon;
grant execute on function public.organisation_house_fenced_amounts() to authenticated;

do $migration$
declare
  v_def text;
  v_fn text;
  v_old text;
  v_new text;
begin
  for v_fn, v_old, v_new in select * from (values
    -- tariffs are fee bands
    ('public.deployable_entities()',
     $r$'tables', '["fee_bands","plans"]'::jsonb$r$,
     $r$'tables', '["fee_bands"]'::jsonb$r$),
    -- a configuration that still holds plans applies everything else
    ('public.configuration_source_fence(uuid,jsonb)',
     $r$  v_ws := v_ws - 'currency_code' - 'country_code';$r$,
     $r$  -- #4042: plans are retired and no configuration brings them
  v_t := v_t - 'plans';
  v_ws := v_ws - 'currency_code' - 'country_code';$r$),
    -- the export no longer holds them
    ('public.export_workspace_configuration(uuid)',
     $r$      'plans', coalesce((select jsonb_agg(jsonb_build_object(
          'name', p.name, 'base_fee_cents', p.base_fee_cents, 'included_half_days', p.included_half_days,
          'overage_fee_cents', p.overage_fee_cents, 'active', p.active)
          order by p.name) from public.plans p where p.workspace_id = p_workspace_id), '[]'::jsonb),
$r$, ''),
    ('public.export_workspace_records(uuid)',
     $r$'sites', 'plans', 'fee_bands',$r$, $r$'sites', 'fee_bands',$r$),
    -- a business is priced by its fee bands
    ('public.workspace_readiness(uuid)',
     $r$  v_pricing := exists (select 1 from public.plans where workspace_id = p_workspace_id)
            or exists (select 1 from public.fee_bands$r$,
     $r$  v_pricing := exists (select 1 from public.fee_bands$r$),
    -- a house abroad carries no plan
    ('public.create_organisation_house_once(uuid,text,text,text,text,text,uuid)',
     $r$      if v_table in ('plans', 'services', 'packages') then$r$,
     $r$      if v_table in ('services', 'packages') then$r$),
    ('public.create_organisation_house_once(uuid,text,text,text,text,text,uuid)',
     $r$    'plans', jsonb_array_length(v_tables->'plans'),
$r$, ''),
    -- a rented room opens to no new plan
    ('public.set_room_rental_audience_v1(uuid,uuid,jsonb)',
     $r$  delete from public.room_rental_audience where rental_id = r.id;$r$,
     $r$  -- #4042: plans are retired; a plan the audience named already stays
  if exists (select 1 from jsonb_array_elements(coalesce(p_audience, '[]'::jsonb)) asked(entry)
              where (asked.entry->>'plan_id') is not null
                and not exists (select 1 from public.room_rental_audience a
                                 where a.rental_id = r.id and a.plan_id = (asked.entry->>'plan_id')::uuid)) then
    raise exception 'a room no longer opens to a plan' using errcode = 'DKP02';
  end if;
  delete from public.room_rental_audience where rental_id = r.id;$r$),
    ('public.set_room_rental_fees_v1(uuid,uuid,jsonb)',
     $r$  delete from public.room_rental_fees where rental_id = r.id;$r$,
     $r$  -- #4042: plans are retired; a plan the fees named already stays
  if exists (select 1 from jsonb_array_elements(coalesce(p_fees, '[]'::jsonb)) asked(entry)
              where (asked.entry->>'plan_id') is not null
                and not exists (select 1 from public.room_rental_fees f
                                 where f.rental_id = r.id and f.plan_id = (asked.entry->>'plan_id')::uuid)) then
    raise exception 'a room no longer opens to a plan' using errcode = 'DKP02';
  end if;
  delete from public.room_rental_fees where rental_id = r.id;$r$)) v(f, o, n)
  loop
    v_def := pg_get_functiondef(v_fn::regprocedure);
    if position(v_new in v_def) > 0 and v_new <> '' then continue; end if;
    if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
      raise exception '% no longer has the shape 0785 retires plans from: %', v_fn, left(v_old, 60) using errcode = 'P0001';
    end if;
    execute replace(v_def, v_old, v_new);
  end loop;
end
$migration$;

select public.set_deskilo_schema_version(785);
