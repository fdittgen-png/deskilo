-- SPDX-License-Identifier: 0BSD
-- 0131 — who may read another member's money is a PERMISSION, not a
-- role (#709).
--
-- THE CLIENT AND THE SERVER DISAGREED ABOUT WHO MAY LOOK. The profile's
-- money card (#704) checks the `viewFinances` permission, the one the
-- owner grants and revokes per role in the matrix (#513). The server
-- guarded the same data with `is_admin_of()` — admin OR owner, full
-- stop. Two consequences, opposite directions:
--
--   * an admin whose role had *View finances* REVOKED saw no card, and
--     could still be served by `member_account` — the client gate was
--     the only thing standing between them and the figures;
--   * a plain member whose role was GRANTED it saw the card, and the
--     RPC refused them — a silent empty card, and the owner's decision
--     honoured by nobody.
--
-- `has_permission()` (0104) already knows the matrix, owners, active
-- co-owners and the admin defaults. This makes the money layer ask it.
--
-- ONE HELPER, so the rule lives in one place. Self always; otherwise
-- `viewFinances` OR `issueInvoices` — the invoicing role reads the
-- statement, the ledger and the invoices it issues from, and an owner
-- who grants one without the other has still granted the reading.

create or replace function public.may_view_member_finances(p_member_id uuid)
returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1 from public.members m
     where m.id = p_member_id
       and (m.user_id = auth.uid()
            or public.has_permission(m.workspace_id, 'viewFinances')
            or public.has_permission(m.workspace_id, 'issueInvoices'))
  );
$$;

-- ---------------------------------------------------------------- 1
-- The two RPCs. Their bodies are long and change often; this swaps the
-- ONE guard line in place and refuses to run if the line it expects is
-- not there — a drifted body fails loudly instead of quietly keeping
-- the old rule.

do $swap$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  -- member_account
  v_def := pg_get_functiondef('public.member_account(uuid)'::regprocedure);
  v_old := 'if not public.is_admin_of(v_member.workspace_id) and not exists (
    select 1 from public.members m
    where m.id = p_member_id and m.user_id = auth.uid()
  ) then
    raise exception ''not your account'';
  end if;';
  v_new := 'if not public.may_view_member_finances(p_member_id) then
    raise exception ''not your account'';
  end if;';
  if position(v_old in v_def) = 0 then
    raise exception '0131: member_account guard not found — body drifted';
  end if;
  execute replace(v_def, v_old, v_new);

  -- member_statement
  v_def := pg_get_functiondef('public.member_statement(uuid, text)'::regprocedure);
  v_old := 'v_caller_is_admin := public.is_admin_of(v_member.workspace_id);
  if not v_caller_is_admin and not exists (
    select 1 from public.members m
    where m.id = p_member_id and m.user_id = auth.uid()
  ) then
    raise exception ''not your statement'';
  end if;';
  v_new := 'v_caller_is_admin := public.is_admin_of(v_member.workspace_id);
  if not public.may_view_member_finances(p_member_id) then
    raise exception ''not your statement'';
  end if;';
  if position(v_old in v_def) = 0 then
    raise exception '0131: member_statement guard not found — body drifted';
  end if;
  execute replace(v_def, v_old, v_new);
end;
$swap$;

-- ---------------------------------------------------------------- 2
-- The row policies the ledger and the invoice list are read through.
-- Same rule, so a screen that lists what the RPC summarises cannot show
-- a different audience a different subset.

alter policy ledger_select on public.ledger_entries
  using (public.may_view_member_finances(member_id));

alter policy invoices_select on public.invoices
  using (public.may_view_member_finances(member_id));

-- ---------------------------------------------------------------- 3
-- E-mail addresses: the `manageMembers` permission, for the same reason.
-- The client's `memberEmails` already asks the matrix; the server asked
-- the role.

create or replace function public.member_emails(p_workspace_id uuid)
returns table (member_id uuid, email text)
language sql stable security definer
set search_path = public as $$
  select m.id, coalesce(u.email::text, '')
  from public.members m
  join auth.users u on u.id = m.user_id
  where m.workspace_id = p_workspace_id
    and public.has_permission(p_workspace_id, 'manageMembers');
$$;

notify pgrst, 'reload schema';
