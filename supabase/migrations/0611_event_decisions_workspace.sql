-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one column on event_decisions, backfilled; a before-insert trigger that
-- fills it from the event; an index; no policy change)
--
-- 0611 (#3099 slice B, PERF-2 of the performance audit) -- a decision
-- belongs to the workspace of its event. The column lets the realtime
-- feed subscribe to event_decisions with `workspace_id=eq.<active>`, as
-- it already does for events: a decision taken in another workspace no
-- longer wakes this one's inbox. Writers never pass it: the trigger reads
-- it from the event, so the RPCs and the sweep are unchanged.

alter table public.event_decisions
  add column if not exists workspace_id uuid references public.workspaces(id) on delete cascade;

update public.event_decisions d
   set workspace_id = e.workspace_id
  from public.events e
 where e.id = d.event_id
   and d.workspace_id is distinct from e.workspace_id;

create or replace function public.event_decisions_fill_workspace()
returns trigger language plpgsql set search_path = public as $fn$
begin
  select e.workspace_id into new.workspace_id from public.events e where e.id = new.event_id;
  return new;
end;
$fn$;
revoke execute on function public.event_decisions_fill_workspace() from public, anon, authenticated;

drop trigger if exists event_decisions_fill_workspace on public.event_decisions;
create trigger event_decisions_fill_workspace
  before insert or update of event_id on public.event_decisions
  for each row execute function public.event_decisions_fill_workspace();

alter table public.event_decisions alter column workspace_id set not null;

create index if not exists event_decisions_workspace_idx
  on public.event_decisions (workspace_id);

select public.set_deskilo_schema_version(611);
