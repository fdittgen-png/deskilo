-- SPDX-License-Identifier: 0BSD
-- 0160 — #917: a workspace says whether it is real.
--
-- Nothing distinguished a space used for trying things out from a space
-- billing real people. The same app, the same documents, the same
-- numbering — and an invoice printed while exploring is indistinguishable
-- from one that is owed. So a workspace now carries its ENVIRONMENT.
--
-- 'dev' is the default, and every workspace that already exists becomes
-- one: the safe answer to "is this real?" is no until somebody says
-- otherwise. Declaring a space PROD is a deliberate act by its owner.
alter table public.workspaces
  add column if not exists environment text not null default 'dev'
    check (environment in ('dev', 'prod'));

-- The environment is chosen AT CREATION and defaults to dev. The 4-arg
-- overload is dropped rather than kept beside it: two candidates make a
-- 4-argument call ambiguous, and PostgREST resolves the named-parameter
-- call against this one, so a client that does not send p_environment
-- still lands on the default.
drop function if exists public.create_workspace(text, text, text, text);
create or replace function public.create_workspace(
  p_name text, p_country_code text, p_currency_code text, p_timezone text,
  p_environment text default 'dev'
) returns uuid language plpgsql security definer set search_path = public as $$
declare ws_id uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if coalesce(p_environment, 'dev') not in ('dev', 'prod') then
    raise exception 'unknown environment %', p_environment;
  end if;
  insert into public.workspaces
    (name, country_code, currency_code, timezone, created_by, environment)
  values (p_name, upper(p_country_code), upper(p_currency_code), p_timezone,
          auth.uid(), coalesce(p_environment, 'dev'))
  returning id into ws_id;
  insert into public.members (workspace_id, user_id, is_admin, is_owner)
  values (ws_id, auth.uid(), true, true);
  return ws_id;
end;
$$;

-- Only the OWNER may declare a space real — an admin cannot quietly
-- take the development mark off the documents they issue.
create or replace function public.set_workspace_environment(
  p_workspace_id uuid,
  p_environment text
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'only owners may change the environment';
  end if;
  if p_environment not in ('dev', 'prod') then
    raise exception 'unknown environment %', p_environment;
  end if;
  update public.workspaces set environment = p_environment
    where id = p_workspace_id;
end;
$$;
revoke execute on function public.set_workspace_environment(uuid, text) from public, anon;
grant execute on function public.set_workspace_environment(uuid, text) to authenticated;
