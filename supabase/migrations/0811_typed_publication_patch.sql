-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- The owner patches only supplied fields; null removes an override. Legacy
-- three-argument callers retain replacement semantics and string coordinates.
drop function public.save_workspace_public_page(uuid,jsonb,boolean);
create function public.save_workspace_public_page(
 p_workspace uuid,p_document jsonb,p_published boolean,p_mode text default 'replace'
) returns jsonb language plpgsql security definer set search_path=public as $$
declare k text; v jsonb; v_doc jsonb; v_changes jsonb := '{}'::jsonb;
begin
 perform public.mcp_require_native();
 if auth.uid() is null or not public.is_owner_of(p_workspace) then raise exception 'owner required'; end if;
 if p_document is null or jsonb_typeof(p_document)<>'object' or octet_length(p_document::text)>20000
  or p_published is null or p_mode is null or p_mode not in ('replace','patch') then
  raise exception 'invalid public page';
 end if;
 for k,v in select * from jsonb_each(p_document) loop
  if k not in ('host_type','description','address','email','phone','website','image_url','plan_url','plans','latitude','longitude') then
   raise exception 'invalid public field';
  end if;
  if v = 'null'::jsonb then
   v_changes := v_changes || jsonb_build_object(k,null);
  elsif k in ('latitude','longitude') then
   if jsonb_typeof(v) not in ('number','string') then raise exception 'invalid coordinates'; end if;
   if v #>> '{}' = '' then
    v_changes := v_changes || jsonb_build_object(k,null);
   elsif v #>> '{}' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$' then
    raise exception 'invalid coordinates';
   else
    v_changes := v_changes || jsonb_build_object(k,(v #>> '{}')::numeric);
   end if;
  else
   if jsonb_typeof(v)<>'string' or length(v #>> '{}')>4000 then raise exception 'invalid public field'; end if;
   if k in ('website','image_url','plan_url') and v #>> '{}'<>'' and v #>> '{}' !~ '^https://[^[:space:]@]+$'
    then raise exception 'public links require HTTPS'; end if;
   v_changes := v_changes || jsonb_build_object(k,v);
  end if;
 end loop;
 -- Serialize read/merge/write even when the page row has not been created yet.
 perform 1 from public.workspaces where id=p_workspace for update;
 v_doc := case when p_mode='patch' then
  coalesce((select document from public.workspace_public_pages where workspace_id=p_workspace for update),'{}'::jsonb)
  else '{}'::jsonb end;
 v_doc := jsonb_strip_nulls(v_doc || v_changes);
 if octet_length(v_doc::text)>20000 then raise exception 'invalid public page'; end if;
 if v_doc ? 'host_type' and v_doc->>'host_type' not in ('association','company','person') then
  raise exception 'invalid host type'; end if;
 if coalesce(v_doc->>'latitude','')<>'' or coalesce(v_doc->>'longitude','')<>'' then
  if (v_doc->>'latitude')::numeric not between -90 and 90 or (v_doc->>'longitude')::numeric not between -180 and 180
   or nullif(v_doc->>'latitude','') is null or nullif(v_doc->>'longitude','') is null then raise exception 'invalid coordinates'; end if;
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

-- Public v1 readers still receive decimal strings. Typed storage and management
-- writes must not make an older visitor silently lose the map location.
create or replace function pg_temp.anchor_replace(p_def text,p_old text,p_new text)
returns text language sql as $$
 select case when (length(p_def)-length(replace(p_def,p_old,'')))/length(p_old)=1
  then replace(p_def,p_old,p_new) else null end;
$$;
do $patch$
declare v_def text; v_old text := $old$d || coalesce(page.document, '{}'::jsonb)$old$;
 v_new text := $new$d || coalesce(page.document, '{}'::jsonb)
  || case when nullif(page.document->>'latitude','') is not null
   and nullif(page.document->>'longitude','') is not null then
    jsonb_build_object('latitude',page.document->>'latitude','longitude',page.document->>'longitude')
   else '{}'::jsonb end$new$;
begin
 v_def := pg_get_functiondef('public.public_workspace_document(uuid)'::regprocedure);
 v_def := pg_temp.anchor_replace(v_def,v_old,v_new);
 if v_def is null then
  raise exception 'public workspace projection anchor missing or ambiguous';
 end if;
 execute v_def;
end;
$patch$;
notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(811);
