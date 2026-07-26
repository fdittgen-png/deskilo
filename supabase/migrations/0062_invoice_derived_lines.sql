-- SPDX-License-Identifier: 0BSD
-- Invoice positions are DERIVED, never typed (field decision): the app
-- already tracks the subscription, consumption, supplements, services
-- and packages — the invoice is the payable summary of exactly that
-- month's positions. create_invoice therefore no longer accepts lines:
-- it builds them from member_statement + the period's confirmed ledger
-- charges, and creates NOTHING new. preview_invoice returns the same
-- lines without issuing, so the form can show what will be invoiced.
--
-- Line shape (structured, covered by the signature):
--   {"kind": text, "label": text, "quantity": int, "amount_cents": int}
-- kinds: subscription | overage | accessories | level | office | desk
--        | service | package | adjustment. The client renders localized
-- wording per kind; label carries data (pct, catalog names).

-- 1. The one line builder. Access control is inherited from
-- member_statement (admin of the workspace, or the member's own data —
-- it raises before anything else is read). Credits (payments, expense
-- reimbursements) are settlement, not positions; PENDING events are not
-- yet validated and are deliberately excluded — confirm them first.
create or replace function public.invoice_lines_for(
  p_member_id uuid,
  p_period text
) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_stmt jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_row record;
begin
  v_stmt := public.member_statement(p_member_id, p_period);

  if (v_stmt->>'fee_cents')::int > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'subscription',
      'label', v_stmt->>'subscription_pct',
      'quantity', 1,
      'amount_cents', (v_stmt->>'fee_cents')::int);
  end if;
  if (v_stmt->>'overage_cents')::int > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'overage',
      'label', '',
      'quantity', (v_stmt->>'extra_half_days')::int,
      'amount_cents', (v_stmt->>'overage_cents')::int);
  end if;
  if coalesce((v_stmt->>'accessory_supplement_cents')::int, 0) > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'accessories', 'label', '', 'quantity', 1,
      'amount_cents', (v_stmt->>'accessory_supplement_cents')::int);
  end if;
  if coalesce((v_stmt->>'level_supplement_cents')::int, 0) > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'level', 'label', '', 'quantity', 1,
      'amount_cents', (v_stmt->>'level_supplement_cents')::int);
  end if;
  if coalesce((v_stmt->>'office_supplement_cents')::int, 0) > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'office', 'label', '', 'quantity', 1,
      'amount_cents', (v_stmt->>'office_supplement_cents')::int);
  end if;
  if coalesce((v_stmt->>'desk_supplement_cents')::int, 0) > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'desk', 'label', '', 'quantity', 1,
      'amount_cents', (v_stmt->>'desk_supplement_cents')::int);
  end if;

  -- Confirmed charge positions booked to the period, in booking order:
  -- consumed services, day packages, charging adjustments.
  for v_row in
    select category, description, amount_cents
      from public.ledger_entries
     where member_id = p_member_id
       and period = p_period
       and kind = 'charge'
       and category in ('service', 'package', 'adjustment')
     order by created_at
  loop
    v_lines := v_lines || jsonb_build_object(
      'kind', v_row.category,
      'label', v_row.description,
      'quantity', 1,
      'amount_cents', v_row.amount_cents);
  end loop;

  return v_lines;
end;
$$;
revoke execute on function public.invoice_lines_for(uuid, text)
  from public, anon;

-- 2. Preview: what create_invoice would issue, without issuing.
create or replace function public.preview_invoice(
  p_workspace_id uuid,
  p_member_id uuid,
  p_period text
) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_lines jsonb;
  v_total int;
begin
  if not exists (
    select 1 from public.members
     where id = p_member_id and workspace_id = p_workspace_id
  ) then
    raise exception 'unknown subject member';
  end if;
  v_lines := public.invoice_lines_for(p_member_id, p_period);
  select coalesce(sum((l->>'amount_cents')::int), 0) into v_total
    from jsonb_array_elements(v_lines) l;
  return jsonb_build_object('lines', v_lines, 'total_cents', v_total);
end;
$$;
revoke execute on function public.preview_invoice(uuid, uuid, text)
  from public, anon;

