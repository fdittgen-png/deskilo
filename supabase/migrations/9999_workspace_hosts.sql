-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- Additive: one reader. No table, no policy, no existing row or function
-- is changed.
--
-- #2562 C2c -- a person creates a workspace on a host they CHOOSE among the
-- workspace installations their personal home's operator enrolled (0567).
--
-- `my_workspace_hosts_v1()` is the client-readable list of those
-- enrolments, for the person signed in to their personal home in a native
-- session (`mcp_require_native()`: never anonymous, never a delegated or
-- identity-only token). Per enrolment in force it names the installation,
-- its HTTPS origin, its publishable key (the only key the relation keeps,
-- 0565's classification) and the one state the app acts on:
--
--   * `available`     -- it accepts new workspaces and this home has an
--                        enabled identity client for it, so the person can
--                        be signed in there under their own identity;
--   * `not_accepting` -- its operator closed it to new workspaces;
--   * `unverified`    -- it accepts, but no enabled identity client of
--                        this home names it: nobody can be verified there.
--
-- A revoked enrolment is not listed at all: the app reads a chosen host
-- that is no longer here as revoked, and refuses it. `here_hosts` says
-- whether this installation itself hosts workspaces, so "this server"
-- is offered only where it can be.
--
-- Nothing is written, nothing is granted: choosing a host is not
-- membership, and the creation itself runs on the chosen host's own
-- client through the existing onboarding (C1b's adopted session).
--
-- pgTAP 277 proves the reader's states, its order, what it never says and
-- who may call it.

create or replace function public.my_workspace_hosts_v1()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.mcp_require_native();
  return jsonb_build_object(
    'here_hosts', exists (select 1 from public.installation_identity
                           where 'workspace_host' = any (roles)),
    'hosts', coalesce((
      select jsonb_agg(jsonb_build_object(
               'installation_id', e.installation_id,
               'origin', e.origin,
               'publishable_key', e.publishable_key,
               'state', (case
                 when not e.accepting_new_workspaces then 'not_accepting'
                 when not exists (select 1 from public.identity_federation_clients c
                                   where c.target_installation_id = e.installation_id
                                     and c.enabled) then 'unverified'
                 else 'available' end))
             order by e.origin collate "C")
        from public.enrolled_installations e
       where e.enabled), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.my_workspace_hosts_v1() from public, anon;
grant execute on function public.my_workspace_hosts_v1() to authenticated;
comment on function public.my_workspace_hosts_v1() is
  '#2562 C2c -- the enrolled workspace installations a person may create a '
  'workspace on, with their publishable key and state; revoked ones are absent.';

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(9999);
