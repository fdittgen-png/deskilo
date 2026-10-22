-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0516 (#2575) -- a bill above the rent a contract expects is a decision,
-- never absorbed in silence.
--
-- Matching (0479) allocates a bill line to an occurrence up to what the
-- occurrence expects: a lessor billing 1 050 against 1 000 leaves 50 of the
-- line unallocated, and next month's 1 000 is untouched. Accepting that 50 is
-- the `commitment_variance` decision:
--
--   * `accept_commitment_variance_v1`: managePurchases while `purchases` and
--     `premisesLease` or `externalRooms` are on. The occurrence is a fully
--     matched contract occurrence of the bill's lessor; the amount is at most
--     what is left of the line; a reason is required. It writes a `variance`
--     row (one per occurrence and line) beside the matches, so the history
--     shows the expectation, the bill and the accepted difference apart. The
--     lease, its terms and every other occurrence stay as they are.
--   * Held by the space's validators when it gives the new
--     `commitment_variance` domain a policy (its minimum is the difference):
--     the request answers pending with its event, and the confirmation writes
--     the row as the requester, re-checking the caps (AFTER UPDATE trigger on
--     events, the 0151 idiom). A rejection writes nothing.
--   * A variance is reversed like a match (`reverse_commitment_match_v1`).
--   * The commitments page lists variance rows with their kind and reason.

alter table public.events drop constraint if exists events_type_check;
alter table public.events add constraint events_type_check check (type = any (array[
  'reservation','payment','expense','adjustment','service_charge','quota','role_change','member_join','space_reservation',
  'invoice_payment','reservation_delete','invoice_writeoff','invoice_reminder','price_negotiation','expense_schedule',
  'expense_repartition','usage_correction','usage_record_delete','payment_terms_change',
  'invoice_issue','invoice_void','refund','member_status_change','subscription_change','matrix_change','lease_change',
  'commitment_variance']));
alter table public.validation_policies drop constraint if exists validation_policies_event_type_check;
alter table public.validation_policies add constraint validation_policies_event_type_check check (event_type is null or event_type = any (array[
  'reservation','payment','expense','adjustment','service_charge','quota','role_change','member_join','space_reservation',
  'invoice_payment','reservation_delete','invoice_writeoff','invoice_reminder','price_negotiation','expense_schedule',
  'expense_repartition','usage_correction','usage_record_delete','payment_terms_change',
  'invoice_issue','invoice_void','refund','member_status_change','subscription_change','matrix_change','lease_change',
  'commitment_variance']));

create or replace function public.event_type_view_permissions(p_type text)
returns text[]
language sql
immutable
set search_path = public
as $fn$
  select case
    when p_type in ('payment', 'adjustment', 'service_charge', 'invoice_payment',
                    'invoice_writeoff', 'invoice_reminder', 'invoice_issue',
                    'invoice_void', 'refund', 'usage_correction', 'usage_record_delete')
      then array['viewFinances', 'issueInvoices']
    when p_type in ('expense', 'expense_schedule', 'expense_repartition')
      then array['approveExpenses', 'viewFinances']
    when p_type in ('reservation', 'space_reservation', 'reservation_delete')
      then array['manageReservations']
    when p_type = 'quota'
      then array['manageReservations', 'viewFinances', 'issueInvoices']
    when p_type in ('member_join', 'member_status_change', 'subscription_change', 'role_change')
      then array['manageMembers']
    when p_type = 'matrix_change'
      then array['manageRoles', 'manageMembers']
    when p_type = 'price_negotiation'
      then array['viewNegotiations']
    when p_type = 'payment_terms_change'
      then array['paymentTermsEdit', 'viewNegotiations']
    when p_type = 'lease_change'
      then array['manageLease', 'viewFinances']
    when p_type = 'commitment_variance'
      then array['managePurchases', 'viewFinances']
    else array['manageConfiguration']
  end;
$fn$;
revoke execute on function public.event_type_view_permissions(text) from public, anon;
grant execute on function public.event_type_view_permissions(text) to authenticated;

-- ── a variance row beside the matches ────────────────────────────────────
alter table public.purchase_commitment_matches drop constraint if exists purchase_commitment_matches_kind_check;
alter table public.purchase_commitment_matches
  add constraint purchase_commitment_matches_kind_check check (kind in ('match', 'reversal', 'variance'));
alter table public.purchase_commitment_matches drop constraint if exists purchase_commitment_matches_check;
alter table public.purchase_commitment_matches
  add constraint purchase_commitment_matches_check check ((kind in ('match', 'variance')) = (allocated_cents > 0));
create unique index if not exists purchase_commitment_matches_one_variance
  on public.purchase_commitment_matches (occurrence_id, purchase_line_id) where kind = 'variance';

-- Writes the accepted difference after checking it still fits; the caller
-- holds the workspace lock. Internal: the RPC and the confirmation call it.
create or replace function public.commitment_variance_write(
  p_workspace_id uuid, p_occurrence_id uuid, p_purchase_id uuid, p_line_no int, p_amount_cents bigint,
  p_reason text, p_request_id uuid, p_actor uuid
) returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  d public.purchase_documents;
  o public.expense_occurrences;
  s public.expense_schedules;
  l public.purchase_lines;
  v_occ_matched bigint;
  v_line_matched bigint;
  v_id uuid;
begin
  if p_amount_cents is null or p_amount_cents <= 0 then raise exception 'the difference must be positive'; end if;
  if btrim(coalesce(p_reason, '')) = '' then raise exception 'state why the difference is accepted'; end if;
  select * into d from public.purchase_documents
   where id = p_purchase_id and workspace_id = p_workspace_id for update;
  if d.id is null then raise exception 'unknown purchase'; end if;
  if d.kind <> 'bill' or d.state not in ('pending', 'approved') then
    raise exception 'only a supplier bill awaiting approval or approved is matched';
  end if;
  select * into o from public.expense_occurrences
   where id = p_occurrence_id and workspace_id = p_workspace_id for update;
  if o.id is null then raise exception 'unknown occurrence'; end if;
  select * into s from public.expense_schedules where id = o.schedule_id;
  if s.origin <> 'workspace_contract' then
    raise exception 'only the expected obligations of a contract are matched to a bill';
  end if;
  if s.supplier_id is distinct from d.supplier_id then
    raise exception 'the bill and the contract have the same lessor';
  end if;
  select * into l from public.purchase_lines where purchase_id = d.id and line_no = p_line_no for update;
  if l.id is null then raise exception 'unknown line of this bill'; end if;
  select coalesce(sum(x.allocated_cents), 0) into v_occ_matched
    from public.purchase_commitment_matches x where x.occurrence_id = o.id and x.kind <> 'variance'
      and not (x.kind = 'reversal' and exists (select 1 from public.purchase_commitment_matches v
                                                where v.id = x.original_match_id and v.kind = 'variance'));
  if v_occ_matched < o.amount_cents then
    raise exception 'match the occurrence in full before accepting a difference';
  end if;
  select coalesce(sum(x.allocated_cents), 0) into v_line_matched
    from public.purchase_commitment_matches x where x.purchase_line_id = l.id;
  if p_amount_cents > l.gross_cents - v_line_matched then
    raise exception 'the amount exceeds what is left of the line';
  end if;
  if exists (select 1 from public.purchase_commitment_matches x
              where x.occurrence_id = o.id and x.purchase_line_id = l.id and x.kind = 'variance'
                and not exists (select 1 from public.purchase_commitment_matches r where r.original_match_id = x.id)) then
    raise exception 'a difference is already accepted for this line';
  end if;
  insert into public.purchase_commitment_matches
    (workspace_id, occurrence_id, purchase_id, purchase_line_id, kind, allocated_cents, currency,
     reason, request_id, actor_member_id)
  values (p_workspace_id, o.id, d.id, l.id, 'variance', p_amount_cents, d.currency,
          left(btrim(p_reason), 300), p_request_id, p_actor)
  returning id into v_id;
  return v_id;
end;
$fn$;
revoke execute on function public.commitment_variance_write(uuid, uuid, uuid, int, bigint, text, uuid, uuid)
  from public, anon, authenticated;

create or replace function public.accept_commitment_variance_v1(
  p_workspace_id uuid, p_occurrence_id uuid, p_purchase_id uuid, p_line_no int, p_amount_cents bigint,
  p_reason text, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_event uuid;
  v_ref text;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select mem.id into v_me from public.members mem
   where mem.workspace_id = p_workspace_id and mem.user_id = auth.uid() and mem.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.feature_effective(p_workspace_id, 'purchases')
     or not (public.feature_effective(p_workspace_id, 'premisesLease')
             or public.feature_effective(p_workspace_id, 'externalRooms')) then
    raise exception 'purchases and the premises lease are switched off in this space';
  end if;
  if not public.has_permission(p_workspace_id, 'managePurchases') then
    raise exception 'you may not link supplier bills';
  end if;
  if p_request_id is null then raise exception 'a request id is required'; end if;
  v_digest := md5(v_me::text || p_occurrence_id::text || p_purchase_id::text || coalesce(p_line_no, 0)::text
                  || coalesce(p_amount_cents, 0)::text || btrim(coalesce(p_reason, '')));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'commitment_variance', v_digest);
  if v_done is not null then return v_done; end if;
  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));

  if public.validation_requires(p_workspace_id, 'commitment_variance', p_amount_cents::int) then
    -- Checked now, so a request that cannot be applied is never submitted;
    -- the confirmation checks again against what is there then.
    begin
      perform public.commitment_variance_write(p_workspace_id, p_occurrence_id, p_purchase_id, p_line_no,
        p_amount_cents, p_reason, p_request_id, v_me);
      raise exception using errcode = 'P0001', message = 'variance-dry-run';
    exception when others then
      if sqlerrm <> 'variance-dry-run' then raise; end if;
    end;
    select d.original_reference into v_ref from public.purchase_documents d where d.id = p_purchase_id;
    insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
    values (p_workspace_id, 'commitment_variance', 'submitted', v_me, v_me,
            jsonb_build_object('occurrence_id', p_occurrence_id, 'purchase_id', p_purchase_id,
                               'line_no', p_line_no, 'amount_cents', p_amount_cents,
                               'reason', left(btrim(p_reason), 300), 'reference', coalesce(v_ref, ''),
                               'due_on', (select o.due_on from public.expense_occurrences o where o.id = p_occurrence_id),
                               'request_id', p_request_id),
            'pending')
    returning id into v_event;
    return public.purchase_request_end(p_workspace_id, p_request_id, 'commitment_variance', v_digest,
      jsonb_build_object('pending', true, 'event_id', v_event));
  end if;

  v_id := public.commitment_variance_write(p_workspace_id, p_occurrence_id, p_purchase_id, p_line_no,
    p_amount_cents, p_reason, p_request_id, v_me);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'commitment_variance', v_digest,
    jsonb_build_object('variance_id', v_id));
