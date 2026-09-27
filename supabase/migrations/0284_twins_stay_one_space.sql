-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0284 -- a space created as a dev + prod pair stays one space.
--
-- create_workspace_once applied the chosen template to the side it
-- returned (dev) and never to its twin: the prod side got neither the
-- plan nor the settings. And a template's feature profile could switch
-- environmentPairs off on dev only, so the two sides disagreed about
-- being a pair and Profiles listed the same space twice ("Flo 1",
-- "Mathieu test 6").
--
-- Creation now applies the template to both twins, and a pair created
-- as a pair keeps environmentPairs on on both sides (the owner can still
-- switch it off later, on both). Existing pairs whose sides disagree
-- about environmentPairs are aligned to ON: the two rows share a pair_id,
-- so they are one space. Nothing else about existing twins is changed;
-- the configuration deployment moves settings from dev to prod on request.

do $migration$
declare
  v_def text := pg_get_functiondef(
    'public.create_workspace_once(uuid,text,text,text,text,text,boolean,jsonb,uuid)'::regprocedure);
  v_old text := $a$  if p_template_id is not null then
    perform public.apply_workspace_template(v_id, p_template_id);
  end if;$a$;
begin
  if position('environmentPairs' in v_def) > 0 then
    return;
  end if;
  if position(v_old in v_def) = 0 then
    raise exception 'create_workspace_once no longer has the shape 0284 patches';
  end if;
  execute replace(v_def, v_old, $a$  if p_template_id is not null then
    perform public.apply_workspace_template(v_id, p_template_id);
    -- 0284: the twin is the same space; it gets the same template.
    perform public.apply_workspace_template(t.id, p_template_id)
       from public.workspaces s join public.workspaces t
         on t.pair_id = s.pair_id and t.id <> s.id
      where s.id = v_id and s.pair_id is not null;
  end if;
  -- 0284: created as a pair, it is shown as one.
  if p_with_twin then
    update public.workspaces w
       set feature_flags = coalesce(w.feature_flags, '{}'::jsonb) || '{"environmentPairs": true}'::jsonb
      from public.workspaces s
     where s.id = v_id and s.pair_id is not null and w.pair_id = s.pair_id;
  end if;$a$);
end
$migration$;

-- Existing pairs whose two sides disagree are one space: align to ON.
update public.workspaces w
   set feature_flags = coalesce(w.feature_flags, '{}'::jsonb) || '{"environmentPairs": true}'::jsonb
 where w.pair_id is not null
   and exists (
     select 1 from public.workspaces t
      where t.pair_id = w.pair_id and t.id <> w.id
        and coalesce(t.feature_flags->>'environmentPairs', 'none')
            is distinct from coalesce(w.feature_flags->>'environmentPairs', 'none'));

select public.set_deskilo_schema_version(284);
