-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0393 -- #1917: the VAT on an issued invoice is never a silent default.
--
-- 0385 refused issuing when a VAT-registered seller had no default rate.
-- Three ways a wrong rate still reached a legal invoice, each now a key of
-- invoice_essentials_missing (DKI01 in create_invoice, listed by
-- invoice_issue_readiness; previews and statements stay usable):
--
--   vat_rate_unresolved (stricter) -- vat_rate_percent_at falls back to a
--     rate's OWN percent when no version is in force, so an expired
--     default still "resolved". vat_rate_in_force has no fallback;
--   vat_line_zero_unexplained -- a VAT-registered seller billing a charge
--     at 0 % with no buyer treatment (export, exempt, reverse charge):
--     the price was stamped when no rate resolved, and create_invoice
--     would issue it as category O, "outside the scope";
--   vat_charged_not_registered -- a seller that does not charge VAT
--     (not_subject, exempt) issuing a line WITH VAT, from a rate left on
--     an accessory or on the subscription tariff.
--
-- And at the source, the subscription tariff's own rate now follows the
-- regime like the default does: a workspace that does not charge VAT
-- prices its subscription at 0 %, as workspace_default_vat_percent always
-- did. Amounts are gross, so only the split changes, never a total.
--
-- And automatic collection stays unavailable where it is off (#1917,
-- #1974): open_payment_intent asked no feature at all, so with
-- onlinePayments off a payment could still be opened wherever a provider
-- was configured. It now refuses a NEW payment (feature_operation_allowed
-- 'accept_new'); one already open is still settled by its provider.

-- The percent of a rate's family IN FORCE on a date: an active version
-- whose validity interval contains the date. Null otherwise — no fallback.
create or replace function public.vat_rate_in_force(p_rate_id uuid, p_date date)
returns numeric
language sql stable security definer set search_path = public as $fn$
  select f.percent from public.vat_rate_family(p_rate_id) f
   where f.active and f.valid_from <= p_date
     and (f.valid_to is null or f.valid_to > p_date)
   order by f.valid_from desc, (f.id = p_rate_id) desc
   limit 1;
$fn$;
revoke execute on function public.vat_rate_in_force(uuid, date) from public, anon, authenticated;

create or replace function public.invoice_essentials_missing(
  p_workspace_id uuid, p_member_id uuid, p_parties jsonb, p_vat_totals jsonb
) returns text[]
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_missing text[] := '{}';
  v_seller jsonb := coalesce(p_parties -> 'seller', '{}'::jsonb);
  v_buyer jsonb := coalesce(p_parties -> 'buyer', '{}'::jsonb);
  v_capacity text;
  v_exempt_line boolean;
  v_reverse boolean;
  v_country text;
  v_rate uuid;
begin
  if btrim(coalesce(v_seller ->> 'street', '')) = ''
     and btrim(coalesce(v_seller ->> 'city', '')) = '' then
    v_missing := array_append(v_missing, 'seller_address'::text);
  end if;
  if v_seller ->> 'vat_regime' = 'vat_registered'
     and btrim(coalesce(v_seller ->> 'vat_id', '')) = '' then
    v_missing := array_append(v_missing, 'seller_vat_id'::text);
  end if;

  select coalesce(bool_or(t ->> 'category' in ('E', 'G')), false),
         coalesce(bool_or(t ->> 'category' = 'AE'), false)
    into v_exempt_line, v_reverse
    from jsonb_array_elements(coalesce(p_vat_totals, '[]'::jsonb)) t;
  if v_exempt_line
     and btrim(coalesce(
           case when v_buyer ->> 'vat_treatment' in ('exempt', 'export')
                then v_buyer ->> 'tax_exemption_reason'
                else v_seller ->> 'tax_exemption_reason' end, '')) = '' then
    v_missing := array_append(v_missing, 'exemption_reason'::text);
  end if;
  if v_reverse and btrim(coalesce(v_buyer ->> 'vat_id', '')) = '' then
    v_missing := array_append(v_missing, 'buyer_vat_id'::text);
  end if;

  -- #1917 -- two things that used to degrade silently, now refuse issuing:
  -- a seller whose country is not one the legal clauses were reviewed for
  -- (FR, DE — what legalProfileOf says on the client), and a VAT-registered
  -- seller whose default rate does not resolve today (it would bill 0 %).
  v_country := public.invoice_legal_snapshot(p_workspace_id, p_member_id, p_parties)
                 ->> 'seller_country';
  if coalesce(v_country, '') not in ('FR', 'DE') then
    v_missing := array_append(v_missing, 'seller_country_unsupported'::text);
  end if;
  if v_seller ->> 'vat_regime' = 'vat_registered' then
    v_rate := public.workspace_default_vat_rate_id(p_workspace_id);
    -- 0393: in force TODAY, inside its validity interval — an expired or
    -- not-yet-valid default no longer answers with its own percent.
    if v_rate is null or public.vat_rate_in_force(v_rate, current_date) is null then
      v_missing := array_append(v_missing, 'vat_rate_unresolved'::text);
    end if;
    -- 0393: a charge billed at 0 % with no buyer treatment explaining it
    -- (export, exemption, reverse charge) is a rate that was missing when
    -- the line was priced — it would be issued as "outside the scope".
    if exists (select 1 from jsonb_array_elements(coalesce(p_vat_totals, '[]'::jsonb)) t
                where t ->> 'category' = 'O'
                  and coalesce((t ->> 'gross_cents')::int, 0) > 0) then
      v_missing := array_append(v_missing, 'vat_line_zero_unexplained'::text);
    end if;
  elsif exists (select 1 from jsonb_array_elements(coalesce(p_vat_totals, '[]'::jsonb)) t
                 where coalesce((t ->> 'percent')::numeric, 0) > 0) then
    -- 0393: a seller that does not charge VAT never issues a line with VAT
    -- on it (a rate left on an accessory or on the subscription tariff).
    v_missing := array_append(v_missing, 'vat_charged_not_registered'::text);
  end if;

  if btrim(coalesce(v_buyer ->> 'name', '')) = ''
     and btrim(coalesce(v_buyer ->> 'company', '')) = '' then
    v_missing := array_append(v_missing, 'buyer_name'::text);
  end if;
  v_capacity := public.invoice_legal_snapshot(p_workspace_id, p_member_id, p_parties)
                  ->> 'buyer_capacity';
  if v_capacity = 'business'
     and btrim(coalesce(v_buyer ->> 'street', '')) = ''
     and btrim(coalesce(v_buyer ->> 'city', '')) = '' then
    v_missing := array_append(v_missing, 'buyer_address'::text);
  end if;
  return v_missing;
end;
$fn$;

revoke execute on function public.invoice_essentials_missing(uuid, uuid, jsonb, jsonb)
  from public, anon, authenticated;

create or replace function public.workspace_tariff_vat_percent(p_workspace_id uuid, p_date date)
returns numeric
language sql stable security definer set search_path = public as $fn$
  select case when public.workspace_charges_vat(p_workspace_id) then
    coalesce(
      (select public.vat_rate_percent_at(w.subscription_vat_rate_id, p_date)
         from public.workspaces w where w.id = p_workspace_id),
      public.workspace_default_vat_percent(p_workspace_id, p_date))
  else 0 end;
$fn$;
revoke execute on function public.workspace_tariff_vat_percent(uuid, date) from public, anon;
grant execute on function public.workspace_tariff_vat_percent(uuid, date) to authenticated;

do $patch$
declare v_def text; v_old text;
begin
  select pg_get_functiondef('public.open_payment_intent(uuid, uuid, text, text, integer, text, uuid)'::regprocedure) into v_def;
  v_old := $a$  v_me := public.my_active_member(p_workspace_id);$a$;
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception '0393: open_payment_intent anchor';
  end if;
  execute replace(v_def, v_old, v_old || $a$
  -- 0393 (#1917, #1974): automatic collection is a feature. With
  -- onlinePayments off no new payment is opened; a payment already open
  -- is still settled by its provider (servicing it).
  if not public.feature_operation_allowed(p_workspace_id, 'onlinePayments', 'accept_new') then
    raise exception 'online payments are off in this workspace';
  end if;$a$);
end;
$patch$;

select public.set_deskilo_schema_version(393);
