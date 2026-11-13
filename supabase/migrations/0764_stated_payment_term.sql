-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0764 (#3889) -- a payment term is stated only when somebody wrote it. The
-- reminder rules keep a mirror of the term (0428), and every write of the
-- rules is a whole write: saving them for another field, or importing a
-- configuration whose term is the one already held, stored that unchanged
-- term as the business's own. From then on each new invoice took the
-- business's term as stated (`document_term`) and automatic reminders could
-- follow it, where a business that never wrote it keeps the platform's
-- default, which needs review (`default_term`).
--
-- The mirror's trigger (0428), restated whole: a write that leaves the term
-- as the row held it states nothing; a write that changes it stores it as
-- before.
create or replace function public.dunning_rules_sync_setting()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_raw text := new.dunning_rules ->> 'first_after_days';
  v_n int;
begin
  if v_raw is null or v_raw !~ '^[0-9]{1,6}$' then return new; end if;
  if tg_op = 'UPDATE' and (old.dunning_rules ->> 'first_after_days') is not distinct from v_raw then
    return new;
  end if;
  v_n := least(greatest(v_raw::int, 1), 365);
  perform public.store_setting(new.id, 'dunning.first_after_days', to_jsonb(v_n), 'dunning rules', auth.uid());
  if v_n <> v_raw::int then
    update public.workspaces
       set dunning_rules = dunning_rules || jsonb_build_object('first_after_days', v_n)
     where id = new.id;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.dunning_rules_sync_setting() from public, anon, authenticated;

select public.set_deskilo_schema_version(764);
