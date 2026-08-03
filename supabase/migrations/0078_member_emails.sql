-- SPDX-License-Identifier: 0BSD
-- Member emails for the members lists (#410). Emails live only in
-- auth.users; profiles deliberately exposes NO contact data to
-- co-members (WhatsApp is opt-in). So emails are an ADMIN surface: a
-- SECURITY DEFINER read gated on is_admin_of, returning the empty set
-- for everyone else (no error to probe against).

create or replace function public.member_emails(p_workspace_id uuid)
returns table(member_id uuid, email text)
language sql stable security definer set search_path = public as $$
  select m.id, coalesce(u.email::text, '')
  from public.members m
  join auth.users u on u.id = m.user_id
  where m.workspace_id = p_workspace_id
    and public.is_admin_of(p_workspace_id);
$$;

revoke execute on function public.member_emails(uuid) from public, anon;
grant execute on function public.member_emails(uuid) to authenticated;
