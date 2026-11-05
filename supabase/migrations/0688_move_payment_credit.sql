-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (invoice_lines_for(uuid, text) patched at one anchor: a moved credit and
-- its reversal are left out of the lines, as a consumed credit already is)
--
-- 0688 (#2380) -- a payment credit booked on the wrong member is moved to
-- the right one, as a correcting entry. A bank line matched to the wrong
-- payer (or a payment recorded against the wrong person) left the money on
-- the wrong account: undoing the match (0650, 0657-0660) leaves the credit
-- where it was, and a ledger entry is never edited.
--
-- Nothing is edited. The move writes:
--   * on the wrong member, a reversal: a charge of the same amount, in the
--     credit's own month, so that month nets to what it was before the
--     credit was booked;
--   * on the right member, a new payment credit of the same amount, in the
--     same month and on the same day (the money arrived then);
--   * ledger_credit_moves, append-only (no write grant): the original credit,
--     the reversal, the new credit, both members, the amount, why, who and
--     when, and the request id.
-- A bank line that pointed at the moved credit points at the new one, so it
-- still reads 'recorded' and a match from the line now uses the right
-- member's credit. The moved credit and its reversal are left out of invoice
-- lines (they cancel each other and are not a supply), as a credit consumed
-- by a match already is; the books post money in from the match, never from
-- a credit, so no posting moves.
--
--   move_payment_credit_v1   issueInvoices while bankImport is on (the
--                            reconciliation this corrects); a reason is
--                            required. Refused in words: a credit that is not
--                            a payment credit of the space, a credit consumed
--                            by a match (undo the match first), a credit
--                            already moved, the same member, a member who
--                            left, a month already invoiced to the wrong
--                            member, a month inside a closed period of the
--                            books. Exactly once: the credit is locked, then
--                            read again; the same request id answers what it
--                            answered, a request id used for another credit
--                            is refused.

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

create table if not exists public.ledger_credit_moves (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  from_credit_id uuid not null references public.ledger_entries(id),
  reversal_ledger_id uuid not null references public.ledger_entries(id),
  to_credit_id uuid not null references public.ledger_entries(id),
  from_member_id uuid not null,
  to_member_id uuid not null,
  amount_cents int not null check (amount_cents > 0),
  reason text not null check (char_length(reason) between 1 and 300),
  request_id uuid not null,
  actor_member_id uuid not null,
  moved_at timestamptz not null default now(),
  foreign key (workspace_id, from_member_id) references public.members (workspace_id, id),
  foreign key (workspace_id, to_member_id) references public.members (workspace_id, id),
  foreign key (workspace_id, actor_member_id) references public.members (workspace_id, id),
  constraint ledger_credit_moves_once unique (from_credit_id),
  constraint ledger_credit_moves_request unique (workspace_id, request_id)
);
select public.ensure_system_columns('ledger_credit_moves');
create index if not exists ledger_credit_moves_reversal on public.ledger_credit_moves (reversal_ledger_id);
create index if not exists ledger_credit_moves_to on public.ledger_credit_moves (to_credit_id);

alter table public.ledger_credit_moves enable row level security;
revoke all on public.ledger_credit_moves from public, anon, authenticated;
grant select on public.ledger_credit_moves to authenticated;
drop policy if exists ledger_credit_moves_select on public.ledger_credit_moves;
create policy ledger_credit_moves_select on public.ledger_credit_moves
  for select to authenticated using (public.bank_statement_reader(workspace_id));
drop policy if exists mcp_delegated_deny on public.ledger_credit_moves;
create policy mcp_delegated_deny on public.ledger_credit_moves as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create or replace function public.move_payment_credit_v1(
  p_credit_id uuid, p_to_member_id uuid, p_reason text, p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_ws uuid;
  v_me uuid;
  v_credit public.ledger_entries;
  v_done public.ledger_credit_moves;
  v_reason text := left(btrim(coalesce(p_reason, '')), 300);
  v_to public.members;
  v_to_name text;
  v_reversal uuid;
  v_new uuid;
  v_move uuid;
  v_day date;
begin
  -- Authorised first, locked after: an unknown credit reads as one the
  -- caller may not act on.
  select workspace_id into v_ws from public.ledger_entries where id = p_credit_id;
  if v_ws is null then raise exception 'you may not move this credit' using errcode = '42501'; end if;
  v_me := public.bank_import_actor(v_ws, 'issueInvoices');
  if p_request_id is null then
    raise exception 'a request id is required' using errcode = '22023';
  end if;
  select * into v_credit from public.ledger_entries where id = p_credit_id for update;
  -- The same request again answers what it answered and changes nothing.
  select * into v_done from public.ledger_credit_moves
   where workspace_id = v_ws and request_id = p_request_id;
  if v_done.id is not null then
    if v_done.from_credit_id <> p_credit_id or v_done.to_member_id <> p_to_member_id then
      raise exception 'this request id was already used for a different request' using errcode = '22023';
    end if;
    return jsonb_build_object('id', v_done.id, 'reversal_id', v_done.reversal_ledger_id,
      'credit_id', v_done.to_credit_id, 'replayed', true);
  end if;
  if v_reason = '' then raise exception 'a reason is required' using errcode = '22023'; end if;
  if v_credit.kind <> 'credit' or v_credit.category <> 'payment' then
    raise exception 'only a payment credit is moved' using errcode = '22023';
  end if;
  if exists (select 1 from public.ledger_credit_moves m where m.from_credit_id = p_credit_id
                                                       or m.reversal_ledger_id = p_credit_id) then
    raise exception 'this credit was already moved' using errcode = '22023';
  end if;
  if exists (select 1 from public.invoice_match_payments p
              where p.payment_ledger_id = p_credit_id or p.credit_ledger_id = p_credit_id)
     or exists (select 1 from public.invoice_matches m
                 where m.payment_ledger_id = p_credit_id or m.credit_ledger_id = p_credit_id) then
    raise exception 'this credit pays an invoice: undo the match first' using errcode = '22023';
  end if;
  if p_to_member_id = v_credit.member_id then
    raise exception 'the credit is already on this member' using errcode = '22023';
  end if;
  select * into v_to from public.members
   where id = p_to_member_id and workspace_id = v_ws;
  if v_to.id is null or v_to.status = 'exited' then
    raise exception 'unknown or departed member' using errcode = '22023';
  end if;
  if exists (select 1 from public.invoices i
              where i.member_id = v_credit.member_id and i.period = v_credit.period
                and i.voided_at is null) then
    raise exception 'this month is already invoiced to the member: correct that invoice first'
      using errcode = '22023';
  end if;
  v_day := coalesce(v_credit.occurred_on, public.book_local_day(v_ws, v_credit.created_at));
  if public.book_period_closed(v_ws, v_day) then
    raise exception 'this credit is dated inside a closed period of the books' using errcode = '22023';
  end if;

  v_to_name := coalesce(nullif(v_to.managed_name, ''),
                        (select nullif(btrim(concat_ws(' ', p.first_name, p.last_name)), '')
                           from public.profiles p where p.id = v_to.user_id), '');
  insert into public.ledger_entries
    (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
  values (v_ws, v_credit.member_id, 'charge', 'adjustment', v_credit.amount_cents,
          left('Payment moved to ' || coalesce(nullif(v_to_name, ''), 'another member') || ': ' || v_reason, 200),
          v_credit.period, v_day)
  returning id into v_reversal;
  insert into public.ledger_entries
    (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
  values (v_ws, p_to_member_id, 'credit', 'payment', v_credit.amount_cents,
          v_credit.description, v_credit.period, v_day)
  returning id into v_new;
  insert into public.ledger_credit_moves
    (workspace_id, from_credit_id, reversal_ledger_id, to_credit_id, from_member_id, to_member_id,
     amount_cents, reason, request_id, actor_member_id)
  values (v_ws, p_credit_id, v_reversal, v_new, v_credit.member_id, p_to_member_id,
          v_credit.amount_cents, v_reason, p_request_id, v_me)
  returning id into v_move;
  -- The bank line that brought this money now names the right credit.
  update public.bank_statement_lines set payment_ledger_id = v_new
   where workspace_id = v_ws and payment_ledger_id = p_credit_id;
  return jsonb_build_object('id', v_move, 'reversal_id', v_reversal, 'credit_id', v_new, 'replayed', false);
end;
$fn$;
revoke execute on function public.move_payment_credit_v1(uuid, uuid, text, uuid) from public, anon;
grant execute on function public.move_payment_credit_v1(uuid, uuid, text, uuid) to authenticated;

-- A moved credit and its reversal cancel each other: neither is a line of
-- an invoice (the same rule as a credit consumed by a match).
do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.invoice_lines_for(uuid,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$     where le.member_id = p_member_id
       and le.period = p_period$a$,
    $a$     where le.member_id = p_member_id
       and le.period = p_period
       and not exists (select 1 from public.ledger_credit_moves mv
                        where le.id in (mv.from_credit_id, mv.reversal_ledger_id))$a$);
  if v_def is null then raise exception '0688: invoice_lines_for anchor missing'; end if;
  execute v_def;
end
$migration$;

select public.set_deskilo_schema_version(688);
