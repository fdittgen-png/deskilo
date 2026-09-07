-- SPDX-License-Identifier: 0BSD
-- 0187 — #998: the deployment started from either side.
--
-- The permission is the DIRECTION's, and the actor holds it on the side
-- they stand on — which may be the target: pulling the dev into the
-- prod from the prod needs deployToProd there. So may_deploy asks
-- either side of the pair. The document designs — every report kind,
-- preset and language — form the reports group of the registry.
create or replace function public.may_deploy(p_from uuid, p_to uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select case public.deployment_direction(p_from, p_to)
    when 'dev_to_prod' then public.has_permission(p_from, 'deployToProd') or public.has_permission(p_to, 'deployToProd')
    else public.has_permission(p_from, 'deployToDev') or public.has_permission(p_to, 'deployToDev') end;
$fn$;

do $patch$
declare v_def text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'deployable_entities';
  v_old := 'jsonb_build_object(''key'', ''document_design'', ''kind'', ''configuration'',';
  if position(v_old in v_def) = 0 then raise exception 'registry anchor missing'; end if;
  v_def := replace(v_def, v_old, 'jsonb_build_object(''key'', ''document_design'', ''kind'', ''reports'',');
  execute v_def;
end;
$patch$;
