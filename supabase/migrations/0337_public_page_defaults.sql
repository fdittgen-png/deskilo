-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0337 (#2086) -- the public listing starts from the workspace's own
-- information instead of being a second, unrelated record.
--
-- A public field that has a LOCAL counterpart is inherited: the stored
-- page holds a value only when the owner overrode it, and an absent key
-- means "follows the workspace information". The projection resolves it,
-- so an anonymous reader always gets a concrete value and a later local
-- edit reaches a published card the owner did not override. Two fields
-- have a counterpart today:
--   * host_type -- the legal seller kind of the invoices (invoice_legal
--                  seller_kind): an association hosts as an association,
--                  anyone else as a company; a private host overrides it;
--   * address   -- the workspace's postal address, else its structured
--                  street, postal code and city.
-- Every other public field (description, contact, links, plans,
-- coordinates) has no local counterpart and stays what the owner typed;
-- private or operational fields never flow to the page.
--
-- reset_workspace_public_page clears the overrides of the named fields
-- (null = every inherited field), so the owner can always return to the
-- workspace information, one field or all at once. Publishing stays the
-- explicit save; a reset changes values, never whether the page is public.
--
-- Upgrade: a page saved before inheritance holds its values already, so
-- they are kept as overrides. A page that never stored an address keeps
-- an explicit blank one, so nothing a reader sees changes until the owner
-- chooses the workspace information. The cards are not rewritten.

alter table public.workspace_public_pages disable trigger user;
update public.workspace_public_pages
   set document = document || jsonb_build_object('address', '')
 where not document ? 'address';
alter table public.workspace_public_pages enable trigger user;

-- The local counterpart of every inherited public field.
create function public.workspace_public_defaults(p_workspace uuid) returns jsonb
language sql stable security definer set search_path=public as $$
 select jsonb_build_object(
  'host_type', case when coalesce(w.invoice_legal->>'seller_kind','')='association'
   then 'association' else 'company' end,
  'address', coalesce(nullif(btrim(w.address),''),
   concat_ws(', ', nullif(btrim(w.street),''),
    nullif(concat_ws(' ', nullif(btrim(w.postal_code),''), nullif(btrim(w.city),'')),''))))
 from public.workspaces w where w.id=p_workspace;
$$;
revoke execute on function public.workspace_public_defaults(uuid) from public,anon,authenticated;

create or replace function public.public_workspace_document(p_workspace uuid) returns jsonb
language sql stable security definer set search_path=public as $$
 select public.workspace_public_defaults(w.id) || coalesce(page.document,'{}'::jsonb)
  || jsonb_build_object('name',w.name,'currency',w.currency_code,
  'booking_unit',coalesce(w.booking_rules->>'granularity','flexible'),
  'contacts',coalesce((select jsonb_agg(jsonb_build_object('user_id',m.user_id,
    'name',coalesce(p.display_name,m.managed_name,''),'owner',m.is_owner,
    'available',coalesce(s.available,false)) order by m.is_owner desc,m.id)
   from public.members m left join public.profiles p on p.id=m.user_id
   left join public.account_contact_settings s on s.user_id=m.user_id
   left join public.member_public_contact c on c.member_id=m.id
   where m.workspace_id=w.id and m.status='active' and
    (m.is_owner or (m.is_admin and c.visible))), '[]'::jsonb))
 from public.workspaces w left join public.workspace_public_pages page on page.workspace_id=w.id
 where w.id=p_workspace;
$$;
revoke execute on function public.public_workspace_document(uuid) from public,anon,authenticated;

-- A local edit reaches a published card that follows the workspace.
drop trigger refresh_public_workspace on public.workspaces;
create trigger refresh_public_workspace after update of name,feature_flags,booking_rules,currency_code,
 address,street,postal_code,city,invoice_legal on public.workspaces
 for each row execute function public.refresh_public_profile_cards();

create or replace function public.save_workspace_public_page(p_workspace uuid,p_document jsonb,p_published boolean)
returns jsonb language plpgsql security definer set search_path=public as $$
declare k text; v jsonb;
begin
 perform public.mcp_require_native();
 if auth.uid() is null or not public.is_owner_of(p_workspace) then raise exception 'owner required'; end if;
 if p_document is null or jsonb_typeof(p_document)<>'object' or octet_length(p_document::text)>20000
  or p_published is null then raise exception 'invalid public page'; end if;
 for k,v in select * from jsonb_each(p_document) loop
  if k not in ('host_type','description','address','email','phone','website','image_url','plan_url','plans','latitude','longitude')
   or jsonb_typeof(v)<>'string' or length(v #>> '{}')>4000 then raise exception 'invalid public field'; end if;
  if k in ('website','image_url','plan_url') and v #>> '{}'<>'' and v #>> '{}' !~ '^https://[^[:space:]@]+$'
   then raise exception 'public links require HTTPS'; end if;
 end loop;
 -- An absent host_type follows the workspace information (#2086).
 if p_document ? 'host_type' and p_document->>'host_type' not in ('association','company','person') then
  raise exception 'invalid host type'; end if;
 if coalesce(p_document->>'latitude','')<>'' or coalesce(p_document->>'longitude','')<>'' then
  if (p_document->>'latitude')::numeric not between -90 and 90 or (p_document->>'longitude')::numeric not between -180 and 180
   or nullif(p_document->>'latitude','') is null or nullif(p_document->>'longitude','') is null then raise exception 'invalid coordinates'; end if;
 end if;
 insert into public.workspace_public_pages(workspace_id,document,published) values(p_workspace,p_document,p_published)
 on conflict(workspace_id) do update set document=excluded.document,published=excluded.published;
 update public.workspaces set feature_flags=feature_flags || jsonb_build_object('publicListings',p_published) where id=p_workspace;
 if not p_published then delete from public.public_workspace_cards where workspace_id=p_workspace; end if;
 return public.public_workspace_document(p_workspace);
end;
$$;

revoke execute on function public.save_workspace_public_page(uuid,jsonb,boolean) from public,anon;

-- The owner's page: the resolved values, and which fields follow.
create or replace function public.my_workspace_public_page(p_workspace uuid) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare v_doc jsonb;
begin
 perform public.mcp_require_native();
 if auth.uid() is null or not public.is_owner_of(p_workspace) then raise exception 'owner required'; end if;
 v_doc:=coalesce((select document from public.workspace_public_pages where workspace_id=p_workspace),'{}'::jsonb);
 return jsonb_build_object(
  'published',coalesce((select published from public.workspace_public_pages where workspace_id=p_workspace),false),
  'document',public.public_workspace_document(p_workspace),
  'following',jsonb_build_object('host_type',not v_doc ? 'host_type','address',not v_doc ? 'address'));
end;
$$;

revoke execute on function public.my_workspace_public_page(uuid) from public,anon;

create function public.reset_workspace_public_page(p_workspace uuid,p_fields text[]) returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_inherited constant text[] := array['host_type','address']; k text;
begin
 perform public.mcp_require_native();
 if auth.uid() is null or not public.is_owner_of(p_workspace) then raise exception 'owner required'; end if;
 if p_fields is not null then
  if cardinality(p_fields)=0 then raise exception 'not an inherited public field'; end if;
  foreach k in array p_fields loop
   if k is null or not k = any(v_inherited) then raise exception 'not an inherited public field'; end if;
  end loop;
 end if;
 update public.workspace_public_pages set document=document - coalesce(p_fields,v_inherited)
  where workspace_id=p_workspace;
 return public.my_workspace_public_page(p_workspace);
end;
$$;
revoke execute on function public.reset_workspace_public_page(uuid,text[]) from public,anon;
grant execute on function public.reset_workspace_public_page(uuid,text[]) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(337);
