-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- #4168 — the recorded configuration stages (0835) are append-only, but they
-- belong to their business: `workspace_id` references `workspaces` on delete
-- cascade, and the trigger refused the cascade, so a business that had
-- confirmed a kind could never be deleted (nor its data erased). A stage is
-- still never changed, and never deleted while its business exists; it goes
-- with the business (the pattern of `stock_movements_append_only`, 0747).
create or replace function public.configuration_choice_events_append_only() returns trigger
language plpgsql set search_path = public as $fn$
begin
  if tg_op = 'DELETE' and not exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
    return old;
  end if;
  raise exception 'a recorded configuration stage is never changed or deleted' using errcode = 'DKK02';
end
$fn$;
revoke execute on function public.configuration_choice_events_append_only() from public, anon, authenticated;

select public.set_deskilo_schema_version(836);
