-- SPDX-License-Identifier: 0BSD
--
-- #749 — two permissions of their own for the commercial agreements:
--   viewNegotiations   — read a member's deal (the sheet, the access list);
--   manageNegotiations — propose / change a member's deal.
-- Until now both rode 'viewFinances'. The owner always holds both; a
-- co-owner starts with everything; an admin starts with both (today's
-- behaviour, so nothing changes for a workspace that never opens the
-- matrix) and the owner removes what they want, per role.

-- ---------------------------------------------------------------- a member's permission
-- has_permission() answers for auth.uid(); the "who can see me" list
-- needs the same answer for ANY member.
create or replace function public.member_has_permission(p_member_id uuid, perm text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.members m
    join public.workspaces w on w.id = m.workspace_id
    where m.id = p_member_id
      and m.status = 'active'
      and (
        m.is_owner
        or (m.co_owner = 'active' and (
              case when w.role_permissions ? 'co_owner'
                   then w.role_permissions->'co_owner' ? perm
                   else true end))
        or (m.is_admin and (
              case when w.role_permissions ? 'admin'
                   then w.role_permissions->'admin' ? perm
                   else perm in ('manageMembers','manageDocuments',
                                 'manageServices','approveExpenses',
                                 'viewFinances','viewNegotiations',
                                 'manageNegotiations') end))
        or (not m.is_admin and not m.is_owner and m.co_owner <> 'active'
            and w.role_permissions ? 'member'
            and w.role_permissions->'member' ? perm)
      )
  );
$$;
revoke execute on function public.member_has_permission(uuid, text) from public, anon;
grant execute on function public.member_has_permission(uuid, text) to authenticated;

-- ---------------------------------------------------------------- has_permission: admin defaults
do $$
declare
  v_def text;
  v_old text := $o$                    else perm in ('manageMembers','manageDocuments',
                                  'manageServices','approveExpenses',
                                  'viewFinances') end)$o$;
  v_new text := $n$                    else perm in ('manageMembers','manageDocuments',
                                  'manageServices','approveExpenses',
                                  'viewFinances','viewNegotiations',
                                  'manageNegotiations') end)$n$;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'has_permission';
  if v_def is null then raise exception 'has_permission missing'; end if;
  if position(v_old in v_def) = 0 then raise exception 'has_permission default anchor not found'; end if;
  execute replace(v_def, v_old, v_new);
end $$;

-- ---------------------------------------------------------------- who may read a deal
create or replace function public.may_view_member_negotiations(p_member_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members m
     where m.id = p_member_id
       and (m.user_id = auth.uid()
            or public.has_permission(m.workspace_id, 'viewNegotiations')
            or public.has_permission(m.workspace_id, 'manageNegotiations'))
  );
$$;
revoke execute on function public.may_view_member_negotiations(uuid) from public, anon;
grant execute on function public.may_view_member_negotiations(uuid) to authenticated;

drop policy if exists price_negotiations_select on public.price_negotiations;
create policy price_negotiations_select on public.price_negotiations
  for select using (public.may_view_member_negotiations(member_id));

-- member_price_negotiation: the read guard follows the new permission.
do $$
declare
  v_def text;
  v_old text := $o$  if not public.may_view_member_finances(p_member_id) then raise exception 'not allowed to see this member''s deal'; end if;$o$;
  v_new text := $n$  if not public.may_view_member_negotiations(p_member_id) then raise exception 'not allowed to see this member''s deal'; end if;$n$;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'member_price_negotiation';
  if v_def is null then raise exception 'member_price_negotiation missing'; end if;
  if position(v_old in v_def) = 0 then raise exception 'read guard anchor not found'; end if;
  execute replace(v_def, v_old, v_new);
end $$;

-- propose_price_negotiation: proposing follows manageNegotiations.
do $$
declare
  v_def text;
  v_old text := $o$  if not (v_actor.is_owner or public.has_permission(v_member.workspace_id, 'viewFinances')) then raise exception 'only the owner or a finance admin may propose a deal'; end if;$o$;
  v_new text := $n$  if not (v_actor.is_owner or public.has_permission(v_member.workspace_id, 'manageNegotiations')) then raise exception 'only the owner or a member with the manageNegotiations permission may propose a deal'; end if;$n$;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'propose_price_negotiation';
  if v_def is null then raise exception 'propose_price_negotiation missing'; end if;
  if position(v_old in v_def) = 0 then raise exception 'propose guard anchor not found'; end if;
  execute replace(v_def, v_old, v_new);
end $$;

-- who_can_access_me: the negotiations list names who actually holds the
-- permission, per the matrix, not a role guess.
do $$
declare
  v_def text;
  v_old text := $o$    'negotiations', (
      select coalesce(jsonb_agg(m.id), '[]'::jsonb) from public.members m
       where m.workspace_id = p_workspace_id and m.status = 'active' and m.id <> v_me.id
         and (m.is_owner or m.co_owner = 'active' or m.is_admin)
    ),$o$;
  v_new text := $n$    'negotiations', (
      select coalesce(jsonb_agg(m.id), '[]'::jsonb) from public.members m
       where m.workspace_id = p_workspace_id and m.status = 'active' and m.id <> v_me.id
         and (public.member_has_permission(m.id, 'viewNegotiations')
              or public.member_has_permission(m.id, 'manageNegotiations'))
    ),$n$;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'who_can_access_me';
  if v_def is null then raise exception 'who_can_access_me missing'; end if;
  if position(v_old in v_def) = 0 then raise exception 'who_can_access_me negotiations anchor not found'; end if;
  execute replace(v_def, v_old, v_new);
end $$;