end;
$fn$;
revoke execute on function public.accept_commitment_variance_v1(uuid, uuid, uuid, int, bigint, text, uuid)
  from public, anon;
grant execute on function public.accept_commitment_variance_v1(uuid, uuid, uuid, int, bigint, text, uuid)
  to authenticated;

-- The confirmation writes the difference as the member who asked for it.
create or replace function public.commitment_variance_apply()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if new.type <> 'commitment_variance' or new.status <> 'confirmed' or old.status = 'confirmed' then
    return new;
  end if;
  perform pg_advisory_xact_lock(hashtext(new.workspace_id::text));
  perform public.commitment_variance_write(new.workspace_id, (new.payload ->> 'occurrence_id')::uuid,
    (new.payload ->> 'purchase_id')::uuid, (new.payload ->> 'line_no')::int,
    (new.payload ->> 'amount_cents')::bigint, new.payload ->> 'reason',
    (new.payload ->> 'request_id')::uuid, new.actor_member_id);
  return new;
end;
$fn$;
revoke execute on function public.commitment_variance_apply() from public, anon, authenticated;
drop trigger if exists events_commitment_variance_apply on public.events;
create trigger events_commitment_variance_apply after update on public.events
  for each row execute function public.commitment_variance_apply();

-- ── a variance is reversed like a match ──────────────────────────────────
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text language plpgsql as $f$
begin
  if position(p_old in p_def) = 0 then return null; end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public, anon;

