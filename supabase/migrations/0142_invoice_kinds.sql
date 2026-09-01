-- SPDX-License-Identifier: 0BSD
-- #802 — the subscription is invoiced BEFORE the month it pays for, and
-- what the month actually cost is invoiced after it.
--
-- Until now a month produced exactly one invoice, issued by hand once the
-- month was over, carrying the subscription and everything else together.
-- That is the wrong shape for a subscription: a member pays for a month in
-- advance, so the document has to exist before the month starts — and the
-- extras (overage, accessories, services, packages, adjustments) cannot be
-- known until it ends.
--
-- An invoice therefore gains a KIND:
--
--   subscription  the monthly fee, issued ahead of the period it covers
--   usage         everything else, issued once that period is over
--   full          the historical whole-month document — every existing
--                 row, and still what issuing by hand produces
--
-- The PERIOD stays the month the invoice is about, never the month it was
-- issued in: a subscription invoice cut on 28 August for September carries
-- '2025-09'. Anything else would make a member's statement disagree with
-- the document that charged them.
--
-- Configurable per workspace (workspaces.billing_rules):
--   subscription_auto          bool  issue subscription invoices on a clock
--   subscription_advance_days  int   how many days before the month starts
--   usage_auto                 bool  issue the difference invoice on a clock
--   usage_when_zero            bool  issue it even when nothing is owed, so
--                                    the member gets the confirmation that
--                                    the month cost them nothing extra
--
-- Dunning needs no change: sweep_payment_reminders already walks every
-- unmatched invoice with a positive total, so both new kinds are chased
-- the day they fall due, exactly like any other invoice.

-- ---------------------------------------------------------------- the kind
alter table public.invoices
  add column if not exists kind text not null default 'full';

alter table public.invoices drop constraint if exists invoices_kind_check;
alter table public.invoices add constraint invoices_kind_check
  check (kind in ('full', 'subscription', 'usage', 'settlement'));

-- One live invoice per member per period PER KIND. The old rule lived only
-- inside create_invoice; a subscription and a usage invoice for the same
-- month are two documents by design, and a duplicate of either is not.
create unique index if not exists invoices_member_period_kind_uniq
  on public.invoices (member_id, period, kind)
  where voided_at is null and period is not null;

-- The index this REPLACES: (member_id, period) with no kind, which is the
-- literal statement "a month produces one invoice". Caught by the live
-- harness — create_invoice's own check was kind-aware from the first
-- draft, and the constraint underneath it silently was not, so a usage
-- invoice was refused beside the subscription invoice it complements.
drop index if exists public.invoices_one_active_per_member_period;

-- ---------------------------------------------------------------- the rules
alter table public.workspaces
  add column if not exists billing_rules jsonb not null default '{}'::jsonb;

comment on column public.workspaces.billing_rules is
  '#802 — subscription_auto, subscription_advance_days, usage_auto, usage_when_zero.';

-- ---------------------------------------------------------------- the lines
-- The three-argument form SPLITS what the two-argument one returns whole.
-- 'subscription' is one line kind in that output, so the split is exact and
-- the two halves cannot drift apart: usage is defined as "everything
-- invoice_lines_for produces that is not the subscription".
create or replace function public.invoice_lines_for(
  p_member_id uuid,
  p_period text,
  p_kind text
) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_all jsonb;
  v_out jsonb := '[]'::jsonb;
  v_line jsonb;
begin
  v_all := public.invoice_lines_for(p_member_id, p_period);
  if p_kind = 'full' then return v_all; end if;
  for v_line in select * from jsonb_array_elements(v_all) loop
    if p_kind = 'subscription' and v_line->>'kind' = 'subscription' then
      v_out := v_out || v_line;
    elsif p_kind = 'usage' and v_line->>'kind' is distinct from 'subscription' then
      v_out := v_out || v_line;
    end if;
  end loop;
  return v_out;
end;
$$;
revoke execute on function public.invoice_lines_for(uuid, text, text)
  from public, anon;

-- ---------------------------------------------------------------- issuing
-- Regenerated from 0104 with the kind threaded through: one implementation,
-- so a manual invoice and a scheduled one can never diverge in numbering,
-- signature, parties or VAT.
drop function if exists public.create_invoice(uuid, uuid, text, uuid, boolean);

create or replace function public.create_invoice(
  p_workspace_id uuid,
  p_member_id uuid,
  p_period text,
  p_replaces uuid default null,
  p_detailed boolean default false,
  -- #802 — which HALF of the month this document charges.
  p_kind text default 'full',
  -- Only a usage invoice may be empty, and only when the owner asked for
  -- the "nothing further to pay" confirmation.
  p_allow_zero boolean default false
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
  if p_kind not in ('full', 'subscription', 'usage') then
    raise exception 'unknown invoice kind';
  end if;
  -- #802 — the nightly run calls this with no session. It still writes a
  -- real issuer on the row (the owner), because issuer_member_id is NOT
  -- NULL and an invoice with no issuer is not a document anyone can
  -- answer for.
  if auth.uid() is null then
    select * into v_actor from public.members
      where workspace_id = p_workspace_id and is_owner and status = 'active'
      order by joined_at limit 1;
    if v_actor.id is null then raise exception 'workspace has no owner'; end if;
  else
    select * into v_actor from public.members
      where workspace_id = p_workspace_id and user_id = auth.uid()
        and status = 'active' and (is_admin or is_owner);
    if v_actor.id is null then raise exception 'not an admin of this workspace'; end if;
  end if;
  -- #513 — the CENTRAL permission decides: owner always passes,
  -- co-owner/admin/member per the workspace's role matrix; the
  -- legacy adminInvoicing flag keeps granting inside
  -- has_permission for compatibility.
  if auth.uid() is not null
     and not public.has_permission(p_workspace_id, 'issueInvoices') then
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
      and i.kind = p_kind
      and i.voided_at is null and i.id is distinct from p_replaces
  ) then
    raise exception 'period already invoiced for this member';
  end if;

  v_lines := public.invoice_lines_for(p_member_id, p_period, p_kind);
  if jsonb_array_length(v_lines) = 0 and not p_allow_zero then
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
      v_parties::text, v_vat_totals::text, p_kind),
      'UTF8'), 'sha256'), 'hex');

  insert into public.invoices
    (id, workspace_id, member_id, issuer_member_id, number, period, title,
     lines, total_cents, currency, member_name, member_address,
     workspace_name, workspace_address, issuer_name, signature,
     replaces_invoice_id, replaces_number, details, parties, vat_totals,
     kind)
  values
    (v_id, p_workspace_id, v_subject.id, v_actor.id, v_number, p_period,
     p_period, v_lines, v_total, v_workspace.currency_code,
     v_member_name, v_member_address, v_workspace.name,
     coalesce(v_workspace.address, ''), v_issuer_name, v_signature,
     p_replaces, v_replaces_number, v_details, v_parties, v_vat_totals,
     p_kind);
  return v_id;
