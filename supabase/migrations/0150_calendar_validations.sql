-- Copyright (c) 2026 Florian DITTGEN
-- SPDX-License-Identifier: 0BSD
--
-- #843 — the calendar carried eleven kinds and none of them was a
-- validation. A decision that released or refused an invoice, a refund
-- or a deletion left no mark on the timeline: the alert said an event
-- had happened, the calendar never said when somebody decided about it.
--
-- A validation item sits at the MOMENT OF THE DECISION, not at the
-- moment of the event, which is the whole point — the two are often days
-- apart, and "when was this released" is the question being asked.
--
-- Patched in place (pg_get_functiondef + replace, anchors asserted): the
-- body is long and its access rules must not be retyped. The rules are
-- unchanged here — a validation is visible to exactly whoever could see
-- the event it decided.
do $patch$
declare
  v_def text;
  v_new text;
  v_old_want text := $o$'due','scheduled']);$o$;
  v_new_want text := $n$'due','scheduled','validation']);$n$;
  -- The deployed body carries no comments (0145 patched it through
  -- pg_get_functiondef), so the anchor has to be code.
  v_anchor text := $a$  if 'message' = any(v_want) then$a$;
  v_branch text := $b$  -- #843 validations: the decision, at the moment it was taken.
  -- Same reach as the event it decided; a decision nobody may see is
  -- not listed, and 'locked' says so.
  if 'validation' = any(v_want) then
    select coalesce(jsonb_agg(jsonb_build_object(
      'kind', 'validation', 'id', d.id, 'at', d.decided_at,
      'member_id', d.member_id,
      'title', e.type || '.' || case when d.decision = 'accept'
                 then 'validated' else 'refused' end,
      'status', d.decision,
      'payload', jsonb_build_object(
        'event_id', e.id, 'event_type', e.type, 'event_action', e.action,
        'by_system', d.decided_by_system,
        'subject_member_id', e.subject_member_id),
      'link', jsonb_build_object('type','event','id', e.id))
      order by d.decided_at), '[]'::jsonb)
      into v_rows
      from public.event_decisions d
      join public.events e on e.id = d.event_id
     where e.workspace_id = p_workspace_id
       and d.decided_at >= p_from and d.decided_at < p_to
       and (e.actor_member_id = v_subject or e.subject_member_id = v_subject
            or d.member_id = v_subject)
       and (v_admin or e.actor_member_id = v_me.id
            or e.subject_member_id = v_me.id or d.member_id = v_me.id);
    v_items := v_items || v_rows;
  end if;

$b$;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'calendar_items';
  if v_def is null then
    raise exception 'calendar_items is missing — 0133/0145 must run first';
  end if;
  if position('''validation''' in v_def) > 0 then
    return;  -- already patched
  end if;
  if position(v_old_want in v_def) = 0 then
    raise exception 'the default kind list is not where 0145 left it';
  end if;
  if position(v_anchor in v_def) = 0 then
    raise exception 'the messages branch is not where 0133 left it';
  end if;
  v_new := replace(v_def, v_old_want, v_new_want);
  v_new := replace(v_new, v_anchor, v_branch || v_anchor);
  if v_new = v_def then
    raise exception 'calendar_items did not change';
  end if;
  execute v_new;
end;
$patch$;
