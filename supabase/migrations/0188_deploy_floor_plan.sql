-- SPDX-License-Identifier: 0BSD
-- 0188 — #1004: the floor plan as a deployable entity.
--
-- #916 kept the plan off the transfer because a plan import wipes the
-- target, and a target with reservations must never lose a seat. A
-- deployment MERGES instead: levels by name, offices, desks and seats
-- by name or, unnamed, by position; what the source has is added or
-- updated (geometry, prices, whole-booking flags, chairs, amenities,
-- accessories by name, the site by name); what only the target has is
-- reported and kept. Physical and temporal facts — badge tags, blocks —
-- never travel. Plan images and level backgrounds travel as COPY JOBS:
-- the rows point at the target's path, and the client copies the bytes
-- (storage objects are not the database's to move).

-- ── the tree ───────────────────────────────────────────────────────
create or replace function public.export_floor_plan(p_workspace_id uuid)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select coalesce((select jsonb_agg(jsonb_build_object(
    'name', l.name, 'sort_order', l.sort_order,
    'bookable_as_whole', coalesce(l.bookable_as_whole, false), 'price_cents', coalesce(l.price_cents, 0),
    'background_path', coalesce(l.background_path, ''),
    'site', (select s.name from public.sites s where s.id = l.site_id),
    'images', coalesce((select jsonb_agg(jsonb_build_object('x', i.x, 'y', i.y, 'w', i.w, 'h', i.h, 'storage_path', i.storage_path)
                order by i.storage_path) from public.plan_images i where i.level_id = l.id), '[]'::jsonb),
    'offices', coalesce((select jsonb_agg(jsonb_build_object(
      'name', o.name, 'color', o.color, 'bookable_as_whole', o.bookable_as_whole, 'price_cents', coalesce(o.price_cents, 0),
      'x', o.x, 'y', o.y, 'w', o.w, 'h', o.h,
      'desks', coalesce((select jsonb_agg(jsonb_build_object(
        'name', d.name, 'x', d.x, 'y', d.y, 'w', d.w, 'h', d.h,
        'bookable_as_whole', coalesce(d.bookable_as_whole, false), 'price_cents', coalesce(d.price_cents, 0),
        'seats', coalesce((select jsonb_agg(jsonb_build_object(
          'name', st.name, 'x', st.x, 'y', st.y, 'orientation', st.orientation, 'chair', st.chair,
          'amenities', to_jsonb(st.amenities),
          'accessories', coalesce((select jsonb_agg(a.name order by a.name) from public.seat_accessories sa
                                    join public.accessories a on a.id = sa.accessory_id where sa.seat_id = st.id), '[]'::jsonb))
          order by st.name, st.x, st.y) from public.seats st where st.desk_id = d.id), '[]'::jsonb))
        order by d.name, d.x, d.y) from public.desks d where d.office_id = o.id), '[]'::jsonb))
      order by o.name, o.x, o.y) from public.offices o where o.level_id = l.id), '[]'::jsonb))
    order by l.sort_order, l.name) from public.levels l where l.workspace_id = p_workspace_id), '[]'::jsonb);
$fn$;

-- One row per element, keyed by its place in the tree, for the diff.
create or replace function public.floor_plan_rows(p_tree jsonb)
returns table (key text, data jsonb) language sql immutable as $fn$
  with lv as (select value as l from jsonb_array_elements(coalesce(p_tree, '[]'::jsonb))),
  ok as (select l, o.value as o, case when coalesce(o.value->>'name', '') <> '' then o.value->>'name' else 'xy:' || (o.value->>'x') || ',' || (o.value->>'y') end as okey
         from lv, jsonb_array_elements(coalesce(l->'offices', '[]'::jsonb)) o),
  dk as (select l, o, okey, d.value as d, case when coalesce(d.value->>'name', '') <> '' then d.value->>'name' else 'xy:' || (d.value->>'x') || ',' || (d.value->>'y') end as dkey
         from ok, jsonb_array_elements(coalesce(o->'desks', '[]'::jsonb)) d),
  sk as (select l, okey, dkey, s.value as s, case when coalesce(s.value->>'name', '') <> '' then s.value->>'name' else 'xy:' || (s.value->>'x') || ',' || (s.value->>'y') end as skey
         from dk, jsonb_array_elements(coalesce(d->'seats', '[]'::jsonb)) s)
  -- the background compares by file name: the prefix is each side's own
  select 'L:' || (l->>'name'), (l - 'offices' - 'images' - 'background_path') || jsonb_build_object('background', regexp_replace(coalesce(l->>'background_path', ''), '^.*/', '')) from lv
  union all
  select 'I:' || (l->>'name') || '/' || regexp_replace(i.value->>'storage_path', '^.*/', ''), i.value - 'storage_path' from lv, jsonb_array_elements(coalesce(l->'images', '[]'::jsonb)) i
  union all
  select 'O:' || (l->>'name') || '/' || okey, o - 'desks' from ok
  union all
  select 'D:' || (l->>'name') || '/' || okey || '/' || dkey, d - 'seats' from dk
  union all
  select 'S:' || (l->>'name') || '/' || okey || '/' || dkey || '/' || skey, s from sk;
$fn$;

-- A jsonb array of strings as text[] — '{}' for null or anything else.
create or replace function public.jsonb_text_array(p jsonb)
returns text[] language sql immutable as $fn$
  select coalesce(array(select jsonb_array_elements_text(case when jsonb_typeof(p) = 'array' then p else '[]'::jsonb end)), '{}');
$fn$;

-- ── the merge ──────────────────────────────────────────────────────
create or replace function public.merge_floor_plan(p_workspace_id uuid, p_tree jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_l jsonb; v_o jsonb; v_d jsonb; v_s jsonb; v_i jsonb; v_acc text;
  v_lid uuid; v_oid uuid; v_did uuid; v_sid uuid; v_aid uuid; v_site uuid;
  v_jobs jsonb := '[]'::jsonb; v_from text; v_to text; v_name text;
begin
  if p_tree is null or jsonb_typeof(p_tree) <> 'array' then return jsonb_build_object('copy_jobs', v_jobs); end if;
  for v_l in select value from jsonb_array_elements(p_tree) loop
    select id into v_site from public.sites where workspace_id = p_workspace_id and name = v_l->>'site' limit 1;
    select id into v_lid from public.levels where workspace_id = p_workspace_id and name = v_l->>'name' order by created_at limit 1;
    -- the background: the same path under this workspace's prefix
    v_from := coalesce(v_l->>'background_path', '');
    v_to := case when v_from = '' then null else regexp_replace(v_from, '^[^/]+', p_workspace_id::text) end;
    if v_lid is null then
      insert into public.levels (workspace_id, name, sort_order, bookable_as_whole, price_cents, site_id, background_path)
      values (p_workspace_id, v_l->>'name', coalesce((v_l->>'sort_order')::int, 0), coalesce((v_l->>'bookable_as_whole')::boolean, false),
              coalesce((v_l->>'price_cents')::int, 0), v_site, v_to)
      returning id into v_lid;
    else
      update public.levels set sort_order = coalesce((v_l->>'sort_order')::int, sort_order),
        bookable_as_whole = coalesce((v_l->>'bookable_as_whole')::boolean, bookable_as_whole),
        price_cents = coalesce((v_l->>'price_cents')::int, price_cents),
        site_id = coalesce(v_site, site_id),
        background_path = coalesce(v_to, background_path)
       where id = v_lid;
    end if;
    if v_to is not null and v_from <> v_to then
      v_jobs := v_jobs || jsonb_build_object('from', v_from, 'to', v_to);
    end if;
    -- images by their path under the prefix
    for v_i in select value from jsonb_array_elements(coalesce(v_l->'images', '[]'::jsonb)) loop
      v_from := v_i->>'storage_path';
      v_to := regexp_replace(v_from, '^[^/]+', p_workspace_id::text);
      if exists (select 1 from public.plan_images where level_id = v_lid and storage_path = v_to) then
        update public.plan_images set x = (v_i->>'x')::int, y = (v_i->>'y')::int, w = (v_i->>'w')::int, h = (v_i->>'h')::int
         where level_id = v_lid and storage_path = v_to;
      else
        insert into public.plan_images (workspace_id, level_id, x, y, w, h, storage_path)
        values (p_workspace_id, v_lid, (v_i->>'x')::int, (v_i->>'y')::int, (v_i->>'w')::int, (v_i->>'h')::int, v_to);
      end if;
      if v_from <> v_to then v_jobs := v_jobs || jsonb_build_object('from', v_from, 'to', v_to); end if;
    end loop;
    -- offices
    for v_o in select value from jsonb_array_elements(coalesce(v_l->'offices', '[]'::jsonb)) loop
      v_name := coalesce(v_o->>'name', '');
      select id into v_oid from public.offices where level_id = v_lid
        and (case when v_name <> '' then name = v_name else name = '' and x = (v_o->>'x')::int and y = (v_o->>'y')::int end)
        order by created_at limit 1;
      if v_oid is null then
        insert into public.offices (workspace_id, level_id, name, color, bookable_as_whole, price_cents, x, y, w, h)
        values (p_workspace_id, v_lid, v_name, coalesce((v_o->>'color')::int, 0), coalesce((v_o->>'bookable_as_whole')::boolean, false),
                coalesce((v_o->>'price_cents')::int, 0), (v_o->>'x')::int, (v_o->>'y')::int, (v_o->>'w')::int, (v_o->>'h')::int)
        returning id into v_oid;
      else
        update public.offices set color = coalesce((v_o->>'color')::int, color),
          bookable_as_whole = coalesce((v_o->>'bookable_as_whole')::boolean, bookable_as_whole),
          price_cents = coalesce((v_o->>'price_cents')::int, price_cents),
          x = (v_o->>'x')::int, y = (v_o->>'y')::int, w = (v_o->>'w')::int, h = (v_o->>'h')::int
         where id = v_oid;
      end if;
      -- desks
      for v_d in select value from jsonb_array_elements(coalesce(v_o->'desks', '[]'::jsonb)) loop
        v_name := coalesce(v_d->>'name', '');
        select id into v_did from public.desks where office_id = v_oid
          and (case when v_name <> '' then name = v_name else name = '' and x = (v_d->>'x')::int and y = (v_d->>'y')::int end)
          order by created_at limit 1;
        if v_did is null then
          insert into public.desks (workspace_id, office_id, name, x, y, w, h, bookable_as_whole, price_cents)
          values (p_workspace_id, v_oid, v_name, (v_d->>'x')::int, (v_d->>'y')::int, (v_d->>'w')::int, (v_d->>'h')::int,
                  coalesce((v_d->>'bookable_as_whole')::boolean, false), coalesce((v_d->>'price_cents')::int, 0))
          returning id into v_did;
        else
          update public.desks set x = (v_d->>'x')::int, y = (v_d->>'y')::int, w = (v_d->>'w')::int, h = (v_d->>'h')::int,
            bookable_as_whole = coalesce((v_d->>'bookable_as_whole')::boolean, bookable_as_whole),
            price_cents = coalesce((v_d->>'price_cents')::int, price_cents)
           where id = v_did;
        end if;
        -- seats
        for v_s in select value from jsonb_array_elements(coalesce(v_d->'seats', '[]'::jsonb)) loop
          v_name := coalesce(v_s->>'name', '');
          select id into v_sid from public.seats where desk_id = v_did
            and (case when v_name <> '' then name = v_name else name = '' and x = (v_s->>'x')::int and y = (v_s->>'y')::int end)
            order by created_at limit 1;
          if v_sid is null then
            insert into public.seats (workspace_id, desk_id, name, x, y, orientation, chair, amenities)
            values (p_workspace_id, v_did, v_name, (v_s->>'x')::int, (v_s->>'y')::int, coalesce(v_s->>'orientation', 'n'),
                    coalesce(v_s->>'chair', ''), public.jsonb_text_array(v_s->'amenities'))
            returning id into v_sid;
          else
            update public.seats set x = (v_s->>'x')::int, y = (v_s->>'y')::int, orientation = coalesce(v_s->>'orientation', orientation),
              chair = coalesce(v_s->>'chair', chair),
              amenities = public.jsonb_text_array(v_s->'amenities')
             where id = v_sid;
          end if;
          -- accessories by name: the source's set becomes the seat's set
          delete from public.seat_accessories where seat_id = v_sid;
          for v_acc in select jsonb_array_elements_text(coalesce(v_s->'accessories', '[]'::jsonb)) loop
            select id into v_aid from public.accessories where workspace_id = p_workspace_id and name = v_acc limit 1;
            if v_aid is not null then
              insert into public.seat_accessories (workspace_id, seat_id, accessory_id) values (p_workspace_id, v_sid, v_aid)
              on conflict do nothing;
            end if;
          end loop;
        end loop;
      end loop;
    end loop;
  end loop;
  return jsonb_build_object('copy_jobs', v_jobs);
end;
$fn$;
revoke execute on function public.merge_floor_plan(uuid, jsonb) from public, anon, authenticated;

-- ── the registry, the slice, the preview, the deploy, the rollback ──
do $patch$
declare v_def text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'deployable_entities';
  v_old := 'jsonb_build_object(''key'', ''sites'', ''kind'', ''master_data'',';
  if position(v_old in v_def) = 0 then raise exception 'registry anchor missing'; end if;
  v_def := replace(v_def, v_old,
    'jsonb_build_object(''key'', ''floor_plan'', ''kind'', ''master_data'', ''requires'', ''["accessories","sites"]''::jsonb,' || E'\n' ||
    '      ''workspace_keys'', ''[]''::jsonb, ''tables'', ''["floor_plan"]''::jsonb),' || E'\n' ||
    '    ' || v_old);
  execute v_def;

  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'export_entities';
  v_old := '  return jsonb_build_object(''entities'', to_jsonb(p_entities), ''workspace'', v_ws, ''tables'', v_t);';
  if position(v_old in v_def) = 0 then raise exception 'export_entities anchor missing'; end if;
  v_def := replace(v_def, v_old,
    '  -- #1004 — the plan is a tree of its own, not a table of the transfer.' || E'\n' ||
    '  if ''floor_plan'' = any (p_entities) then' || E'\n' ||
    '    v_t := v_t || jsonb_build_object(''floor_plan'', public.export_floor_plan(p_workspace_id));' || E'\n' ||
    '  end if;' || E'\n' || v_old);
  execute v_def;
end;
$patch$;

-- The preview learns the tree: rows by their place, extras reported.
create or replace function public.preview_deployment(p_from uuid, p_to uuid, p_entities text[])
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_src jsonb; v_dst jsonb; v_e jsonb; v_k text; v_out jsonb := '[]'::jsonb;
  v_added int; v_changed int; v_removed int; v_keys text[]; v_row jsonb; v_other jsonb; v_key text; v_r record;
begin
  if not public.may_deploy(p_from, p_to) then raise exception 'not allowed to deploy in this direction'; end if;
  perform set_config('deskilo.deploying', p_from::text || ':' || p_to::text, true);
  v_src := public.export_entities(p_from, p_entities);
  v_dst := public.export_entities(p_to, p_entities);
  for v_e in select value from jsonb_array_elements(public.deployable_entities()) loop
    if not ((v_e->>'key') = any (p_entities)) then continue; end if;
    v_added := 0; v_changed := 0; v_removed := 0; v_keys := '{}';
    for v_k in select jsonb_array_elements_text(v_e->'workspace_keys') loop
      if (v_src->'workspace'->v_k) is distinct from (v_dst->'workspace'->v_k) then
        v_changed := v_changed + 1; v_keys := v_keys || v_k;
      end if;
    end loop;
    if (v_e->>'key') = 'floor_plan' then
      for v_r in select s.key, s.data, d.data as other from public.floor_plan_rows(v_src->'tables'->'floor_plan') s
                 left join public.floor_plan_rows(v_dst->'tables'->'floor_plan') d on d.key = s.key loop
        if v_r.other is null then v_added := v_added + 1; v_keys := v_keys || ('+' || v_r.key);
        elsif v_r.other <> v_r.data then v_changed := v_changed + 1; v_keys := v_keys || ('~' || v_r.key); end if;
      end loop;
      for v_r in select d.key from public.floor_plan_rows(v_dst->'tables'->'floor_plan') d
                 where not exists (select 1 from public.floor_plan_rows(v_src->'tables'->'floor_plan') s where s.key = d.key) loop
        -- kept, never deleted: a seat may hold a booking
        v_removed := v_removed + 1; v_keys := v_keys || ('-' || v_r.key);
      end loop;
    else
      for v_k in select jsonb_array_elements_text(v_e->'tables') loop
        for v_row in select value from jsonb_array_elements(coalesce(v_src->'tables'->v_k, '[]'::jsonb)) loop
          v_key := public.entity_row_key(v_k, v_row);
          select value into v_other from jsonb_array_elements(coalesce(v_dst->'tables'->v_k, '[]'::jsonb)) o
           where public.entity_row_key(v_k, o.value) = v_key limit 1;
          if v_other is null then v_added := v_added + 1; v_keys := v_keys || ('+' || v_key);
          elsif v_other <> v_row then v_changed := v_changed + 1; v_keys := v_keys || ('~' || v_key); end if;
          v_other := null;
        end loop;
        for v_row in select value from jsonb_array_elements(coalesce(v_dst->'tables'->v_k, '[]'::jsonb)) loop
          v_key := public.entity_row_key(v_k, v_row);
          if not exists (select 1 from jsonb_array_elements(coalesce(v_src->'tables'->v_k, '[]'::jsonb)) s
                          where public.entity_row_key(v_k, s.value) = v_key) then
            v_removed := v_removed + 1; v_keys := v_keys || ('-' || v_key);
          end if;
        end loop;
      end loop;
    end if;
    v_out := v_out || jsonb_build_object('key', v_e->>'key', 'kind', v_e->>'kind',
      'added', v_added, 'changed', v_changed, 'removed', v_removed, 'details', to_jsonb(v_keys));
  end loop;
  return jsonb_build_object('direction', public.deployment_direction(p_from, p_to), 'entities', v_out);
end;
$fn$;

create or replace function public.deploy_entities(p_from uuid, p_to uuid, p_entities text[])
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_direction text; v_preview jsonb; v_snapshot jsonb; v_before jsonb; v_id uuid; v_pair uuid; v_name text;
  v_jobs jsonb := '[]'::jsonb;
begin
  if p_entities is null or array_length(p_entities, 1) is null then raise exception 'nothing to deploy'; end if;
  v_direction := public.deployment_direction(p_from, p_to);
  if not public.may_deploy(p_from, p_to) then raise exception 'not allowed to deploy in this direction'; end if;
  perform set_config('deskilo.deploying', p_from::text || ':' || p_to::text, true);
  v_preview := public.preview_deployment(p_from, p_to, p_entities);
  v_before := public.export_entities(p_to, p_entities);
  v_snapshot := public.export_entities(p_from, p_entities);
  perform public.import_workspace_configuration(p_to, v_snapshot - 'tables' || jsonb_build_object('tables', (v_snapshot->'tables') - 'floor_plan'));
  if 'floor_plan' = any (p_entities) then
    v_jobs := public.merge_floor_plan(p_to, v_snapshot->'tables'->'floor_plan')->'copy_jobs';
  end if;
  select pair_id into v_pair from public.workspaces where id = p_from;
  select coalesce(display_name, '') into v_name from public.profiles where id = auth.uid();
  insert into public.deployments (workspace_id, pair_id, from_workspace_id, to_workspace_id, direction, entities, snapshot, before, summary, actor_user_id, actor_name)
  values (p_to, v_pair, p_from, p_to, v_direction, p_entities, v_snapshot, v_before, v_preview->'entities', auth.uid(), v_name)
  returning id into v_id;
  return jsonb_build_object('id', v_id, 'direction', v_direction, 'entities', v_preview->'entities', 'copy_jobs', v_jobs);
end;
$fn$;

-- A rollback puts the plan's matched elements back; what the deploy
-- added stays, since a seat may have been booked since.
create or replace function public.rollback_deployment(p_deployment_id uuid)
returns void language plpgsql security definer set search_path = public as $fn$
declare v_d public.deployments;
begin
  select * into v_d from public.deployments where id = p_deployment_id;
  if v_d.id is null then raise exception 'unknown deployment'; end if;
  if v_d.rolled_back_at is not null then raise exception 'already rolled back'; end if;
  if not public.may_deploy(v_d.from_workspace_id, v_d.to_workspace_id) then raise exception 'not allowed to deploy in this direction'; end if;
  if exists (select 1 from public.deployments d where d.pair_id = v_d.pair_id and d.to_workspace_id = v_d.to_workspace_id
              and d.created_at > v_d.created_at and d.rolled_back_at is null) then
    raise exception 'a later deployment stands on this side; roll that one back first';
  end if;
  perform set_config('deskilo.deploying', v_d.from_workspace_id::text || ':' || v_d.to_workspace_id::text, true);
  perform public.import_workspace_configuration(v_d.to_workspace_id, v_d.before - 'tables' || jsonb_build_object('tables', (v_d.before->'tables') - 'floor_plan'));
  if v_d.before->'tables' ? 'floor_plan' then
    perform public.merge_floor_plan(v_d.to_workspace_id, v_d.before->'tables'->'floor_plan');
  end if;
  update public.deployments set rolled_back_at = now() where id = p_deployment_id;
end;
$fn$;
