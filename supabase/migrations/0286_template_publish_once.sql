-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0286 (#1658) -- a template is published once per request.
--
-- save_workspace_as_template upserts the template a workspace owns under
-- a key and bumps its version, so a lost response that the app retries
-- published the same thing twice (version +2) and, if the owner had
-- edited the form meanwhile, published the second form under the first
-- review. 0282 closed the same gap on the apply side.
--
-- save_workspace_as_template_once takes a request id. The template row
-- remembers the request that last published it and a digest of that
-- request's arguments. The same request id again answers 'replayed' with
-- the template id when the arguments are the same, and 'conflict' when
-- they are not, and changes nothing. Otherwise it publishes through the
-- existing function (every authority, key, visibility and publication
-- rule unchanged) and records the request. The replay window is the time
-- until the next publication of the same key, which replaces the record:
-- that is when a retry of the older request is no longer a retry.
-- The old function stays for older clients.

alter table public.workspace_templates
  add column if not exists publish_request_id uuid,
  add column if not exists publish_args text;
create unique index if not exists workspace_templates_publish_request
  on public.workspace_templates (owner_workspace_id, publish_request_id)
  where publish_request_id is not null;

create or replace function public.save_workspace_as_template_once(
  p_workspace_id uuid, p_key text, p_name text, p_description text,
  p_visibility text, p_tags text[], p_groups text[], p_request_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_args text := md5(jsonb_build_array(p_key, p_name, coalesce(p_description, ''), p_visibility,
                                       to_jsonb(coalesce(p_tags, '{}')), to_jsonb(p_groups))::text);
  v_prior public.workspace_templates;
  v_id uuid;
begin
  if auth.uid() is null or not public.is_owner_of(p_workspace_id) then
    raise exception 'only an owner publishes a template from a workspace';
  end if;
  if p_request_id is null then
    raise exception 'a publication needs its request id';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_workspace_id::text || p_request_id::text, 16582));
  select * into v_prior from public.workspace_templates
   where owner_workspace_id = p_workspace_id and publish_request_id = p_request_id;
  if v_prior.id is not null then
    if v_prior.publish_args = v_args then
      return jsonb_build_object('status', 'replayed', 'template_id', v_prior.id,
                                'template_version', v_prior.template_version);
    end if;
    return jsonb_build_object('status', 'conflict', 'reason', 'request_id_reused');
  end if;
  v_id := public.save_workspace_as_template(p_workspace_id, p_key, p_name, p_description,
                                            p_visibility, p_tags, p_groups);
  update public.workspace_templates
     set publish_request_id = p_request_id, publish_args = v_args
   where id = v_id;
  return jsonb_build_object('status', 'published', 'template_id', v_id,
    'template_version', (select template_version from public.workspace_templates where id = v_id));
end;
$fn$;
revoke execute on function public.save_workspace_as_template_once(uuid, text, text, text, text, text[], text[], uuid) from public, anon;
grant execute on function public.save_workspace_as_template_once(uuid, text, text, text, text, text[], text[], uuid) to authenticated;

select public.set_deskilo_schema_version(286);
