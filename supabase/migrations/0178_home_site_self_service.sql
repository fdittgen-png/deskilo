-- SPDX-License-Identifier: 0BSD
-- 0178 — #974: a member picks their own home site.
--
-- set_member_home_site (0168) was admins-only. The home site decides
-- which address the person's documents carry and which levels are
-- theirs by default — their own affair on a multi-site workspace, so
-- the person now sets it from their profile; an admin still sets
-- anyone's. Harnessed: a plain member sets their own, is refused
-- another's; the owner sets anyone's.
create or replace function public.set_member_home_site(p_member_id uuid, p_site_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_ws uuid; v_user uuid;
begin
  select workspace_id, user_id into v_ws, v_user from public.members where id = p_member_id;
  if v_ws is null then raise exception 'unknown member'; end if;
  -- #974 — a member picks their OWN home site; an admin picks anyone's.
  if not (public.is_admin_of(v_ws) or (v_user is not null and v_user = auth.uid())) then
    raise exception 'admins only';
  end if;
  if p_site_id is not null and not exists (select 1 from public.sites where id = p_site_id and workspace_id = v_ws) then
    raise exception 'site is not in this workspace';
  end if;
  update public.members set home_site_id = p_site_id where id = p_member_id;
end;
$$;
