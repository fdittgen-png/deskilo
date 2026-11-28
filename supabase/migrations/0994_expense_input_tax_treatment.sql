-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4479 -- an expense keeps its input-tax treatment, the identity of the rate and the facts of the document.
--
-- Until now an expense said only a percent (`payload.vat.percent`), checked to lie between 0 and 100: the rate it was
-- entered at was whatever number the form offered, and a supplier abroad's invoice had nowhere to say its own VAT.
-- `expense_vat_payload` (0413, restated whole by 0605) now reads and keeps:
--   * `treatment`, one of
--       domestic         VAT charged by a supplier in the space's country: an active rate of the space, by `vat_rate_id`
--                        (the percent is resolved from it; `vat_rate_unknown` otherwise), deducted by the share given;
--       acquisition      a service bought from a supplier abroad, the tax owed by the space itself (0605's flag, now a
--                        treatment): the same rate by identity, the amount is the base;
--       foreign_charged  VAT a supplier abroad charged in its own country. It is not input tax of this return, so it is
--                        deducted nowhere and filed nowhere: the stated percent and amount stay as document facts
--                        (`stated_percent`, `stated_tax_cents`) for a later cross-border refund filing. It never carries
--                        a catalogue rate: the space's sales catalogue says nothing about another country's rates;
--       none             no VAT on the document.
--     A payload without a treatment reads as `acquisition` when its flag is set and as `domestic` otherwise; no event
--     already stored is rewritten, and a percent sent without a rate id keeps working as before (a schedule, the MCP).
--   * the document's facts: `supplier_country` (a country code, differing from the space's for an acquisition or foreign
--     VAT), `document_number`, `document_date`.
-- Every reader of `payload.vat.percent` (the return, the purchase bridge) keeps reading it: a foreign-charged or untaxed
-- expense carries no `percent`, so it reaches none of them. A filed return is untouched.

