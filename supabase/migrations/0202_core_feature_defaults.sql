-- SPDX-License-Identifier: 0BSD
-- 0202 — #1063: a new workspace starts Core, not Everything.
--
-- The registry has a hundred flags. Every one of them is behind a
-- feature toggle already, which is the right architecture; what was
-- wrong is that the DEFAULT was "all of it", so a fifteen-person
-- community met VAT groups, positioned report layouts, environment
-- pairs and the deployment engine beside the six things it needed on
-- day one.
--
-- ── why the list is not in this file ───────────────────────────────
--
-- `create_workspace` takes the flags as a parameter instead of knowing
-- them. A copy of the catalogue in SQL would be a second registry, and
-- the two would disagree within a release — which is exactly the drift
-- 0195 spent a migration removing from the permission catalogue, and
-- #982 before it. The tier lives on `featureManifest`, next to the flag
-- it describes, and `defaultFeatureFlagsForNewWorkspace()` derives the
-- object. The instance wizard calls the same function.
--
-- ── and why no existing workspace moves ────────────────────────────
--
-- The parameter defaults to null, and null means "write nothing", which
-- is exactly today's behaviour. Resolution is untouched: a workspace
-- created before this keeps resolving its stored flags against the
-- registry defaults as it always has. Nothing here reaches backwards.
-- A migration that silently switched a live workspace's features off
-- would be a data-loss bug wearing a feature flag.
--
-- The twin gets the SAME object. A dev and a prod that disagreed about
-- which features exist would make the deployment engine's diff
-- meaningless from the first minute.

create or replace function public.create_workspace(
  p_name text, p_country_code text, p_currency_code text, p_timezone text,
  p_environment text default 'dev', p_with_twin boolean default true,
  p_feature_flags jsonb default null
) returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  ws_id uuid;
  twin_id uuid;
  v_pair uuid;
  v_other text;
  -- Only an object is accepted. A client that sends an array or a
  -- string does not get to decide the shape of this column.
  v_flags jsonb := case
    when p_feature_flags is null then '{}'::jsonb
    when jsonb_typeof(p_feature_flags) = 'object' then p_feature_flags
    else '{}'::jsonb
  end;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.user_has_email(auth.uid()) then raise exception 'an owner must have an e-mail address'; end if;
  if coalesce(p_environment, 'dev') not in ('dev', 'prod') then
    raise exception 'unknown environment %', p_environment;
  end if;
  v_pair := case when p_with_twin then gen_random_uuid() else null end;
  insert into public.workspaces
    (name, country_code, currency_code, timezone, created_by, environment,
     pair_id, feature_flags)
  values (p_name, upper(p_country_code), upper(p_currency_code), p_timezone,
          auth.uid(), coalesce(p_environment, 'dev'), v_pair, v_flags)
  returning id into ws_id;
  insert into public.members (workspace_id, user_id, is_admin, is_owner, origin)
  values (ws_id, auth.uid(), true, true, 'founder');
  update public.members set member_number = public.next_document_number(ws_id, 'member')
    where workspace_id = ws_id and user_id = auth.uid();
  if p_with_twin then
    v_other := case when coalesce(p_environment, 'dev') = 'dev' then 'prod' else 'dev' end;
    insert into public.workspaces
      (name, country_code, currency_code, timezone, created_by, environment,
       pair_id, feature_flags)
    values (p_name, upper(p_country_code), upper(p_currency_code), p_timezone,
            auth.uid(), v_other, v_pair, v_flags)
    returning id into twin_id;
    insert into public.members (workspace_id, user_id, is_admin, is_owner, origin)
    values (twin_id, auth.uid(), true, true, 'founder');
    update public.members set member_number = public.next_document_number(twin_id, 'member')
      where workspace_id = twin_id and user_id = auth.uid();
  end if;
  return ws_id;
end;
$fn$;
revoke execute on function
  public.create_workspace(text, text, text, text, text, boolean, jsonb)
  from public, anon;

-- The six-argument signature is dropped rather than left beside the new
-- one: an overload whose extra parameter has a default is ambiguous
-- against an exact-arity sibling, and PostgreSQL refuses the call
-- rather than choosing. 0201 learned this on `create_invitation`.
drop function if exists
  public.create_workspace(text, text, text, text, text, boolean);
