-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0485 (#2569, C2b) -- the lease reminders on the calendar.
--
-- A new calendar kind `lease` shows the responsible member of a premises
-- lease two dated facts, status `notice_deadline` (the last day notice can be
-- given for the fixed term to end) and `end` (the day the lease ends: the
-- effective end of a terminated lease, else the end of the fixed term). It is
-- the person's own reminder, not money: only the responsible member sees it
-- on their own calendar; a terminated lease keeps its end, loses its deadline.
-- Patched IN PLACE (anchor asserted exactly once), as 0145 did.

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
      raise exception '0485: anchor % is not present exactly once in %', i, p_proc;
    end if;
    v_def := replace(v_def, p_old[i], p_new[i]);
  end loop;
  execute v_def;
end
$f$;
revoke execute on function pg_temp.patch_function(regprocedure, text[], text[]) from public, anon;

select pg_temp.patch_function(
  'public.calendar_items(uuid, timestamptz, timestamptz, text[], uuid)'::regprocedure,
  array[
    $a$                                     'due','scheduled','validation']);$a$,
    $a$  return jsonb_build_object(
    'subject_member_id', v_subject,$a$],
  array[
    $a$                                     'due','scheduled','validation','lease']);$a$,
    $a$  -- #2569 -- the lease reminders of the person responsible for a premises lease.
  if v_self and 'lease' = any(v_want) and public.feature_effective(p_workspace_id, 'premisesLease') then
    select coalesce(jsonb_agg(x order by x->>'at'), '[]'::jsonb) into v_rows from (
      select jsonb_build_object(
        'kind', 'lease', 'id', l.id || ':notice',
        'at', ((l.fixed_until - make_interval(months => l.notice_months))::date::timestamp at time zone w.timezone),
        'member_id', l.responsible_member_id, 'title', l.premises, 'status', 'notice_deadline',
        'link', jsonb_build_object('type', 'ledger',
          'period', to_char((l.fixed_until - make_interval(months => l.notice_months))::date, 'YYYY-MM'))) x
        from public.premises_leases l
        join public.workspaces w on w.id = l.workspace_id
       where l.workspace_id = p_workspace_id and l.responsible_member_id = v_subject
         and l.status in ('draft', 'active') and l.fixed_until is not null
         and ((l.fixed_until - make_interval(months => l.notice_months))::date::timestamp at time zone w.timezone) >= p_from
         and ((l.fixed_until - make_interval(months => l.notice_months))::date::timestamp at time zone w.timezone) < p_to
      union all
      select jsonb_build_object(
        'kind', 'lease', 'id', l.id || ':end',
        'at', (coalesce(l.effective_end, l.fixed_until)::timestamp at time zone w.timezone),
        'member_id', l.responsible_member_id, 'title', l.premises, 'status', 'end',
        'link', jsonb_build_object('type', 'ledger', 'period', to_char(coalesce(l.effective_end, l.fixed_until), 'YYYY-MM')))
        from public.premises_leases l
        join public.workspaces w on w.id = l.workspace_id
       where l.workspace_id = p_workspace_id and l.responsible_member_id = v_subject
         and coalesce(l.effective_end, l.fixed_until) is not null
         and (coalesce(l.effective_end, l.fixed_until)::timestamp at time zone w.timezone) >= p_from
         and (coalesce(l.effective_end, l.fixed_until)::timestamp at time zone w.timezone) < p_to
    ) s;
    v_items := v_items || v_rows;
  end if;

  return jsonb_build_object(
    'subject_member_id', v_subject,$a$]);

select public.set_deskilo_schema_version(485);