do $migration$
declare
  v_def text;
begin
  v_def := pg_temp.anchor_replace(
    pg_get_functiondef('public.reverse_commitment_match_v1(uuid, uuid, text, uuid)'::regprocedure),
    $a$  if x.kind <> 'match' then raise exception 'only a match is reversed'; end if;$a$,
    $a$  if x.kind not in ('match', 'variance') then raise exception 'only a match is reversed'; end if;$a$);
  if v_def is null then raise exception '0516: reverse_commitment_match_v1 anchor missing'; end if;
  execute v_def;
end
$migration$;

-- ── the page lists the accepted differences too ──────────────────────────
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
  -- p_lease_id names a workspace contract: a lease, or (0515) a rented room.
  if not exists (select 1 from public.premises_leases l where l.id = p_lease_id and l.workspace_id = p_workspace_id)
     and not exists (select 1 from public.room_rentals rr
                      where rr.id = p_lease_id and rr.workspace_id = p_workspace_id) then
    raise exception 'unknown lease';
  end if;

  with page as (
    select o.id, o.due_on, o.amount_cents, t.id as term_id,
           coalesce(t.kind, 'rent') as term_kind, coalesce(t.label, sc.title) as term_label
      from public.expense_occurrences o
      join public.expense_schedules sc on sc.id = o.schedule_id
      left join public.lease_terms t on t.schedule_id = o.schedule_id
     where sc.origin = 'workspace_contract' and sc.contract_id = p_lease_id
       and o.workspace_id = p_workspace_id
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
          'id', x.id, 'kind', x.kind, 'reason', x.reason,
          'purchase_id', x.purchase_id, 'line_id', x.purchase_line_id, 'line_no', pl.line_no,
          'reference', d.original_reference, 'allocated_cents', x.allocated_cents,
          'line_gross_cents', pl.gross_cents,
          'line_unallocated_cents', pl.gross_cents - coalesce((select sum(y.allocated_cents)
              from public.purchase_commitment_matches y where y.purchase_line_id = pl.id), 0),
          'reversed', exists (select 1 from public.purchase_commitment_matches r where r.original_match_id = x.id))
          order by x.created_datetime, x.id)
          from public.purchase_commitment_matches x
          join public.purchase_documents d on d.id = x.purchase_id
          join public.purchase_lines pl on pl.id = x.purchase_line_id
         where x.occurrence_id = s.id and x.kind in ('match', 'variance')), '[]'::jsonb))
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

select public.set_deskilo_schema_version(516);
