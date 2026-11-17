-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- Catalogue facts are optional. Missing accessibility is unknown. Place hours
-- follow configured booking rules; no parallel owner-authored schedule.
create or replace function public.public_profile_facets_catalogue()
returns jsonb language sql immutable set search_path=public as $catalogue$
 select $json${"amenities":["wifi","meeting_room","kitchen","printer","parking","bike_parking"],"accessibility":["step_free_entrance","accessible_toilet","lift"]}$json$::jsonb
$catalogue$;
revoke execute on function public.public_profile_facets_catalogue() from public,anon,authenticated;

create or replace function public.public_opening_hours(
 p_rules jsonb,p_timezone text,p_note text,p_place boolean
) returns jsonb language plpgsql immutable set search_path=public as $hours$
declare v_days jsonb; v_start text; v_end text;
begin
 if nullif(p_timezone,'') is null then return null; end if;
 if not p_place then
  if nullif(btrim(p_note),'') is null then return null; end if;
  return jsonb_build_object('note',p_note,'timezone',p_timezone);
 end if;
 v_days := p_rules->'open_weekdays';
 v_start := p_rules->>'work_start_minutes';
 v_end := p_rules->>'work_end_minutes';
 -- Only configured facts are published. Missing rules are not an owner claim
 -- about opening hours, and this projection does not invent product defaults.
 if v_days is null or jsonb_typeof(v_days)<>'array' then return null; end if;
 if jsonb_array_length(v_days)>7 or exists(select 1 from jsonb_array_elements(v_days) d
   where jsonb_typeof(d)<>'number' or d::text !~ '^[1-7]$') then return null; end if;
 if (select count(distinct d) from jsonb_array_elements(v_days) d)<>jsonb_array_length(v_days)
  or v_start is null or v_end is null or v_start !~ '^[0-9]{1,4}$' or v_end !~ '^[0-9]{1,4}$' then return null; end if;
 if v_start::int<0 or v_start::int>=v_end::int or v_end::int>1440 then return null; end if;
 return jsonb_build_object('weekdays',v_days,'start_minutes',v_start::int,
  'end_minutes',v_end::int,'timezone',p_timezone);
end;
$hours$;
revoke execute on function public.public_opening_hours(jsonb,text,text,boolean) from public,anon,authenticated;

