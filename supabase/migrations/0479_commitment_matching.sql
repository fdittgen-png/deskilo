-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0479 (#2575, C1) -- a supplier bill is matched to the rent the lease
-- already expects, and replaces it.
--
-- A lease term generates scheduled occurrences (0474) that are EXPECTED
-- obligations: never an outlay a member confirms, never a credit on a member
-- account. When the lessor's bill arrives it is matched to the occurrence(s)
-- it covers, line by line:
--
--   * `purchase_commitment_matches`: append-only. A match allocates part of a
--     bill line (`allocated_cents`) to an occurrence; a reversal is a row of
--     its own with the opposite sign, so a correction keeps its history. One
--     match per (occurrence, line); at most the occurrence's expected amount
--     on the occurrence side and at most the line's gross on the line side,
--     checked under the workspace lock. Partial bills (600 then 400), one
--     bill covering two months and a bill above the expectation (1 050
--     against 1 000: the line keeps 50 unallocated, the next month's
--     expectation is untouched) all follow from those two sums.
--   * `match_purchase_commitments_v1`: managePurchases while `purchases` and
--     `premisesLease` are on; the bill is a pending or approved supplier bill
--     of the lessor of the occurrences' schedule, in the space's currency;
--     request-id replay; a stale revision is refused.
--   * `reverse_commitment_match_v1`: a reason, once per match.
--   * `purchase_commitment_page_v1`: the occurrences of one lease with what
--     is expected, matched and left, and the bills behind each match.
--
-- Not here: the cash forecast (#2582), the deviation decision through
-- validation, the room rental commitments (#2568).

create table public.purchase_commitment_matches (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  occurrence_id uuid not null references public.expense_occurrences(id),
  purchase_id uuid not null,
  purchase_line_id uuid not null references public.purchase_lines(id),
  kind text not null default 'match' check (kind in ('match', 'reversal')),
  allocated_cents bigint not null check (allocated_cents <> 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  original_match_id uuid references public.purchase_commitment_matches(id),
  reason text not null default '' check (char_length(reason) <= 300),
  request_id uuid not null,
  actor_member_id uuid not null,
  foreign key (workspace_id, purchase_id) references public.purchase_documents (workspace_id, id),
  foreign key (workspace_id, actor_member_id) references public.members (workspace_id, id),
  check ((kind = 'match') = (allocated_cents > 0)),
  check ((kind = 'reversal') = (original_match_id is not null))
);
select public.ensure_system_columns('purchase_commitment_matches');
create unique index purchase_commitment_matches_one_pair
  on public.purchase_commitment_matches (occurrence_id, purchase_line_id) where kind = 'match';
create unique index purchase_commitment_matches_one_reversal
  on public.purchase_commitment_matches (original_match_id) where original_match_id is not null;
create index purchase_commitment_matches_occurrence on public.purchase_commitment_matches (occurrence_id);
create index purchase_commitment_matches_line on public.purchase_commitment_matches (purchase_line_id);

alter table public.purchase_commitment_matches enable row level security;
revoke all on public.purchase_commitment_matches from public, anon, authenticated;
grant select on public.purchase_commitment_matches to authenticated;
create policy purchase_commitment_matches_select on public.purchase_commitment_matches
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(
    array['viewFinances', 'managePurchases', 'manageLease'])));
create policy mcp_delegated_deny on public.purchase_commitment_matches as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create or replace function public.purchase_commitment_matches_guard()
returns trigger language plpgsql as $fn$
begin
  raise exception 'a commitment match is never edited or removed; reverse it';
end;
$fn$;
revoke execute on function public.purchase_commitment_matches_guard() from public, anon, authenticated;
create trigger purchase_commitment_matches_guard
  before update or delete on public.purchase_commitment_matches
  for each row execute function public.purchase_commitment_matches_guard();

-- ── match ───────────────────────────────────────────────────────────────
create or replace function public.match_purchase_commitments_v1(
  p_workspace_id uuid, p_purchase_id uuid, p_revision int, p_matches jsonb, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  d public.purchase_documents;
  v_currency text;
  m jsonb;
  o public.expense_occurrences;
  s public.expense_schedules;
  l public.purchase_lines;
  v_amount bigint;
  v_occ_matched bigint;
  v_line_matched bigint;
  v_ids uuid[] := '{}';
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select mem.id into v_me from public.members mem
   where mem.workspace_id = p_workspace_id and mem.user_id = auth.uid() and mem.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.feature_effective(p_workspace_id, 'purchases')
     or not public.feature_effective(p_workspace_id, 'premisesLease') then
    raise exception 'purchases and the premises lease are switched off in this space';
  end if;
  if not public.has_permission(p_workspace_id, 'managePurchases') then
    raise exception 'you may not link supplier bills';
  end if;
  if p_matches is null or jsonb_typeof(p_matches) <> 'array'
     or jsonb_array_length(p_matches) not between 1 and 50 then
    raise exception 'name between 1 and 50 occurrences to match';
  end if;
  v_digest := md5(v_me::text || p_purchase_id::text || coalesce(p_revision, 0)::text || p_matches::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'commitment_match', v_digest);
  if v_done is not null then return v_done; end if;
  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));

  select * into d from public.purchase_documents
   where id = p_purchase_id and workspace_id = p_workspace_id for update;
  if d.id is null then raise exception 'unknown purchase'; end if;
  if d.kind <> 'bill' or d.state not in ('pending', 'approved') then
    raise exception 'only a supplier bill awaiting approval or approved is matched';
  end if;
  if d.revision <> coalesce(p_revision, 0) then raise exception 'stale revision'; end if;
  if d.supplier_id is null then raise exception 'a bill needs its supplier'; end if;
  select w.currency_code into v_currency from public.workspaces w where w.id = p_workspace_id;
  if d.currency <> v_currency then raise exception 'the bill is in another currency than the space'; end if;

  for m in select value from jsonb_array_elements(p_matches) loop
    v_amount := (m ->> 'allocated_cents')::bigint;
    if v_amount is null or v_amount <= 0 then raise exception 'the allocated amount must be positive'; end if;
    select * into o from public.expense_occurrences
     where id = (m ->> 'occurrence_id')::uuid and workspace_id = p_workspace_id for update;
    if o.id is null then raise exception 'unknown occurrence'; end if;
    select * into s from public.expense_schedules where id = o.schedule_id;
    if s.origin <> 'workspace_contract' then
      raise exception 'only the expected obligations of a contract are matched to a bill';
    end if;
    if s.supplier_id is distinct from d.supplier_id then
      raise exception 'the bill and the contract have the same lessor';
    end if;
    -- a line is named by its id or, as the app reads a bill, by its number
    select * into l from public.purchase_lines
     where purchase_id = d.id
       and ((m ? 'purchase_line_id' and id = (m ->> 'purchase_line_id')::uuid)
            or (m ? 'line_no' and line_no = (m ->> 'line_no')::int))
     for update;
    if l.id is null then raise exception 'unknown line of this bill'; end if;
    select coalesce(sum(x.allocated_cents), 0) into v_occ_matched
      from public.purchase_commitment_matches x where x.occurrence_id = o.id;
    if v_amount > o.amount_cents - v_occ_matched then
      raise exception 'the amount exceeds what the occurrence still expects';
    end if;
    select coalesce(sum(x.allocated_cents), 0) into v_line_matched
      from public.purchase_commitment_matches x where x.purchase_line_id = l.id;
    if v_amount > l.gross_cents - v_line_matched then
      raise exception 'the amount exceeds what is left of the line';
    end if;
    insert into public.purchase_commitment_matches
      (workspace_id, occurrence_id, purchase_id, purchase_line_id, kind, allocated_cents,
       currency, request_id, actor_member_id)
    values (p_workspace_id, o.id, d.id, l.id, 'match', v_amount, d.currency, p_request_id, v_me)
    returning id into v_id;
    v_ids := v_ids || v_id;
  end loop;

  return public.purchase_request_end(p_workspace_id, p_request_id, 'commitment_match', v_digest,
    jsonb_build_object('purchase_id', d.id, 'match_ids', to_jsonb(v_ids)));
end;
$fn$;
revoke execute on function public.match_purchase_commitments_v1(uuid, uuid, int, jsonb, uuid) from public, anon;
grant execute on function public.match_purchase_commitments_v1(uuid, uuid, int, jsonb, uuid) to authenticated;

-- ── reverse ─────────────────────────────────────────────────────────────
create or replace function public.reverse_commitment_match_v1(
  p_workspace_id uuid, p_match_id uuid, p_reason text, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  x public.purchase_commitment_matches;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select mem.id into v_me from public.members mem
   where mem.workspace_id = p_workspace_id and mem.user_id = auth.uid() and mem.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.has_permission(p_workspace_id, 'managePurchases') then
    raise exception 'you may not link supplier bills';
  end if;
  if btrim(coalesce(p_reason, '')) = '' then raise exception 'state why the match is reversed'; end if;
  v_digest := md5(v_me::text || p_match_id::text || btrim(p_reason));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'commitment_reverse', v_digest);
  if v_done is not null then return v_done; end if;
  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));

  select * into x from public.purchase_commitment_matches
   where id = p_match_id and workspace_id = p_workspace_id;
  if x.id is null then raise exception 'unknown match'; end if;
  if x.kind <> 'match' then raise exception 'only a match is reversed'; end if;
  if exists (select 1 from public.purchase_commitment_matches r where r.original_match_id = x.id) then
    raise exception 'this match is already reversed';
  end if;
  insert into public.purchase_commitment_matches
    (workspace_id, occurrence_id, purchase_id, purchase_line_id, kind, allocated_cents, currency,
     original_match_id, reason, request_id, actor_member_id)
  values (x.workspace_id, x.occurrence_id, x.purchase_id, x.purchase_line_id, 'reversal', -x.allocated_cents,
          x.currency, x.id, left(btrim(p_reason), 300), p_request_id, v_me)
  returning id into v_id;
  return public.purchase_request_end(p_workspace_id, p_request_id, 'commitment_reverse', v_digest,
    jsonb_build_object('reversal_id', v_id, 'match_id', x.id));