-- 3. create_invoice v3: member + period only. Title/period both carry
-- the period; positions come from invoice_lines_for. An empty month
-- refuses with a pinned error (nothing tracked = nothing to invoice).
drop function public.create_invoice(uuid, uuid, text, jsonb, text, uuid);
create function public.create_invoice(
  p_workspace_id uuid,
  p_member_id uuid,
  p_period text,
  p_replaces uuid default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_subject public.members;
  v_workspace public.workspaces;
  v_replaced public.invoices;
  v_replaces_number text := '';
  v_lines jsonb;
  v_total int := 0;
  v_count int;
  v_number text;
  v_member_name text;
  v_member_address text;
  v_issuer_name text;
  v_id uuid;
  v_signature text;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid()
      and status = 'active' and (is_admin or is_owner);
  if v_actor.id is null then raise exception 'not an admin of this workspace'; end if;
  if not public.is_owner_of(p_workspace_id) and not coalesce(
    (select w.feature_flags -> 'adminInvoicing' = to_jsonb(true)
       from public.workspaces w where w.id = p_workspace_id), false) then
    raise exception 'admins may not issue invoices here';
  end if;

  select * into v_subject from public.members
    where id = p_member_id and workspace_id = p_workspace_id
      and status = 'active' and not is_kiosk;
  if v_subject.id is null then raise exception 'unknown subject member'; end if;
  if p_period is null or p_period !~ '^[0-9]{4}-[0-9]{2}$' then
    raise exception 'invalid period';
  end if;

  -- The positions: exclusively what the month already tracked.
  v_lines := public.invoice_lines_for(p_member_id, p_period);
  if jsonb_array_length(v_lines) = 0 then
    raise exception 'nothing to invoice for this period';
  end if;
  select coalesce(sum((l->>'amount_cents')::int), 0) into v_total
    from jsonb_array_elements(v_lines) l;

  select * into v_workspace from public.workspaces where id = p_workspace_id;
  select coalesce(display_name, ''), coalesce(address, '')
    into v_member_name, v_member_address
    from public.profiles where id = v_subject.user_id;
  select coalesce(display_name, '') into v_issuer_name
    from public.profiles where id = v_actor.user_id;

  if p_replaces is not null then
    select * into v_replaced from public.invoices
      where id = p_replaces and workspace_id = p_workspace_id;
    if v_replaced.id is null then raise exception 'unknown invoice'; end if;
    if exists (select 1 from public.invoices
                where replaces_invoice_id = p_replaces) then
      raise exception 'invoice already replaced';
    end if;
    if v_replaced.voided_at is null then
      update public.invoices
         set voided_at = now(), voided_by_name = v_issuer_name
       where id = p_replaces;
    end if;
    v_replaces_number := v_replaced.number;
  end if;

  -- Per-workspace/year sequence under an advisory lock.
  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));
  select count(*) into v_count from public.invoices
    where workspace_id = p_workspace_id
      and date_part('year', issued_at) = date_part('year', now());
  v_number := 'INV-' || date_part('year', now())::int || '-'
      || lpad((v_count + 1)::text, 4, '0');

  v_id := gen_random_uuid();
  v_signature := encode(extensions.digest(convert_to(concat_ws('|',
      v_id::text, v_number, p_workspace_id::text, v_subject.id::text,
      v_member_name, v_member_address, v_workspace.name,
      coalesce(v_workspace.address, ''), v_issuer_name,
      p_period, v_lines::text, v_total::text, v_workspace.currency_code,
      now()::date::text, coalesce(p_replaces::text, ''),
      v_replaces_number), 'UTF8'), 'sha256'), 'hex');

  insert into public.invoices
    (id, workspace_id, member_id, issuer_member_id, number, period, title,
     lines, total_cents, currency, member_name, member_address,
     workspace_name, workspace_address, issuer_name, signature,
     replaces_invoice_id, replaces_number)
  values
    (v_id, p_workspace_id, v_subject.id, v_actor.id, v_number, p_period,
     p_period, v_lines, v_total, v_workspace.currency_code,
     v_member_name, v_member_address, v_workspace.name,
     coalesce(v_workspace.address, ''), v_issuer_name, v_signature,
     p_replaces, v_replaces_number);
  return v_id;
end;
$$;
revoke execute on function
  public.create_invoice(uuid, uuid, text, uuid)
  from public, anon;
