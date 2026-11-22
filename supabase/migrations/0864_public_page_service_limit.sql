-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- #4318: the public page, the Discover card and the search by service carry the first
-- N public services, and N has one source.
--   * `public_page_service_limit()` is that source (12). The app mirrors it in
--     `publicPageServiceLimit` (lib/features/money/domain/public_page.dart), and
--     test/lint/public_page_service_limit_test.dart keeps the two equal.
--   * the order is the services list's order: category (alphabetical, uncategorised last),
--     then sort order, then name. The owner sees in that list which public services the
--     page carries.
--   * every published card is refreshed, so it carries the new order.

create or replace function public.public_page_service_limit() returns integer
language sql immutable set search_path = public as $$ select 12 $$;
revoke execute on function public.public_page_service_limit() from public;
grant execute on function public.public_page_service_limit() to anon, authenticated;

create or replace function pg_temp.anchor_replace(p_def text,p_old text,p_new text)
returns text language sql as $$
 select case when (length(p_def)-length(replace(p_def,p_old,'')))/length(p_old)=1
  then replace(p_def,p_old,p_new) else null end;
$$;
revoke execute on function pg_temp.anchor_replace(text,text,text) from public,anon,authenticated;

do $patch$
declare v_def text;
begin
 v_def := pg_get_functiondef('public.public_workspace_offer(uuid)'::regprocedure);
 v_def := pg_temp.anchor_replace(v_def,
  $old$select jsonb_agg(s.item order by s.sort_order, s.id)
        from (select sv.sort_order, sv.id,$old$,
  $new$select jsonb_agg(s.item order by s.uncategorised, s.category_key, s.sort_order, s.name_key, s.id)
        from (select nullif(btrim(sv.category), '') is null as uncategorised,
                     lower(coalesce(btrim(sv.category), '')) as category_key,
                     lower(sv.name) as name_key, sv.sort_order, sv.id,$new$);
 if v_def is null then raise exception 'public services aggregate anchor missing' using errcode='P0001'; end if;
 v_def := pg_temp.anchor_replace(v_def,
  $old$order by sv.sort_order, sv.id
               limit 12)$old$,
  $new$order by nullif(btrim(sv.category), '') is null, lower(coalesce(btrim(sv.category), '')),
                        sv.sort_order, lower(sv.name), sv.id
               limit public.public_page_service_limit())$new$);
 if v_def is null then raise exception 'public services limit anchor missing' using errcode='P0001'; end if;
 execute v_def;
end;
$patch$;
revoke execute on function public.public_workspace_offer(uuid) from public, anon, authenticated;

do $refresh$
declare v_id uuid;
begin
 for v_id in select workspace_id from public.public_workspace_cards loop
  perform public.refresh_public_workspace_card(v_id);
 end loop;
end;
$refresh$;

select public.set_deskilo_schema_version(864);
