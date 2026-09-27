-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0282 (#1658) -- a template is applied at the revision the owner
-- reviewed, once.
--
-- apply_workspace_template applied whatever the template held when the
-- call arrived, and every call applied again. So an owner could review
-- revision 3, have the publisher republish revision 4 meanwhile, and get
-- 4 applied under a preview of 3; and a lost response retried by the app
-- applied the template twice.
--
-- apply_workspace_template_exact takes the reviewed template_version and
-- a request id. A template that moved answers 'stale' with its current
-- version and changes nothing: the app re-previews. A request id already
-- used for this workspace answers the recorded result ('replayed') when
-- the arguments are the same and 'conflict' when they are not. Otherwise
-- it applies through the existing guarded apply (every authority and
-- merge rule unchanged) and records the request id and result on the
-- application row it wrote. The old function stays for older clients.

alter table public.workspace_template_applications
  add column if not exists request_id uuid,
  add column if not exists result jsonb;
create unique index if not exists workspace_template_applications_request
  on public.workspace_template_applications (workspace_id, request_id) where request_id is not null;

create or replace function public.apply_workspace_template_exact(
  p_workspace_id uuid, p_template_id uuid, p_groups text[], p_expected_version integer, p_request_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_prior public.workspace_template_applications;
  v_version integer;
  v_result jsonb;
begin
  if auth.uid() is null
     or not public.has_permission(p_workspace_id, 'manageConfiguration') then
    raise exception 'only someone who configures this workspace applies a template';
  end if;
  if p_request_id is null then
    raise exception 'an application needs its request id';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_workspace_id::text || p_request_id::text, 1658));
  select * into v_prior from public.workspace_template_applications
   where workspace_id = p_workspace_id and request_id = p_request_id;
  if v_prior.id is not null then
    if v_prior.template_id = p_template_id and v_prior.groups = coalesce(p_groups, '{}') then
      return coalesce(v_prior.result, '{}'::jsonb)
             || jsonb_build_object('status', 'replayed', 'template_version', v_prior.template_version);
    end if;
    return jsonb_build_object('status', 'conflict', 'reason', 'request_id_reused');
  end if;
  if not public.workspace_template_readable(p_template_id) then
    raise exception 'unknown template';
  end if;
  select template_version into v_version from public.workspace_templates where id = p_template_id for share;
  if v_version is distinct from p_expected_version then
    return jsonb_build_object('status', 'stale', 'template_version', v_version);
  end if;
  v_result := public.apply_workspace_template(p_workspace_id, p_template_id, p_groups);
  update public.workspace_template_applications a
     set request_id = p_request_id, result = v_result
   where a.id = (select id from public.workspace_template_applications
                  where workspace_id = p_workspace_id and template_id = p_template_id and request_id is null
                  order by applied_at desc, created_datetime desc limit 1);
  return v_result || jsonb_build_object('status', 'applied', 'template_version', v_version);
end;
$fn$;
revoke execute on function public.apply_workspace_template_exact(uuid, uuid, text[], integer, uuid) from public, anon;
grant execute on function public.apply_workspace_template_exact(uuid, uuid, text[], integer, uuid) to authenticated;

select public.set_deskilo_schema_version(282);
