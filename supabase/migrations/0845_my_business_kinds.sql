-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- #4168 -- Me names the kind of each business the person belongs to. The kind is
-- a workspace setting (`business.kind`, 0703); a person reads it for the
-- businesses they are an active member of, never another's. Only a kind the
-- business SET is returned: a business that never chose one has none to show
-- (the registry default is not a statement of the business).

create or replace function public.my_business_kinds_v1()
returns table (workspace_id uuid, kind text)
language sql stable security definer set search_path = public as $fn$
  select v.workspace_id, v.value #>> '{}'
    from public.setting_values v
    join public.members m
      on m.workspace_id = v.workspace_id and m.user_id = auth.uid() and m.status = 'active'
   where auth.uid() is not null and not public.mcp_is_delegated()
     and v.key = 'business.kind' and v.scope = 'workspace' and v.valid_to is null
$fn$;
revoke execute on function public.my_business_kinds_v1() from public, anon;
grant execute on function public.my_business_kinds_v1() to authenticated;

select public.set_deskilo_schema_version(845);
