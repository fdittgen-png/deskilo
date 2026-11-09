-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0698 (#2380) -- the posting engine books a payment provider's money through
-- a clearing account. Money the member paid ONLINE (a ledger credit a
-- captured payment intent carries) reaches the bank only with the provider's
-- payout, net of its fee, so:
--
--   * a receipt matched to such a payment debits `clearing:<provider>`
--     instead of `bank` (the part of a match paid otherwise stays on `bank`);
--   * the provider's fee, reported with the payment (0687), is an expense
--     entry on the capture day: Dr `fees:<provider>`, Cr `clearing:<provider>`,
--     and, where the country has a standard rate, the reverse-charge pair
--     Dr `vat_input:<group>` / Cr `vat_output:<group>` of the fee at that
--     rate (a foreign provider's service the space accounts for itself);
--   * a paid payout is Dr `bank` / Cr `clearing:<provider>` on its arrival day.
--
-- After the payout the clearing balance is zero: gross receipts less fees
-- equal the payout, to the cent. A match with no online payment, a
-- workspace with no provider fact: every entry is byte-identical to before
-- (the three helpers answer the unchanged bank leg and no extra entry).
-- Entries in another currency than the space's are not booked here.
--
-- The roles resolve through the issuer's own book mapping like every other;
-- the suggested chart gains `clearing:<provider>` and `fees:<provider>` rows
-- for the generic, French, German and Swiss charts (unconfirmed, like every
-- suggested account until an accountant checks them).

-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('account_map', '*', 'coa/20-clearing_stripe', '1900-01-01', '{"format":"coa","role":"clearing:stripe","account":"1250","label":"Payment provider clearing — Stripe"}'::jsonb, 'a generic chart numbering (#2380: the clearing account of a payment provider and its fees, until an accountant re-points them)', false),
('account_map', '*', 'coa/21-clearing_paypal', '1900-01-01', '{"format":"coa","role":"clearing:paypal","account":"1251","label":"Payment provider clearing — PayPal"}'::jsonb, 'a generic chart numbering (#2380: the clearing account of a payment provider and its fees, until an accountant re-points them)', false),
('account_map', '*', 'coa/22-clearing_mollie', '1900-01-01', '{"format":"coa","role":"clearing:mollie","account":"1252","label":"Payment provider clearing — Mollie"}'::jsonb, 'a generic chart numbering (#2380: the clearing account of a payment provider and its fees, until an accountant re-points them)', false),
('account_map', '*', 'coa/23-fees_stripe', '1900-01-01', '{"format":"coa","role":"fees:stripe","account":"6150","label":"Payment provider fees — Stripe"}'::jsonb, 'a generic chart numbering (#2380: the clearing account of a payment provider and its fees, until an accountant re-points them)', false),
('account_map', '*', 'coa/24-fees_paypal', '1900-01-01', '{"format":"coa","role":"fees:paypal","account":"6151","label":"Payment provider fees — PayPal"}'::jsonb, 'a generic chart numbering (#2380: the clearing account of a payment provider and its fees, until an accountant re-points them)', false),
('account_map', '*', 'coa/25-fees_mollie', '1900-01-01', '{"format":"coa","role":"fees:mollie","account":"6152","label":"Payment provider fees — Mollie"}'::jsonb, 'a generic chart numbering (#2380: the clearing account of a payment provider and its fees, until an accountant re-points them)', false),
('account_map', 'CH', 'coa/20-clearing_stripe', '1900-01-01', '{"format":"coa","role":"clearing:stripe","account":"1090","label":"Durchlaufkonto Zahlungsanbieter — Stripe"}'::jsonb, 'KMU-Kontenrahmen 1090 Durchlaufkonto and 6940 Spesen (#2380: a payment provider''s clearing and fees, unconfirmed)', false),
('account_map', 'CH', 'coa/21-clearing_paypal', '1900-01-01', '{"format":"coa","role":"clearing:paypal","account":"1091","label":"Durchlaufkonto Zahlungsanbieter — PayPal"}'::jsonb, 'KMU-Kontenrahmen 1090 Durchlaufkonto and 6940 Spesen (#2380: a payment provider''s clearing and fees, unconfirmed)', false),
('account_map', 'CH', 'coa/22-clearing_mollie', '1900-01-01', '{"format":"coa","role":"clearing:mollie","account":"1092","label":"Durchlaufkonto Zahlungsanbieter — Mollie"}'::jsonb, 'KMU-Kontenrahmen 1090 Durchlaufkonto and 6940 Spesen (#2380: a payment provider''s clearing and fees, unconfirmed)', false),
('account_map', 'CH', 'coa/23-fees_stripe', '1900-01-01', '{"format":"coa","role":"fees:stripe","account":"6940","label":"Zahlungsverkehrsspesen — Stripe"}'::jsonb, 'KMU-Kontenrahmen 1090 Durchlaufkonto and 6940 Spesen (#2380: a payment provider''s clearing and fees, unconfirmed)', false),
('account_map', 'CH', 'coa/24-fees_paypal', '1900-01-01', '{"format":"coa","role":"fees:paypal","account":"6941","label":"Zahlungsverkehrsspesen — PayPal"}'::jsonb, 'KMU-Kontenrahmen 1090 Durchlaufkonto and 6940 Spesen (#2380: a payment provider''s clearing and fees, unconfirmed)', false),
('account_map', 'CH', 'coa/25-fees_mollie', '1900-01-01', '{"format":"coa","role":"fees:mollie","account":"6942","label":"Zahlungsverkehrsspesen — Mollie"}'::jsonb, 'KMU-Kontenrahmen 1090 Durchlaufkonto and 6940 Spesen (#2380: a payment provider''s clearing and fees, unconfirmed)', false),
('account_map', 'DE', 'coa/20-clearing_stripe', '1900-01-01', '{"format":"coa","role":"clearing:stripe","account":"1360","label":"Geldtransit Zahlungsdienstleister — Stripe"}'::jsonb, 'DATEV SKR03 1360 Geldtransit and 4970 Nebenkosten des Geldverkehrs (#2380: a payment provider''s clearing and fees, unconfirmed)', false),
('account_map', 'DE', 'coa/21-clearing_paypal', '1900-01-01', '{"format":"coa","role":"clearing:paypal","account":"1361","label":"Geldtransit Zahlungsdienstleister — PayPal"}'::jsonb, 'DATEV SKR03 1360 Geldtransit and 4970 Nebenkosten des Geldverkehrs (#2380: a payment provider''s clearing and fees, unconfirmed)', false),
('account_map', 'DE', 'coa/22-clearing_mollie', '1900-01-01', '{"format":"coa","role":"clearing:mollie","account":"1362","label":"Geldtransit Zahlungsdienstleister — Mollie"}'::jsonb, 'DATEV SKR03 1360 Geldtransit and 4970 Nebenkosten des Geldverkehrs (#2380: a payment provider''s clearing and fees, unconfirmed)', false),
('account_map', 'DE', 'coa/23-fees_stripe', '1900-01-01', '{"format":"coa","role":"fees:stripe","account":"4970","label":"Nebenkosten des Geldverkehrs — Stripe"}'::jsonb, 'DATEV SKR03 1360 Geldtransit and 4970 Nebenkosten des Geldverkehrs (#2380: a payment provider''s clearing and fees, unconfirmed)', false),
('account_map', 'DE', 'coa/24-fees_paypal', '1900-01-01', '{"format":"coa","role":"fees:paypal","account":"4971","label":"Nebenkosten des Geldverkehrs — PayPal"}'::jsonb, 'DATEV SKR03 1360 Geldtransit and 4970 Nebenkosten des Geldverkehrs (#2380: a payment provider''s clearing and fees, unconfirmed)', false),
('account_map', 'DE', 'coa/25-fees_mollie', '1900-01-01', '{"format":"coa","role":"fees:mollie","account":"4972","label":"Nebenkosten des Geldverkehrs — Mollie"}'::jsonb, 'DATEV SKR03 1360 Geldtransit and 4970 Nebenkosten des Geldverkehrs (#2380: a payment provider''s clearing and fees, unconfirmed)', false),
('account_map', 'FR', 'coa/20-clearing_stripe', '1900-01-01', '{"format":"coa","role":"clearing:stripe","account":"517100","label":"Prestataire de paiement (compte d''attente) — Stripe"}'::jsonb, 'PCG 517 Autres organismes financiers and 627 Services bancaires (#2380: a payment provider''s clearing and fees, unconfirmed)', false),
('account_map', 'FR', 'coa/21-clearing_paypal', '1900-01-01', '{"format":"coa","role":"clearing:paypal","account":"517101","label":"Prestataire de paiement (compte d''attente) — PayPal"}'::jsonb, 'PCG 517 Autres organismes financiers and 627 Services bancaires (#2380: a payment provider''s clearing and fees, unconfirmed)', false),
('account_map', 'FR', 'coa/22-clearing_mollie', '1900-01-01', '{"format":"coa","role":"clearing:mollie","account":"517102","label":"Prestataire de paiement (compte d''attente) — Mollie"}'::jsonb, 'PCG 517 Autres organismes financiers and 627 Services bancaires (#2380: a payment provider''s clearing and fees, unconfirmed)', false),
('account_map', 'FR', 'coa/23-fees_stripe', '1900-01-01', '{"format":"coa","role":"fees:stripe","account":"627800","label":"Frais du prestataire de paiement — Stripe"}'::jsonb, 'PCG 517 Autres organismes financiers and 627 Services bancaires (#2380: a payment provider''s clearing and fees, unconfirmed)', false),
('account_map', 'FR', 'coa/24-fees_paypal', '1900-01-01', '{"format":"coa","role":"fees:paypal","account":"627801","label":"Frais du prestataire de paiement — PayPal"}'::jsonb, 'PCG 517 Autres organismes financiers and 627 Services bancaires (#2380: a payment provider''s clearing and fees, unconfirmed)', false),
('account_map', 'FR', 'coa/25-fees_mollie', '1900-01-01', '{"format":"coa","role":"fees:mollie","account":"627802","label":"Frais du prestataire de paiement — Mollie"}'::jsonb, 'PCG 517 Autres organismes financiers and 627 Services bancaires (#2380: a payment provider''s clearing and fees, unconfirmed)', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

-- ── the helpers (each keeps the anchored patch to a call) ───────────────
-- The online payments a matched invoice was paid with, by provider.
create or replace function public.provider_receipt_split(p_invoice_id uuid, p_ledger_id uuid, p_paid bigint)
returns jsonb language sql stable security definer set search_path = public as $fn$
  with pays as (
    select p.payment_ledger_id, p.amount_cents
      from public.invoice_match_payments p
     where p.invoice_id = p_invoice_id
    union all
    select p_ledger_id, p_paid
     where p_ledger_id is not null and p_paid > 0
       and not exists (select 1 from public.invoice_match_payments q where q.invoice_id = p_invoice_id)
  )
  select coalesce(jsonb_agg(jsonb_build_object('provider', g.provider, 'cents', g.cents) order by g.provider), '[]'::jsonb)
    from (
      select pi.provider, sum(pays.amount_cents)::bigint as cents
        from pays
        join public.payment_intents pi on pi.ledger_entry_id = pays.payment_ledger_id and pi.status = 'captured'
       where pays.amount_cents > 0
       group by pi.provider
    ) g;
$fn$;
revoke execute on function public.provider_receipt_split(uuid, uuid, bigint) from public, anon, authenticated;

-- The debit legs of a receipt of [p_paid]: [p_split]'s providers' clearing
-- accounts for what they carried, `bank` for the rest -- exactly the bank leg
-- it was when no online payment is named.
create or replace function public.provider_clearing_lines(
  p_issuer_site_id uuid, p_day date, p_paid bigint, p_split jsonb
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  e jsonb;
  v_rest bigint := p_paid;
  v_clearing jsonb := '[]'::jsonb;
begin
  if p_paid > 0 then
    for e in select * from jsonb_array_elements(coalesce(p_split, '[]'::jsonb)) loop
      v_clearing := v_clearing || public.posting_line(p_issuer_site_id, 'clearing', e ->> 'provider', p_day,
                                                      (e ->> 'cents')::bigint, true);
      v_rest := v_rest - (e ->> 'cents')::bigint;
    end loop;
  end if;
  return public.posting_line(p_issuer_site_id, 'bank', null, p_day, v_rest, true) || v_clearing;
end;
$fn$;
revoke execute on function public.provider_clearing_lines(uuid, date, bigint, jsonb) from public, anon, authenticated;

-- The provider fee and payout entries dated in [p_from, p_to].
create or replace function public.provider_settlement_postings(
  p_workspace_id uuid, p_issuer_site_id uuid, p_from date, p_to date,
  p_country text, p_tz text, p_currency text
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_out jsonb := '[]'::jsonb;
  f record;
  po record;
  v_lines jsonb;
  v_grp text;
  v_pct numeric;
  v_vat bigint;
begin
  for f in
    select pi.id, pi.provider, pi.order_id, pi.currency, pi.provider_fee_cents as fee,
           coalesce(le.occurred_on, (le.created_at at time zone coalesce(nullif(p_tz, ''), 'UTC'))::date) as day
      from public.payment_intents pi
      join public.ledger_entries le on le.id = pi.ledger_entry_id
     where pi.workspace_id = p_workspace_id and pi.status = 'captured'
       and pi.provider_fee_cents is not null and pi.provider_fee_cents > 0
       and upper(pi.provider_fee_currency) = upper(p_currency)
       and coalesce(le.occurred_on, (le.created_at at time zone coalesce(nullif(p_tz, ''), 'UTC'))::date) between p_from and p_to
     order by 6, pi.order_id
  loop
    v_lines := public.posting_line(p_issuer_site_id, 'fees', f.provider, f.day, f.fee, true);
    -- Reverse charge: the standard rate group of the space's country on the day.
    select r.value ->> 'group', (r.value ->> 'percent')::numeric into v_grp, v_pct
      from public.tax_reference r
     where r.domain = 'rate' and r.country = upper(btrim(p_country))
       and r.value ->> 'category' = 'S'
       and r.valid_from <= f.day and (r.valid_to is null or r.valid_to > f.day)
     order by (r.value ->> 'percent')::numeric desc
     limit 1;
    if v_grp is not null and v_grp <> '' and v_pct is not null and v_pct > 0 then
      v_vat := round(f.fee * v_pct / 100);
      v_lines := v_lines
        || public.posting_line(p_issuer_site_id, 'vat_input', v_grp, f.day, v_vat, true)
        || public.posting_line(p_issuer_site_id, 'vat_output', v_grp, f.day, v_vat, false);
    end if;
    v_lines := v_lines || public.posting_line(p_issuer_site_id, 'clearing', f.provider, f.day, f.fee, false);
    v_out := v_out || public.posting_entry('purchases', 'expense', f.day, f.id, f.order_id, upper(f.currency), v_lines);
  end loop;
  for po in
    select p.id, p.provider, p.payout_id, p.currency, p.amount_cents, p.arrival_date
      from public.provider_payouts p
     where p.workspace_id = p_workspace_id and p.status = 'paid' and p.amount_cents > 0
       and p.arrival_date between p_from and p_to
       and upper(p.currency) = upper(p_currency)
     order by p.arrival_date, p.payout_id
  loop
    v_out := v_out || public.posting_entry('bank', 'receipt', po.arrival_date, po.id, po.payout_id, po.currency,
      public.posting_line(p_issuer_site_id, 'bank', null, po.arrival_date, po.amount_cents, true)
      || public.posting_line(p_issuer_site_id, 'clearing', po.provider, po.arrival_date, po.amount_cents, false));
  end loop;
  return v_out;
end;
$fn$;
revoke execute on function public.provider_settlement_postings(uuid, uuid, date, date, text, text, text)
  from public, anon, authenticated;

-- ── anchored patch of compute_postings ──────────────────────────────────
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

do $migration$
declare
  v_def text;
  v_step record;
begin
  select pg_get_functiondef('public.compute_postings(uuid,uuid,date,date)'::regprocedure) into v_def;
  for v_step in
    select * from (values
      (1, 'the own matches name the online payments they were paid with',
       $old$             x.matched_at, x.writeoff_at
        from public.invoices inv
        join public.invoice_matches x on x.invoice_id = inv.id and x.status = 'confirmed'$old$,
       $new$             x.matched_at, x.writeoff_at,
             public.provider_receipt_split(inv.id, x.payment_ledger_id, x.paid_cents) as clearing
        from public.invoices inv
        join public.invoice_matches x on x.invoice_id = inv.id and x.status = 'confirmed'$new$),
      (2, 'a settlement allocation carries none',
       $old$             x.matched_at, x.writeoff_at
        from public.invoices st$old$,
       $new$             x.matched_at, x.writeoff_at, '[]'::jsonb as clearing
        from public.invoices st$new$),
      (3, 'the receipt debits clearing for what a provider carried',
       $old$        public.posting_line(p_issuer_site_id, 'bank', null, v_day, m.paid, true)
        || public.posting_line(p_issuer_site_id, 'customers', null, v_day, m.paid, false)));$old$,
       $new$        public.provider_clearing_lines(p_issuer_site_id, v_day, m.paid, m.clearing)
        || public.posting_line(p_issuer_site_id, 'customers', null, v_day, m.paid, false)));$new$),
      (4, 'the provider fee and payout entries',
       $old$  -- ── the output tax released on its tax points (0521) ──────────────────$old$,
       $new$  -- ── a provider's fee and payout through its clearing account (0698) ──
  if v_default then
    v_postings := v_postings
      || public.provider_settlement_postings(p_workspace_id, p_issuer_site_id, p_from, p_to, v_country, v_tz, v_space);
  end if;

  -- ── the output tax released on its tax points (0521) ──────────────────$new$)
    ) as s(n, what, old_text, new_text) order by n
  loop
    v_def := pg_temp.anchor_replace(v_def, v_step.old_text, v_step.new_text);
    if v_def is null then
      raise exception '0698: compute_postings anchor % (%) missing', v_step.n, v_step.what;
    end if;
  end loop;
  execute v_def;
end
$migration$;

select public.set_deskilo_schema_version(698);
