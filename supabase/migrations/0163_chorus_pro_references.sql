-- SPDX-License-Identifier: 0BSD
-- 0163 — #922: the two references Chorus Pro will not accept a deposit
-- without.
--
-- Factur-X is sound (PDF/A-3, CII embedded, EN 16931 conformance), and
-- the upload posts it to the platform. What the document did not carry
-- were two fields of the norm that the French public-sector portal
-- REQUIRES for most public entities: BT-13, the purchase-order
-- reference — the numéro d'engagement — and BT-10, the buyer reference
-- — the code service exécutant. The app would accept the deposit, the
-- portal would refuse it, and nothing had warned the issuer.
--
-- Both are captured AT ISSUE and frozen on the document, under the
-- buyer party: an engagement number belongs to one order, not to a
-- member for ever, and an issued invoice does not change. The 7-argument
-- overload is dropped rather than kept beside the new one: two
-- candidates make the old call ambiguous, and PostgREST resolves the
-- named-parameter call against this one, so a client that sends neither
-- reference lands on the empty default.
do $patch$
declare v_def text; v_anchor text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'create_invoice';
  if v_def is null then raise exception '0163: create_invoice not found'; end if;
  v_anchor := 'p_allow_zero boolean DEFAULT false)';
  if position(v_anchor in v_def) = 0 then raise exception '0163: signature anchor missing'; end if;
  v_def := replace(v_def, v_anchor,
    'p_allow_zero boolean DEFAULT false, p_buyer_reference text DEFAULT ''''::text, p_purchase_order text DEFAULT ''''::text)');
  v_anchor := E'      ''vat_id'', v_member_vat));\n';
  if position(v_anchor in v_def) = 0 then raise exception '0163: buyer anchor missing'; end if;
  v_def := replace(v_def, v_anchor,
       E'      ''reference'', left(btrim(coalesce(p_buyer_reference, '''')), 120),\n'
    || E'      ''order'', left(btrim(coalesce(p_purchase_order, '''')), 120),\n'
    || v_anchor);
  drop function if exists public.create_invoice(uuid, uuid, text, uuid, boolean, text, boolean);
  execute v_def;
end
$patch$;
