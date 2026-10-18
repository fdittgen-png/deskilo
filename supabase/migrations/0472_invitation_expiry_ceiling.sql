-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0472 (#2485, S2 of #2483) -- the platform value of a security limit is a
-- ceiling for the workspace value.
--
-- `security.invitation_expiry_days` exists at two scopes (0451). The resolver
-- lets a workspace value win over the platform value, so after the platform
-- owner tightened the lifetime to 7 days a workspace that had stored 14 kept
-- issuing 14-day invitations: a longer lifetime silently weakened a promise
-- the platform had just made. `create_invitation` now takes the SHORTER of the
-- two. An invitation already created keeps its own expiry (expires_at is
-- written once, at creation), exactly as before.
--
-- Anchored patch of the live body (asserted to occur exactly once), as 0451.

create or replace function pg_temp.patch_function(p_proc regprocedure, p_old text[], p_new text[])
returns void
language plpgsql
as $f$
declare
  v_def text := pg_get_functiondef(p_proc);
  i int;
begin
  for i in 1 .. cardinality(p_old) loop
    if (length(v_def) - length(replace(v_def, p_old[i], ''))) <> length(p_old[i]) then
      raise exception '0472: anchor % is not present exactly once in %', i, p_proc;
    end if;
    v_def := replace(v_def, p_old[i], p_new[i]);
  end loop;
  execute v_def;
end
$f$;
revoke execute on function pg_temp.patch_function(regprocedure, text[], text[]) from public;

select pg_temp.patch_function('public.create_invitation(uuid, boolean, text, text, uuid, boolean)'::regprocedure,
  array[
    $a$make_interval(days => (public.setting_value(p_workspace_id, 'security.invitation_expiry_days') #>> '{}')::int)$a$],
  array[
    $a$make_interval(days => least(
            (public.setting_value(p_workspace_id, 'security.invitation_expiry_days') #>> '{}')::int,
            (public.setting_value(null, 'security.invitation_expiry_days') #>> '{}')::int))$a$]);

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(472);