end;
$$;
revoke execute on function
  public.create_invoice(uuid, uuid, text, uuid, boolean, text, boolean)
  from public, anon;
grant execute on function
  public.create_invoice(uuid, uuid, text, uuid, boolean, text, boolean)
  to authenticated;

-- ---------------------------------------------------------------- the clock
-- One sweep for both runs: the same walk over the same members, a month
-- apart. Runs daily and is idempotent — the unique index above is what
-- makes a second run of the day a no-op rather than a duplicate.
create or replace function public.sweep_billing_invoices(
  p_workspace_id uuid default null
) returns int language plpgsql security definer set search_path = public as $$
declare
  v_ws record;
  v_member record;
  v_rules jsonb;
  v_flags jsonb;
  v_tz text;
  v_today date;
  v_next_start date;
  v_next_period text;
  v_last_period text;
  v_advance int;
  v_total int := 0;
begin
  if auth.uid() is not null then
    if p_workspace_id is null then raise exception 'workspace required'; end if;
    if not public.is_admin_of(p_workspace_id) then
      raise exception 'not an admin of this workspace';
    end if;
  end if;

  for v_ws in
    select w.id, w.billing_rules, w.timezone, w.feature_flags
      from public.workspaces w
     where (p_workspace_id is null or w.id = p_workspace_id)
       and coalesce((w.feature_flags ->> 'moneyTab')::boolean, true)
       and coalesce((w.feature_flags ->> 'invoicing')::boolean, true)
  loop
    v_rules := coalesce(v_ws.billing_rules, '{}'::jsonb);
    v_flags := coalesce(v_ws.feature_flags, '{}'::jsonb);
    -- The WORKSPACE's calendar decides when a month starts, not UTC's:
    -- east of UTC the first of the month arrives hours earlier, and a
    -- subscription invoice that lands a day late is a late invoice.
    v_tz := coalesce(nullif(v_ws.timezone, ''), 'UTC');
    v_today := (now() at time zone v_tz)::date;
    v_next_start := date_trunc('month', v_today + interval '1 month')::date;
    v_next_period := to_char(v_next_start, 'YYYY-MM');
    v_last_period :=
      to_char(date_trunc('month', v_today) - interval '1 month', 'YYYY-MM');
    v_advance := least(greatest(
      coalesce((v_rules ->> 'subscription_advance_days')::int, 3), 0), 28);

    for v_member in
      select m.id from public.members m
       where m.workspace_id = v_ws.id and m.status = 'active' and not m.is_kiosk
       order by m.id
    loop
      -- SUBSCRIPTION, for the month AHEAD, once we are inside the advance
      -- window. Every failure here is expected traffic — already issued,
      -- or this member has no fee — and must not abort the workspace.
      if coalesce((v_rules ->> 'subscription_auto')::boolean, true)
         and coalesce((v_flags ->> 'subscriptionInvoices')::boolean, true)
         and v_today >= v_next_start - make_interval(days => v_advance)
      then
        begin
          perform public.create_invoice(
            v_ws.id, v_member.id, v_next_period, null, false,
            'subscription', false);
          v_total := v_total + 1;
        exception when others then
          null;
        end;
      end if;

      -- USAGE, for the month just FINISHED, so the figures can no longer
      -- move. `usage_when_zero` decides whether a member who owes nothing
      -- extra still receives the document that says so.
      if coalesce((v_rules ->> 'usage_auto')::boolean, true)
         and coalesce((v_flags ->> 'usageInvoices')::boolean, true)
      then
        begin
          perform public.create_invoice(
            v_ws.id, v_member.id, v_last_period, null, false, 'usage',
            coalesce((v_rules ->> 'usage_when_zero')::boolean, false));
          v_total := v_total + 1;
        exception when others then
          null;
        end;
      end if;
    end loop;
  end loop;
  return v_total;
end;
$$;
revoke execute on function public.sweep_billing_invoices(uuid) from public, anon;
grant execute on function public.sweep_billing_invoices(uuid) to authenticated;

do $$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('deskilo-billing-invoices')
    from cron.job where jobname = 'deskilo-billing-invoices';
  -- 06:40, after the expense sweep at 06:20: a scheduled expense
  -- confirmed this morning belongs on this morning's usage invoice.
  perform cron.schedule('deskilo-billing-invoices', '40 6 * * *',
    $job$select public.sweep_billing_invoices()$job$);
exception when others then
  raise notice 'pg_cron unavailable (%): the client sweep stays the only clock', sqlerrm;
end $$;