-- restates 0605
create or replace function public.expense_vat_payload(
  p_workspace_id uuid, p_vat jsonb
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_treat text;
  v_percent numeric;
  v_share numeric;
  v_rate_id uuid;
  v_country text;
  v_space_country text;
  v_stated numeric;
  v_stated_tax bigint;
  v_number text;
  v_date date;
  v_acquisition boolean := coalesce((p_vat ->> 'acquisition')::boolean, false);
  v_facts jsonb := '{}'::jsonb;
begin
  if p_vat is null or jsonb_typeof(p_vat) <> 'object' then
    return null;
  end if;
  if not public.feature_effective(p_workspace_id, 'inputVat') then
    raise exception 'input VAT is switched off in this space';
  end if;
  v_treat := coalesce(nullif(p_vat ->> 'treatment', ''), case when v_acquisition then 'acquisition' else 'domestic' end);
  if v_treat not in ('domestic', 'acquisition', 'foreign_charged', 'none') then
    raise exception 'unknown input tax treatment of an expense';
  end if;
  if v_treat = 'acquisition' then
    v_acquisition := true;
  elsif v_acquisition then
    raise exception 'the acquisition flag belongs to the acquisition treatment';
  end if;

  select upper(btrim(coalesce(w.country_code, ''))) into v_space_country from public.workspaces w where w.id = p_workspace_id;
  v_country := nullif(upper(btrim(coalesce(p_vat ->> 'supplier_country', ''))), '');
  if v_country is not null and v_country !~ '^[A-Z][A-Z]$' then
    raise exception 'the supplier''s country is a country code';
  end if;
  if v_country is not null then
    if v_treat = 'domestic' and v_country <> v_space_country then
      raise exception 'a domestic expense comes from a supplier in the space''s country';
    end if;
    if v_treat in ('acquisition', 'foreign_charged') and v_country = v_space_country then
      raise exception 'a supplier in the space''s own country is not a supplier abroad';
    end if;
    v_facts := v_facts || jsonb_build_object('supplier_country', v_country);
  end if;
  v_number := nullif(btrim(coalesce(p_vat ->> 'document_number', '')), '');
  if v_number is not null then
    if char_length(v_number) > 60 then
      raise exception 'the document number is at most 60 characters';
    end if;
    v_facts := v_facts || jsonb_build_object('document_number', v_number);
  end if;
  v_date := nullif(p_vat ->> 'document_date', '')::date;
  if v_date is not null then
    v_facts := v_facts || jsonb_build_object('document_date', v_date);
  end if;

  if v_treat = 'none' then
    return jsonb_build_object('treatment', 'none') || v_facts;
  end if;

  if v_treat = 'foreign_charged' then
    -- the supplier's own VAT, kept as a fact: never looked up in the space's catalogue, never deducted, never filed
    if nullif(p_vat ->> 'vat_rate_id', '') is not null or nullif(p_vat ->> 'percent', '') is not null
       or coalesce((p_vat ->> 'asset')::boolean, false) then
      raise exception 'VAT charged abroad carries no rate of this space, no deduction and is no asset';
    end if;
    if v_country is null then
      raise exception 'VAT charged abroad names the supplier''s country';
    end if;
    v_stated := (p_vat ->> 'stated_percent')::numeric;
    if v_stated is null or v_stated <= 0 or v_stated > 100 then
      raise exception 'the VAT a supplier abroad charged is stated as a rate between 0 and 100';
    end if;
    v_stated_tax := nullif(p_vat ->> 'stated_tax_cents', '')::bigint;
    if v_stated_tax is not null and v_stated_tax < 0 then
      raise exception 'the VAT a supplier abroad charged is not negative';
    end if;
    return jsonb_build_object('treatment', 'foreign_charged', 'stated_percent', trim_scale(v_stated))
           || case when v_stated_tax is null then '{}'::jsonb else jsonb_build_object('stated_tax_cents', v_stated_tax) end
           || v_facts;
  end if;

  -- domestic and acquisition: a rate of this space, by identity when it is given
  v_rate_id := nullif(p_vat ->> 'vat_rate_id', '')::uuid;
  if v_rate_id is not null then
    select r.percent into v_percent from public.vat_rates r
     where r.id = v_rate_id and r.workspace_id = p_workspace_id and r.active;
    if not found then
      raise exception 'vat_rate_unknown: the VAT rate is not an active rate of this space';
    end if;
  else
    v_percent := (p_vat ->> 'percent')::numeric;
  end if;
  v_share := coalesce((p_vat ->> 'deductible_pct')::numeric, 100);
  if v_percent is null or v_percent <= 0 or v_percent > 100 then
    raise exception 'the VAT rate of an expense lies between 0 and 100';
  end if;
  if v_share < 0 or v_share > 100 then
    raise exception 'the deductible share lies between 0 and 100';
  end if;
  if v_acquisition and not exists (
       select 1 from public.workspaces w
        cross join lateral (select (now() at time zone coalesce(nullif(w.timezone, ''), 'UTC'))::date as d) today
        join public.tax_reference r
          on r.domain = 'form_box' and r.country = upper(btrim(coalesce(w.country_code, '')))
         and r.valid_from <= today.d and (r.valid_to is null or r.valid_to > today.d)
        where w.id = p_workspace_id and coalesce(r.value -> 'categories' ? 'acquisition', false)) then
    raise exception 'this space''s return has no acquisition tax box';
  end if;
  return jsonb_build_object('percent', trim_scale(v_percent),
                            'deductible_pct', trim_scale(v_share),
                            'treatment', v_treat)
         || case when v_rate_id is null then '{}'::jsonb else jsonb_build_object('vat_rate_id', v_rate_id) end
         || case when coalesce((p_vat ->> 'asset')::boolean, false)
                 then jsonb_build_object('asset', true) else '{}'::jsonb end
         -- A service bought from a supplier abroad, the tax not on its
         -- invoice: the space owes it itself (CH Bezugsteuer, art. 45 MWSTG)
         -- and deducts the share it may; the amount is then the base.
         || case when v_acquisition then jsonb_build_object('acquisition', true) else '{}'::jsonb end
         || v_facts;
end;
$fn$;
revoke execute on function public.expense_vat_payload(uuid, jsonb)
  from public, anon, authenticated;

select public.set_deskilo_schema_version(994);
