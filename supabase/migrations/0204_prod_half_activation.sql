-- SPDX-License-Identifier: 0BSD
-- 0204 — the prod half of a dev+prod invitation was never activated.
--
-- 0201 (#1119) lets an invitation say "also production". On redemption
-- `join_workspace` inserts the dev row 'pending' with a member_join
-- event, and the prod row 'pending' with NO event — one approval for one
-- person was the point. But `respond_to_event` activates exactly
-- `subject_member_id`, the dev row, and `members_mirror_to_dev` only
-- mirrors prod → dev. So the prod row stayed 'pending' forever,
-- `is_member_of(prod)` stayed false, and the event payload said
-- also_prod_given=true. Caught in code review, not in the field.
--
-- The fix follows the ONE decision: when the dev member_join is
-- confirmed, the invitation's pending prod twin is activated with it;
-- when it is rejected, the twin exits with it.
--
-- Discriminator, so this can never bypass a prod approval of its own: a
-- prod row that carries a pending member_join event of ITS OWN was not
-- made by 0201 (it came through a prod invite code) and is left to that
-- event. A row made by 0201 has none.
--
-- Anchored patch: respond_to_event is large and much-patched; this cuts
-- at two exact clauses and asserts both before and after.
do $patch$
declare v_def text; v_new text; v_a text; v_r text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'respond_to_event';
  if v_def is null then raise exception '0204: respond_to_event not found'; end if;

  v_a := E'    elsif v_event.type = ''member_join'' then\n'
         '      update public.members set status = ''active''\n'
         '        where id = v_event.subject_member_id and status = ''pending'';';
  if position(v_a in v_def) = 0 then
    raise exception '0204: accept anchor missing';
  end if;
  v_new := replace(v_def, v_a, v_a || E'\n'
    '      -- #1119/0204 — the invitation''s prod twin follows the decision.\n'
    '      update public.members p set status = ''active''\n'
    '        from public.members d\n'
    '        join public.workspaces wd on wd.id = d.workspace_id\n'
    '        join public.workspaces wp on wp.pair_id = wd.pair_id\n'
    '                                 and wp.environment = ''prod'' and wp.id <> wd.id\n'
    '       where d.id = v_event.subject_member_id\n'
    '         and wd.environment = ''dev'' and wd.pair_id is not null\n'
    '         and p.workspace_id = wp.id and p.user_id = d.user_id\n'
    '         and p.status = ''pending''\n'
    '         and not exists (select 1 from public.events e\n'
    '                          where e.subject_member_id = p.id\n'
    '                            and e.type = ''member_join'' and e.status = ''pending'');');
  if v_new = v_def then raise exception '0204: accept patch changed nothing'; end if;

  v_r := E'    if v_event.type = ''member_join'' then\n'
         '      update public.members set status = ''exited''\n'
         '        where id = v_event.subject_member_id and status = ''pending'';';
  if position(v_r in v_new) = 0 then
    raise exception '0204: reject anchor missing';
  end if;
  v_def := v_new;
  v_new := replace(v_def, v_r, v_r || E'\n'
    '      -- #1119/0204 — and exits with it when refused.\n'
    '      update public.members p set status = ''exited''\n'
    '        from public.members d\n'
    '        join public.workspaces wd on wd.id = d.workspace_id\n'
    '        join public.workspaces wp on wp.pair_id = wd.pair_id\n'
    '                                 and wp.environment = ''prod'' and wp.id <> wd.id\n'
    '       where d.id = v_event.subject_member_id\n'
    '         and wd.environment = ''dev'' and wd.pair_id is not null\n'
    '         and p.workspace_id = wp.id and p.user_id = d.user_id\n'
    '         and p.status = ''pending''\n'
    '         and not exists (select 1 from public.events e\n'
    '                          where e.subject_member_id = p.id\n'
    '                            and e.type = ''member_join'' and e.status = ''pending'');');
  if v_new = v_def then raise exception '0204: reject patch changed nothing'; end if;
  if position('0204 — the invitation' in v_new) = 0
     or position('0204 — and exits' in v_new) = 0 then
    raise exception '0204: post-condition failed';
  end if;
  execute v_new;
end
$patch$;
revoke execute on function public.respond_to_event(uuid, boolean) from public, anon;
