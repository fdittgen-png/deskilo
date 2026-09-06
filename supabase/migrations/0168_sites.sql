-- SPDX-License-Identifier: 0BSD
-- 0168 — #945: sites. The unit of address.
--
-- A workspace had one address, and every level, booking and document
-- stood at it. A workspace that opens a second building needs each
-- level to belong to a SITE with its own address and its own SIRET (the
-- establishment's, under the entity's SIREN), each member to have a home
-- site, and each document to name the site it concerns (#946).
--
-- Every workspace gets its default site from the address it already
-- has, so nothing changes until a second site is created: a null
-- levels.site_id or members.home_site_id means "the default site".
create table if not exists public.sites (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name         text not null check (char_length(name) between 1 and 80),
  street       text not null default '' check (char_length(street) <= 200),
  postal_code  text not null default '' check (char_length(postal_code) <= 16),
  city         text not null default '' check (char_length(city) <= 120),
  country_code text not null default '' check (char_length(country_code) <= 2),
  legal_id     text not null default '' check (char_length(legal_id) <= 40),
  is_default   boolean not null default false,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now()
);
create unique index if not exists sites_one_default_per_workspace on public.sites (workspace_id) where is_default;
alter table public.sites enable row level security;
drop policy if exists sites_select on public.sites;
create policy sites_select on public.sites for select using (public.is_member_of(workspace_id));
alter table public.levels add column if not exists site_id uuid references public.sites(id) on delete set null;
alter table public.members add column if not exists home_site_id uuid references public.sites(id) on delete set null;

insert into public.sites (workspace_id, name, street, postal_code, city, country_code, legal_id, is_default, sort_order)
select w.id, coalesce(nullif(w.name, ''), 'Site'), coalesce(w.street, ''), coalesce(w.postal_code, ''), coalesce(w.city, ''),
       coalesce(w.country_code, ''), coalesce(w.legal_id, ''), true, 0
  from public.workspaces w
 where not exists (select 1 from public.sites s where s.workspace_id = w.id and s.is_default);

create or replace function public.default_site(p_workspace_id uuid) returns public.sites
language sql stable security definer set search_path = public as $$
  select s from public.sites s where s.workspace_id = p_workspace_id and s.is_default limit 1;
$$;

-- The site a member's documents name: their home site, else the default.
create or replace function public.document_site_for_member(p_member_id uuid) returns public.sites
language sql stable security definer set search_path = public as $$
  select coalesce((select s from public.sites s join public.members m on m.home_site_id = s.id where m.id = p_member_id),
                  (select public.default_site(m.workspace_id) from public.members m where m.id = p_member_id));
$$;
grant execute on function public.document_site_for_member(uuid) to authenticated;

create or replace function public.upsert_site(
  p_workspace_id uuid, p_id uuid, p_name text, p_street text, p_postal_code text, p_city text,
  p_country_code text, p_legal_id text, p_sort_order int default 0)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.is_admin_of(p_workspace_id) then raise exception 'admins only'; end if;
  if p_id is null then
    insert into public.sites (workspace_id, name, street, postal_code, city, country_code, legal_id, sort_order)
    values (p_workspace_id, btrim(p_name), btrim(coalesce(p_street,'')), btrim(coalesce(p_postal_code,'')), btrim(coalesce(p_city,'')),
            upper(btrim(coalesce(p_country_code,''))), btrim(coalesce(p_legal_id,'')), coalesce(p_sort_order, 0))
    returning id into v_id;
  else
    update public.sites
       set name = btrim(p_name), street = btrim(coalesce(p_street,'')), postal_code = btrim(coalesce(p_postal_code,'')),
           city = btrim(coalesce(p_city,'')), country_code = upper(btrim(coalesce(p_country_code,''))),
           legal_id = btrim(coalesce(p_legal_id,'')), sort_order = coalesce(p_sort_order, sort_order)
     where id = p_id and workspace_id = p_workspace_id
    returning id into v_id;
    if v_id is null then raise exception 'unknown site'; end if;
  end if;
  return v_id;
end;
$$;
grant execute on function public.upsert_site(uuid, uuid, text, text, text, text, text, text, int) to authenticated;

-- Levels and members of a deleted site fall back to the default (null).
create or replace function public.delete_site(p_site_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_site public.sites;
begin
  select * into v_site from public.sites where id = p_site_id;
  if v_site.id is null then raise exception 'unknown site'; end if;
  if not public.is_admin_of(v_site.workspace_id) then raise exception 'admins only'; end if;
  if v_site.is_default then raise exception 'the default site cannot be deleted'; end if;
  update public.levels set site_id = null where site_id = p_site_id;
  update public.members set home_site_id = null where home_site_id = p_site_id;
  delete from public.sites where id = p_site_id;
end;
$$;
grant execute on function public.delete_site(uuid) to authenticated;

create or replace function public.set_level_site(p_level_id uuid, p_site_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_ws uuid;
begin
  select workspace_id into v_ws from public.levels where id = p_level_id;
  if v_ws is null then raise exception 'unknown level'; end if;
  if not public.is_admin_of(v_ws) then raise exception 'admins only'; end if;
  if p_site_id is not null and not exists (select 1 from public.sites where id = p_site_id and workspace_id = v_ws) then
    raise exception 'site is not in this workspace';
  end if;
  update public.levels set site_id = p_site_id where id = p_level_id;
end;
$$;
grant execute on function public.set_level_site(uuid, uuid) to authenticated;

create or replace function public.set_member_home_site(p_member_id uuid, p_site_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_ws uuid;
begin
  select workspace_id into v_ws from public.members where id = p_member_id;
  if v_ws is null then raise exception 'unknown member'; end if;
  if not public.is_admin_of(v_ws) then raise exception 'admins only'; end if;
  if p_site_id is not null and not exists (select 1 from public.sites where id = p_site_id and workspace_id = v_ws) then
    raise exception 'site is not in this workspace';
  end if;
  update public.members set home_site_id = p_site_id where id = p_member_id;
end;
$$;
grant execute on function public.set_member_home_site(uuid, uuid) to authenticated;
