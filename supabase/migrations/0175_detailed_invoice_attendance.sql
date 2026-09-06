-- SPDX-License-Identifier: 0BSD
-- 0175 — #960: detailed invoices issue again.
--
-- 0169 added the site name to each attendance row of a detailed invoice
-- by inserting the pair after the anchor that closes the `space`
-- coalesce. That parenthesis also closes jsonb_build_object, so the pair
-- became two extra arguments of jsonb_agg and every detailed invoice
-- failed with 42883 (`function jsonb_agg(jsonb, unknown, text) does not
-- exist`). A plain invoice never reaches the block, which is why 0169's
-- harness passed. The pair moves inside the object at an asserted
-- anchor; from here on the harness issues a DETAILED invoice in a
-- rolled-back transaction.
do $patch$
declare v_def text; v_old text; v_new text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_invoice' and p.prokind='f';
  v_old := E'              ''''))\n            , ''site'', coalesce((public.reservation_site(r)).name, '''')\n          order by r.starts_at)\n';
  v_new := E'              ''''),\n            ''site'', coalesce((public.reservation_site(r)).name, ''''))\n          order by r.starts_at)\n';
  if position(v_old in v_def) = 0 then raise exception '0175: anchor missing'; end if;
  v_def := replace(v_def, v_old, v_new);
  execute v_def;
end
$patch$;