create or replace function public.save_workspace_public_page(
 p_workspace uuid,p_document jsonb,p_published boolean,p_mode text default 'replace'
) returns jsonb language plpgsql security definer set search_path=public as $$
declare k text; v jsonb; v_doc jsonb; v_changes jsonb := '{}'::jsonb;
begin
 perform public.mcp_require_native();
 if auth.uid() is null or not public.is_owner_of(p_workspace) then raise exception 'owner required' using errcode = 'P0001'; end if;
 if p_document is null or jsonb_typeof(p_document)<>'object' or octet_length(p_document::text)>20000
  or p_published is null or p_mode is null or p_mode not in ('replace','patch') then
  raise exception 'invalid public page' using errcode = 'P0001';
 end if;
 for k,v in select * from jsonb_each(p_document) loop
  if k not in ('host_type','description','address','email','phone','website','image_url','plan_url','plans','latitude','longitude','amenities','accessibility','opening_hours') then
   raise exception 'invalid public field' using errcode = 'P0001';
  end if;
  if v = 'null'::jsonb then
   v_changes := v_changes || jsonb_build_object(k,null);
  elsif k in ('amenities','accessibility') then
   if jsonb_typeof(v)<>'array' then raise exception 'invalid public facts' using errcode='P0001'; end if;
   if jsonb_array_length(v)>jsonb_array_length(public.public_profile_facets_catalogue()->k)
    or exists(select 1 from jsonb_array_elements(v) item where jsonb_typeof(item)<>'string'
      or not (public.public_profile_facets_catalogue()->k) ? (item #>> '{}'))
    or (select count(distinct item) from jsonb_array_elements(v) item)<>jsonb_array_length(v) then
     raise exception 'invalid public facts' using errcode='P0001'; end if;
   v_changes := v_changes || jsonb_build_object(k,v);
  elsif k in ('latitude','longitude') then
   if jsonb_typeof(v) not in ('number','string') then raise exception 'invalid coordinates' using errcode = 'P0001'; end if;
   if v #>> '{}' = '' then
    v_changes := v_changes || jsonb_build_object(k,null);
   elsif v #>> '{}' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$' then
    raise exception 'invalid coordinates' using errcode = 'P0001';
   else
    v_changes := v_changes || jsonb_build_object(k,(v #>> '{}')::numeric);
   end if;
  else
   if jsonb_typeof(v)<>'string' or length(v #>> '{}')>4000 then raise exception 'invalid public field' using errcode = 'P0001'; end if;
   if k in ('website','image_url','plan_url') and v #>> '{}'<>'' and v #>> '{}' !~ '^https://[^[:space:]@]+$'
    then raise exception 'public links require HTTPS' using errcode = 'P0001'; end if;
   v_changes := v_changes || jsonb_build_object(k,v);
  end if;
 end loop;
 -- Serialize read/merge/write even when the page row has not been created yet.
 perform 1 from public.workspaces where id=p_workspace for update;
 v_doc := case when p_mode='patch' then
  coalesce((select document from public.workspace_public_pages where workspace_id=p_workspace for update),'{}'::jsonb)
  else '{}'::jsonb end;
 v_doc := jsonb_strip_nulls(v_doc || v_changes);
 if public.feature_effective(p_workspace,'placeBooking') and nullif(v_changes->>'opening_hours','') is not null then
  raise exception 'opening hours follow availability' using errcode='P0001'; end if;
 if octet_length(v_doc::text)>20000 then raise exception 'invalid public page' using errcode = 'P0001'; end if;
 if v_doc ? 'host_type' and v_doc->>'host_type' not in ('association','company','person') then
  raise exception 'invalid host type' using errcode = 'P0001'; end if;
 if coalesce(v_doc->>'latitude','')<>'' or coalesce(v_doc->>'longitude','')<>'' then
  if (v_doc->>'latitude')::numeric not between -90 and 90 or (v_doc->>'longitude')::numeric not between -180 and 180
   or nullif(v_doc->>'latitude','') is null or nullif(v_doc->>'longitude','') is null then raise exception 'invalid coordinates' using errcode = 'P0001'; end if;
  v_doc := v_doc || jsonb_build_object('latitude',(v_doc->>'latitude')::numeric,'longitude',(v_doc->>'longitude')::numeric);
 else
  v_doc := v_doc - 'latitude' - 'longitude';
 end if;
 insert into public.workspace_public_pages(workspace_id,document,published) values(p_workspace,v_doc,p_published)
 on conflict(workspace_id) do update set document=excluded.document,published=excluded.published;
 update public.workspaces set feature_flags=feature_flags || jsonb_build_object('publicListings',p_published) where id=p_workspace;
 if not p_published then delete from public.public_workspace_cards where workspace_id=p_workspace; end if;
 return public.public_workspace_document(p_workspace);
end;
$$;
revoke execute on function public.save_workspace_public_page(uuid,jsonb,boolean,text) from public,anon;
grant execute on function public.save_workspace_public_page(uuid,jsonb,boolean,text) to authenticated;

create or replace function pg_temp.anchor_replace(p_def text,p_old text,p_new text)
returns text language sql as $$
 select case when (length(p_def)-length(replace(p_def,p_old,'')))/length(p_old)=1
  then replace(p_def,p_old,p_new) else null end;
$$;
revoke execute on function pg_temp.anchor_replace(text,text,text) from public,anon,authenticated;
do $patch$
declare v_def text;
begin
 v_def := pg_get_functiondef('public.public_workspace_document(uuid)'::regprocedure);
 v_def := pg_temp.anchor_replace(v_def,
  $old$|| public.public_workspace_offer(w.id)$old$,
  $new$|| public.public_workspace_offer(w.id)
  || jsonb_build_object('opening_hours',public.public_opening_hours(w.booking_rules,w.timezone,
     page.document->>'opening_hours',public.feature_effective(w.id,'placeBooking')))$new$);
 if v_def is null then raise exception 'public hours projection anchor missing' using errcode='P0001'; end if;
 execute v_def;
end;
$patch$;

-- A timezone change changes the meaning of the published regular hours.
drop trigger refresh_public_workspace on public.workspaces;
create trigger refresh_public_workspace after update of name, feature_flags, booking_rules,
 currency_code, address, street, postal_code, city, invoice_legal, visibility, visibility_set_at,
 vat_regime, country_code, timezone
 on public.workspaces for each row execute function public.refresh_public_profile_cards();

create or replace function public.public_network_descriptor()
returns jsonb
language sql
stable
set search_path = public
as $descriptor$
  select $json${"protocol":"deskilo.public-network","protocol_versions":[1],"capabilities":["kind_filter","operation_header","profile_facets"],"operations":[{"id":"network.descriptor.read","versions":[1],"requires":[]},{"id":"directory.sources.list","versions":[1],"requires":[]},{"id":"directory.workspaces.search","versions":[1],"requires":[]},{"id":"directory.workspaces.detail","versions":[1],"requires":[]},{"id":"directory.sources.register","versions":[1],"requires":[],"unlabelled":1},{"id":"workspace.profile.request","versions":[1],"requires":[],"unlabelled":1}]}$json$::jsonb
    || jsonb_build_object(
         'roles', to_jsonb(i.roles),
         'role_capabilities', coalesce((
           select jsonb_agg(c.capability order by c.ordinal)
             from (values (1, 'personal_home', 'personal@1'), (2, 'workspace_host', 'workspace@1')) as c (ordinal, role, capability)
            where c.role = any (i.roles)), '[]'::jsonb))
    from public.installation_identity i
$descriptor$;

do $refresh$
declare v_id uuid;
begin
 for v_id in select workspace_id from public.public_workspace_cards loop
  perform public.refresh_public_workspace_card(v_id);
 end loop;
end;
$refresh$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(812);
