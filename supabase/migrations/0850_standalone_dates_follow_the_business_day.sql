-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- #4309 (of #4166): the standalone invoice's date checks read the database clock's date
-- (`current_date`, UTC on the hosted project), not the business's own day. For a business
-- east of UTC in its first hours after midnight (or west of it in its last), a due date of
-- the business's yesterday was not recognised as past and a due date of its today was, and
-- the quote dry-run's due date started from the wrong day. They now read
-- `public.workspace_today(workspace)`, the helper the dated member terms already use:
--   * standalone_invoice_issue_core: the due date is not before, and not more than 365 days
--     after, the business's today; a service date is never later than its today (the tax
--     point);
--   * customer_quote_dry_run: its due date counts 30 days from the later of the quote's day
--     and the business's today.
-- The frozen signature of an issued invoice is untouched (its issue date is a fact written
-- with the invoice, not a check). Anchored patches of the live definitions; each anchor is
-- asserted to occur exactly once.

do $patch$
declare
  v_def text;
  v_old text;
  v_next text;
begin
  v_def := pg_get_functiondef('public.standalone_invoice_issue_core(uuid, public.members, public.standalone_invoice_drafts)'::regprocedure);
  foreach v_old in array array[
    $a$p_draft.due_on < current_date$a$,
    $a$p_draft.due_on > current_date + 365$a$,
    $a$least(p_draft.service_date, current_date)$a$
  ] loop
    if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
      raise exception '0850: the anchor "%" of standalone_invoice_issue_core is not found exactly once', v_old using errcode = 'P0001';
    end if;
    v_def := replace(v_def, v_old, replace(v_old, 'current_date', 'public.workspace_today(p_workspace_id)'));
  end loop;
  execute v_def;

  v_def := pg_get_functiondef('public.customer_quote_dry_run(uuid, public.members, uuid, jsonb, date)'::regprocedure);
  v_old := $a$greatest(p_on, current_date)$a$;
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception '0850: the anchor of customer_quote_dry_run is not found exactly once' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, $a$greatest(p_on, public.workspace_today(p_workspace))$a$);
end
$patch$;

select public.set_deskilo_schema_version(850);
