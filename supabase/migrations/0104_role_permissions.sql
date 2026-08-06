-- SPDX-License-Identifier: 0BSD
-- #513 — CENTRALIZED role management. One permission catalog, one
-- matrix per workspace (role → granted permissions), one helper every
-- gate consults:
--   · the OWNER always holds every permission — not stored, not
--     editable;
--   · an ACTIVE co-owner defaults to all of them ("co-owner can have
--     less" — the owner may remove some);
--   · an admin defaults to today's admin abilities; the legacy
--     adminInvoicing feature flag keeps granting issueInvoices for
--     compatibility;
--   · a plain member defaults to none.
-- An absent role key in role_permissions means "the defaults" — a
-- workspace that never opens the matrix behaves exactly as before.
-- match_invoice/create_invoice bodies generated from 0103/0072.

alter table public.workspaces
  add column if not exists role_permissions jsonb not null default '{}'::jsonb;

create or replace function public.has_permission(ws uuid, perm text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.members m
    join public.workspaces w on w.id = ws
    where m.workspace_id = ws and m.user_id = auth.uid()
      and m.status = 'active'
      and (
        m.is_owner
        or (m.co_owner = 'active' and (
              case when w.role_permissions ? 'co_owner'
                   then w.role_permissions->'co_owner' ? perm
                   else true end))
        or (m.is_admin and (
              (case when w.role_permissions ? 'admin'
                    then w.role_permissions->'admin' ? perm
                    else perm in ('manageMembers','manageDocuments',
                                  'manageServices','approveExpenses',
                                  'viewFinances') end)
              or (perm = 'issueInvoices'
                  and coalesce(w.feature_flags -> 'adminInvoicing'
                                 = to_jsonb(true), false))))
        or (not m.is_admin and not m.is_owner and m.co_owner <> 'active'
            and w.role_permissions ? 'member'
            and w.role_permissions->'member' ? perm)
      )
  );
$$;
revoke execute on function public.has_permission(uuid, text) from public, anon;

-- The owner (or whoever holds manageRoles) shapes the matrix. The
-- 'owner' row does not exist: owners always hold everything.
create or replace function public.set_role_permissions(
  p_workspace_id uuid,
  p_role text,
  p_permissions text[]
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_catalog text[] := array[
    'manageRoles','manageMembers','manageValidation','workspaceSettings',
    'issueInvoices','viewFinances','manageDocuments','manageServices',
    'approveExpenses'];
  v_perm text;
begin
  if not public.has_permission(p_workspace_id, 'manageRoles') then
    raise exception 'only role managers may edit permissions';
  end if;
  if p_role not in ('co_owner','admin','member') then
    raise exception 'unknown role';
  end if;
  foreach v_perm in array coalesce(p_permissions, '{}') loop
    if not (v_perm = any(v_catalog)) then
      raise exception 'unknown permission %', v_perm;
    end if;
  end loop;
  update public.workspaces
    set role_permissions = jsonb_set(
      coalesce(role_permissions, '{}'::jsonb),
      array[p_role],
      coalesce(to_jsonb(p_permissions), '[]'::jsonb))
    where id = p_workspace_id;
end;
$$;
revoke execute on function public.set_role_permissions(uuid, text, text[])
  from public, anon;

create or replace function public.match_invoice(
  p_invoice_id uuid,
  p_payment_ledger_id uuid,
  p_resolution text,
  p_note text default ''
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_invoice public.invoices;
  v_existing public.invoice_matches;
  v_payment public.ledger_entries;
  v_paid int;
  v_due int;
  v_actor public.members;
  v_actor_name text;
  v_note text := btrim(coalesce(p_note, ''));
  v_has_policy boolean;
  v_event_id uuid;
  v_credit_id uuid := null;
  v_additional boolean := false;
begin
  select * into v_invoice from public.invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'unknown invoice'; end if;
  if v_invoice.voided_at is not null then
    raise exception 'invoice is voided';
  end if;
  select * into v_existing from public.invoice_matches
    where invoice_id = p_invoice_id;
  if v_existing.invoice_id is not null then
    -- #506 — only a STANDING partial (not written off) accepts more.
    if v_existing.status <> 'confirmed'
       or v_existing.resolution <> 'under_accepted'
       or v_existing.writeoff_at is not null then
      raise exception 'invoice already matched';
    end if;
    v_additional := true;
    v_due := v_invoice.total_cents - v_existing.paid_cents;
  else
    v_due := v_invoice.total_cents;
  end if;
  select * into v_actor from public.members
    where workspace_id = v_invoice.workspace_id and user_id = auth.uid()
      and status = 'active' and (is_admin or is_owner);
  if v_actor.id is null then raise exception 'not an admin of this workspace'; end if;
  -- #513 — the CENTRAL permission decides: owner always passes,
  -- co-owner/admin/member per the workspace's role matrix; the
  -- legacy adminInvoicing flag keeps granting inside
  -- has_permission for compatibility.
  if not public.has_permission(v_invoice.workspace_id, 'issueInvoices') then
    raise exception 'admins may not issue invoices here';
  end if;

  -- #512 — settlement sources: registered payments AND account credits
  -- (category 'adjustment': credit-note excess) — the imputation of an
  -- avoir on any outstanding invoice, past months included.
  select * into v_payment from public.ledger_entries
    where id = p_payment_ledger_id
      and workspace_id = v_invoice.workspace_id
      and member_id = v_invoice.member_id
      and kind = 'credit' and category in ('payment', 'adjustment');
  if v_payment.id is null then raise exception 'unknown payment'; end if;
  -- A credit already BAKED into an issued invoice (negative line at
  -- derivation) was spent there — it cannot settle a second document.
  if exists (
    select 1 from public.invoices i
    where i.member_id = v_invoice.member_id
      and i.period = v_payment.period
      and i.voided_at is null
      and i.issued_at > v_payment.created_at) then
    raise exception 'credit already deducted on an issued invoice';
  end if;
  if exists (select 1 from public.invoice_match_payments
              where payment_ledger_id = p_payment_ledger_id) then
    raise exception 'payment already matched';
  end if;
  v_paid := v_payment.amount_cents;

  if p_resolution not in
      ('exact','over_forced','over_credit_note','under_accepted') then
    raise exception 'unknown resolution';
  end if;
  -- All amount rules compare against what is STILL DUE (#506).
  if p_resolution = 'exact' and v_paid <> v_due then
    raise exception 'amount does not match the invoice';
  end if;
  if p_resolution in ('over_forced','over_credit_note')
     and v_paid <= v_due then
    raise exception 'amount does not exceed the invoice';
  end if;
  if p_resolution = 'under_accepted' and v_paid >= v_due then
    raise exception 'amount is not below the invoice';
  end if;
  if p_resolution in ('over_forced','under_accepted') and v_note = '' then
    raise exception 'a note is required';
  end if;

  select coalesce(display_name, '') into v_actor_name
    from public.profiles where id = v_actor.user_id;

  if p_resolution = 'over_credit_note' then
    insert into public.ledger_entries
      (workspace_id, member_id, kind, category, amount_cents,
       description, period)
    values
      (v_invoice.workspace_id, v_invoice.member_id, 'credit',
       'adjustment', v_paid - v_due,
       'Credit note ' || v_invoice.number
         || case when v_note = '' then '' else ' — ' || v_note end,
       to_char(now(), 'YYYY-MM'))
    returning id into v_credit_id;
  end if;

  v_has_policy := exists (
    select 1 from public.validation_policies vp
    where vp.workspace_id = v_invoice.workspace_id
      and vp.event_type = 'invoice_payment');

  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     payload, status, decided_at)
  values
    (v_invoice.workspace_id, 'invoice_payment', 'submitted',
     v_actor.id, v_invoice.member_id,
     jsonb_build_object(
       'invoice_id', v_invoice.id,
       'number', v_invoice.number,
       'due_cents', v_due,
       'paid_cents', v_paid,
       'amount_cents', v_paid,
       'payment_ledger_id', p_payment_ledger_id,
       'resolution', p_resolution,
       'note', v_note,
       'additional', v_additional),
     case when v_has_policy then 'pending' else 'confirmed' end,
     case when v_has_policy then null else now() end)
  returning id into v_event_id;

  -- The junction row reserves the payment even while pending.
  insert into public.invoice_match_payments
    (workspace_id, invoice_id, payment_ledger_id, amount_cents,
     resolution, note, event_id, credit_ledger_id, by_name)
  values
    (v_invoice.workspace_id, p_invoice_id, p_payment_ledger_id, v_paid,
     p_resolution, v_note, v_event_id, v_credit_id, v_actor_name);

  if v_additional then
    -- The aggregate moves only when the payment stands.
    if not v_has_policy then
      update public.invoice_matches
        set paid_cents = paid_cents + v_paid,
            resolution = p_resolution,
            note = case when v_note = '' then note else v_note end,
            payment_ledger_id = p_payment_ledger_id,
            credit_ledger_id = coalesce(v_credit_id, credit_ledger_id),
            matched_at = now(),
            by_name = v_actor_name
        where invoice_id = p_invoice_id;
    end if;
  else
    insert into public.invoice_matches
      (workspace_id, invoice_id, paid_cents, resolution, note, status,
       event_id, credit_ledger_id, payment_ledger_id, by_name)
    values
      (v_invoice.workspace_id, p_invoice_id, v_paid, p_resolution,
       v_note, case when v_has_policy then 'pending' else 'confirmed' end,
       v_event_id, v_credit_id, p_payment_ledger_id, v_actor_name);
  end if;
end;
$$;
revoke execute on function public.match_invoice(uuid, uuid, text, text) from public, anon;

create or replace function public.create_invoice(
  p_workspace_id uuid,
  p_member_id uuid,
  p_period text,
  p_replaces uuid default null,
  p_detailed boolean default false
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_subject public.members;
  v_workspace public.workspaces;
  v_replaced public.invoices;
  v_replaces_number text := '';
  v_lines jsonb;
  v_details jsonb := null;
  v_parties jsonb;
  v_vat_totals jsonb;
  v_zero_category text;
  v_tz text;
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_total int := 0;
  v_count int;
  v_number text;
  v_member_name text;
  v_member_address text;
  v_member_country text;
  v_member_vat text;
  v_issuer_name text;
  v_id uuid;
  v_signature text;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid()
      and status = 'active' and (is_admin or is_owner);
  if v_actor.id is null then raise exception 'not an admin of this workspace'; end if;
  -- #513 — the CENTRAL permission decides: owner always passes,
  -- co-owner/admin/member per the workspace's role matrix; the
  -- legacy adminInvoicing flag keeps granting inside
  -- has_permission for compatibility.
  if not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'admins may not issue invoices here';
  end if;

  select * into v_subject from public.members
    where id = p_member_id and workspace_id = p_workspace_id
      and status = 'active' and not is_kiosk;
  if v_subject.id is null then raise exception 'unknown subject member'; end if;
  if p_period is null or p_period !~ '^[0-9]{4}-[0-9]{2}$' then
    raise exception 'invalid period';
  end if;
  if exists (
    select 1 from public.invoices i
    where i.member_id = v_subject.id and i.period = p_period
      and i.voided_at is null and i.id is distinct from p_replaces
  ) then
    raise exception 'period already invoiced for this member';
  end if;

  v_lines := public.invoice_lines_for(p_member_id, p_period);
  if jsonb_array_length(v_lines) = 0 then
    raise exception 'nothing to invoice for this period';
  end if;
  select coalesce(sum((l->>'amount_cents')::int), 0) into v_total
    from jsonb_array_elements(v_lines) l;

  select * into v_workspace from public.workspaces where id = p_workspace_id;
  select coalesce(display_name, ''), coalesce(address, ''),
         coalesce(country_code, ''), coalesce(vat_id, '')
    into v_member_name, v_member_address, v_member_country, v_member_vat
    from public.profiles where id = v_subject.user_id;
  select coalesce(display_name, '') into v_issuer_name
    from public.profiles where id = v_actor.user_id;

  -- A 0% line is categorised by the workspace's declared regime, exactly
  -- as before VAT existed: outside the scope, or exempt.
  v_zero_category := case coalesce(v_workspace.vat_regime, 'not_subject')
                       when 'exempt' then 'E' else 'O' end;

  -- One entry per rate. Charges only: a credit is money moving.
  with charges as (
    select coalesce((l->>'vat_percent')::numeric, 0) as percent,
           (l->>'amount_cents')::int as gross,
           round((l->>'amount_cents')::int * 100.0
                 / (100 + coalesce((l->>'vat_percent')::numeric, 0)))::int as net
      from jsonb_array_elements(v_lines) l
     where (l->>'amount_cents')::int > 0
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'percent', percent,
      'category', case when percent > 0 then 'S' else v_zero_category end,
      'gross_cents', gross,
      'net_cents', net,
      'vat_cents', gross - net) order by percent desc), '[]'::jsonb)
    into v_vat_totals
    from (
      select percent, sum(gross)::int as gross, sum(net)::int as net
        from charges group by percent
    ) grouped;

  v_parties := jsonb_build_object(
    'seller', jsonb_build_object(
      'name', v_workspace.name,
      'street', coalesce(nullif(v_workspace.street, ''),
                         coalesce(v_workspace.address, '')),
      'city', coalesce(v_workspace.city, ''),
      'postal_code', coalesce(v_workspace.postal_code, ''),
      'country', v_workspace.country_code,
      'vat_id', coalesce(v_workspace.vat_id, ''),
      'legal_id', coalesce(v_workspace.legal_id, ''),
      'vat_regime', coalesce(v_workspace.vat_regime, 'not_subject'),
      'tax_exemption_reason',
        coalesce(v_workspace.tax_exemption_reason, '')),
    'buyer', jsonb_build_object(
      'name', v_member_name,
      'street', v_member_address,
      'country', coalesce(nullif(v_member_country, ''),
                          v_workspace.country_code),
      'vat_id', v_member_vat));

  if p_detailed then
    v_tz := v_workspace.timezone;
    v_period_start := to_timestamp(p_period || '-01', 'YYYY-MM-DD') at time zone v_tz;
    v_period_end := (to_timestamp(p_period || '-01', 'YYYY-MM-DD') + interval '1 month') at time zone v_tz;
    v_details := jsonb_build_object(
      'ledger', coalesce((
        select jsonb_agg(jsonb_build_object(
            'on', coalesce(le.occurred_on, le.created_at::date)::text,
            'category', le.category,
            'description', le.description,
            'amount_cents', case when le.kind = 'credit'
                                 then -le.amount_cents
                                 else le.amount_cents end)
          order by coalesce(le.occurred_on, le.created_at::date), le.created_at)
        from public.ledger_entries le
        where le.member_id = p_member_id and le.period = p_period
      ), '[]'::jsonb),
      'attendance', coalesce((
        select jsonb_agg(jsonb_build_object(
            'starts_at', to_char(r.starts_at at time zone v_tz,
                                 'YYYY-MM-DD"T"HH24:MI'),
            'ends_at', to_char(r.ends_at at time zone v_tz,
                               'YYYY-MM-DD"T"HH24:MI'),
            'status', r.status,
            'space', coalesce(
              (select s.name || ' · ' || d.name
                 from public.seats s
                 join public.desks d on d.id = s.desk_id
                where s.id = r.seat_id),
              (select d.name from public.desks d where d.id = r.desk_id),
              (select o.name from public.offices o where o.id = r.office_id),
              (select l.name from public.levels l where l.id = r.level_id),
              ''))
          order by r.starts_at)
        from public.reservations r
        where r.member_id = p_member_id
          and r.status in ('reserved', 'checked_in', 'completed')
          and r.starts_at >= v_period_start and r.starts_at < v_period_end
      ), '[]'::jsonb));
  end if;

  if p_replaces is not null then
    select * into v_replaced from public.invoices
      where id = p_replaces and workspace_id = p_workspace_id;
    if v_replaced.id is null then raise exception 'unknown invoice'; end if;
    if exists (select 1 from public.invoices
                where replaces_invoice_id = p_replaces) then
      raise exception 'invoice already replaced';
    end if;
    if exists (select 1 from public.invoice_matches
                where invoice_id = p_replaces) then
      raise exception 'invoice is matched';
    end if;
    if v_replaced.voided_at is null then
      update public.invoices
         set voided_at = now(), voided_by_name = v_issuer_name
       where id = p_replaces;
    end if;
    v_replaces_number := v_replaced.number;
  end if;

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
      v_replaces_number, coalesce(v_details::text, ''),
      v_parties::text, v_vat_totals::text),
      'UTF8'), 'sha256'), 'hex');

  insert into public.invoices
    (id, workspace_id, member_id, issuer_member_id, number, period, title,
     lines, total_cents, currency, member_name, member_address,
     workspace_name, workspace_address, issuer_name, signature,
     replaces_invoice_id, replaces_number, details, parties, vat_totals)
  values
    (v_id, p_workspace_id, v_subject.id, v_actor.id, v_number, p_period,
     p_period, v_lines, v_total, v_workspace.currency_code,
     v_member_name, v_member_address, v_workspace.name,
     coalesce(v_workspace.address, ''), v_issuer_name, v_signature,
     p_replaces, v_replaces_number, v_details, v_parties, v_vat_totals);
  return v_id;
end;
$$;
revoke execute on function public.create_invoice(uuid, uuid, text, uuid, boolean) from public, anon;
