-- SPDX-License-Identifier: 0BSD
-- 0190 — #1012: the preview of the document designs counts their images.
--
-- A twin receives the design JSON at creation, so the preview read "no
-- change" and refused to deploy — while the design's images (the logo)
-- had never reached the target's storage prefix. The preview now counts
-- every report image the source has and the target lacks as an
-- addition, so the deploy runs and its copy jobs carry the files.
create or replace function public.report_image_names(p_workspace_id uuid)
returns setof text language sql stable security definer set search_path = public as $fn$
  select regexp_replace(o.name, '^[^/]+/report/', '') from storage.objects o
   where o.bucket_id = 'floor-plans' and o.name like p_workspace_id::text || '/report/%';
$fn$;
revoke execute on function public.report_image_names(uuid) from public, anon;

do $patch$
declare v_def text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'preview_deployment';
  v_old := '    v_out := v_out || jsonb_build_object(''key'', v_e->>''key'', ''kind'', v_e->>''kind'',';
  if position(v_old in v_def) = 0 then raise exception 'preview anchor missing'; end if;
  v_def := replace(v_def, v_old,
    '    -- #1012 — the designs'' images the target lacks are additions.' || E'\n' ||
    '    if (v_e->>''key'') = ''document_design'' then' || E'\n' ||
    '      for v_r in select s as name from public.report_image_names(p_from) s' || E'\n' ||
    '                 where not exists (select 1 from public.report_image_names(p_to) t where t = s) loop' || E'\n' ||
    '        v_added := v_added + 1; v_keys := v_keys || (''+image:'' || v_r.name);' || E'\n' ||
    '      end loop;' || E'\n' ||
    '    end if;' || E'\n' || v_old);
  execute v_def;
end;
$patch$;
