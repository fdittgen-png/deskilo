-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (two functions created; invoice_essentials_missing patched at two asserted
-- anchors)
--
-- #4105 -- what the country's own invoice rules require of an address is
-- refused before the invoice is issued, not found after. Each country's postal
-- layout carries two facts about its region (the address form asks for it;
-- the invoice requires it), and postal_region_rules() is the server's copy of
-- them, generated from the app (tool/build_postal_region_rules_sql.dart, bound
-- by test/lint/postal_region_rules_sql_test.dart). A party in the seller's own
-- country whose country's invoices require the region and that has none is
-- refused: `seller_region`, `buyer_region`. A buyer abroad is never refused
-- for its own country's rules.

-- ── 1. the region facts of each country (generated) ─────────────────────
create or replace function public.postal_region_rules()
returns jsonb language sql immutable set search_path = public as $fn$
  select '{"CA":{"form":true,"invoice":true},"CH":{"form":false,"invoice":false},"ES":{"form":false,"invoice":false},"IE":{"form":false,"invoice":false},"IT":{"form":true,"invoice":true},"RO":{"form":true,"invoice":true},"US":{"form":true,"invoice":true}}'::jsonb
$fn$;
revoke execute on function public.postal_region_rules() from public, anon, authenticated;

-- ── 2. the region a party lacks, for the seller's own country ───────────
create or replace function public.invoice_region_missing(
  p_seller jsonb, p_buyer jsonb, p_seller_country text)
returns text[] language sql stable set search_path = public as $fn$
  select array_remove(array[
    case when coalesce((public.postal_region_rules()
                          -> upper(btrim(coalesce(p_seller_country, ''))) ->> 'invoice')::boolean, false)
              and btrim(coalesce(p_seller ->> 'subdivision', '')) = ''
         then 'seller_region' end,
    case when coalesce((public.postal_region_rules()
                          -> upper(btrim(coalesce(p_seller_country, ''))) ->> 'invoice')::boolean, false)
              and upper(btrim(coalesce(nullif(p_buyer ->> 'country', ''), p_seller_country, '')))
                  = upper(btrim(coalesce(p_seller_country, '')))
              and btrim(coalesce(p_buyer ->> 'subdivision', '')) = ''
         then 'buyer_region' end], null)
$fn$;
revoke execute on function public.invoice_region_missing(jsonb, jsonb, text)
  from public, anon, authenticated;

-- ── 3. the issue check asks it, in both of its branches ─────────────────
do $migration$
declare
  v_fn text;
  v_old text;
  v_new text;
  v_def text;
begin
  for v_fn, v_old, v_new in select * from (values
    -- a seller under sales tax (a US or Canadian state or province)
    ('public.invoice_essentials_missing(uuid,uuid,jsonb,jsonb)',
     $r$    return v_missing;
  end if;
$r$,
     $r$    -- #4105 -- the region the seller's country requires on the invoice
    v_missing := v_missing || public.invoice_region_missing(v_seller, v_buyer, v_country);
    return v_missing;
  end if;
$r$),
    -- a seller under VAT (an Italian province, a Romanian county)
    ('public.invoice_essentials_missing(uuid,uuid,jsonb,jsonb)',
     $r$    v_missing := array_append(v_missing, 'buyer_tax_id'::text);
  end if;
$r$,
     $r$    v_missing := array_append(v_missing, 'buyer_tax_id'::text);
  end if;
  -- #4105 -- the region the seller's country requires on the invoice
  v_missing := v_missing || public.invoice_region_missing(v_seller, v_buyer, v_country);
$r$)) v(f, o, n)
  loop
    v_def := pg_get_functiondef(v_fn::regprocedure);
    if position(v_new in v_def) > 0 then continue; end if;
    if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
      raise exception '% no longer has the shape 0793 extends: %', v_fn, left(v_old, 60) using errcode = 'P0001';
    end if;
    execute replace(v_def, v_old, v_new);
  end loop;
end
$migration$;

select public.set_deskilo_schema_version(793);