end;
$fn$;
revoke execute on function public.reverse_commitment_match_v1(uuid, uuid, text, uuid) from public, anon;
grant execute on function public.reverse_commitment_match_v1(uuid, uuid, text, uuid) to authenticated;

-- ── the occurrences of a lease, with what is matched ────────────────────
create or replace function public.purchase_commitment_page_v1(
  p_workspace_id uuid, p_lease_id uuid, p_before date default null, p_limit int default 24
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_rows jsonb;
  v_next date;
  v_limit int := least(greatest(coalesce(p_limit, 24), 1), 100);
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not exists (select 1 from public.members mem
                  where mem.workspace_id = p_workspace_id and mem.user_id = auth.uid()
                    and mem.status = 'active') then
    raise exception 'not an active member';
  end if;
  if not (public.has_permission(p_workspace_id, 'viewFinances')
          or public.has_permission(p_workspace_id, 'managePurchases')
          or public.has_permission(p_workspace_id, 'manageLease')) then
    raise exception 'you may not read the commitments';
  end if;
  if not exists (select 1 from public.premises_leases l where l.id = p_lease_id and l.workspace_id = p_workspace_id) then
    raise exception 'unknown lease';
  end if;

  with page as (
    select o.id, o.due_on, o.amount_cents, t.id as term_id, t.kind as term_kind, t.label as term_label
      from public.expense_occurrences o
      join public.lease_terms t on t.schedule_id = o.schedule_id
     where t.lease_id = p_lease_id and o.workspace_id = p_workspace_id
       and (p_before is null or o.due_on < p_before)
     order by o.due_on desc, o.id
     limit v_limit + 1
  ), shown as (
    select * from page order by due_on desc, id limit v_limit
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', s.id, 'due_on', s.due_on, 'expected_cents', s.amount_cents,
      'term_id', s.term_id, 'term_kind', s.term_kind, 'term_label', s.term_label,
      'matched_cents', coalesce((select sum(x.allocated_cents) from public.purchase_commitment_matches x
                                  where x.occurrence_id = s.id), 0),
      'matches', coalesce((select jsonb_agg(jsonb_build_object(
          'id', x.id, 'purchase_id', x.purchase_id, 'line_id', x.purchase_line_id, 'line_no', pl.line_no,
          'reference', d.original_reference, 'allocated_cents', x.allocated_cents,
          'line_gross_cents', pl.gross_cents,
          'line_unallocated_cents', pl.gross_cents - coalesce((select sum(y.allocated_cents)
              from public.purchase_commitment_matches y where y.purchase_line_id = pl.id), 0),
          'reversed', exists (select 1 from public.purchase_commitment_matches r where r.original_match_id = x.id))
          order by x.created_datetime, x.id)
          from public.purchase_commitment_matches x
          join public.purchase_documents d on d.id = x.purchase_id
          join public.purchase_lines pl on pl.id = x.purchase_line_id
         where x.occurrence_id = s.id and x.kind = 'match'), '[]'::jsonb))
      order by s.due_on desc, s.id), '[]'::jsonb),
    case when (select count(*) from page) > v_limit then (select min(due_on) from shown) end
    into v_rows, v_next
    from shown s;
  return jsonb_build_object('occurrences', v_rows, 'next_before', v_next);
end;
$fn$;
revoke execute on function public.purchase_commitment_page_v1(uuid, uuid, date, int) from public, anon;
grant execute on function public.purchase_commitment_page_v1(uuid, uuid, date, int) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(479);
