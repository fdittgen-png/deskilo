-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (compute_postings patched at one asserted anchor: a new section, nothing
-- of the existing entries changes)
--
-- 0622 (#3152, follow-up of #2360) -- the acquisition tax in the books. A
-- confirmed expense bought from a supplier abroad (`vat.acquisition`, 0413)
-- is filed by vat_input_amounts (0605) as two rows on its tax point: the
-- deductible share (S/asset) and the tax owed (`acquisition`); the return
-- files them under 400/405 and 383. The books had no entry for either, so
-- the VAT accounts did not reconcile to the return. Now one entry per such
-- expense, on its tax point, in the purchases journal, booked by the
-- default issuer like every purchase:
--
--   Dr vat_input:<group>   the deductible share
--   Dr expenses            the share that is not deductible, if any
--   Cr vat_output:<group>  the tax owed
--
-- The Dart reference is posting_rules_acquisitions.dart; pgTAP 316 holds
-- this engine to its hand-worked entries.

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
begin
  -- An anchor names one place: it occurs exactly once, or nothing is patched.
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    return null;
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public, anon, authenticated;

do $migration$
declare
  v_def text;
  v_patched text;
begin
  select pg_get_functiondef('public.compute_postings(uuid, uuid, date, date)'::regprocedure) into v_def;
  -- Idempotent: a definition that already books the acquisition tax stays.
  v_patched := case when position('acquisition_tax' in v_def) > 0 then v_def end;
  v_patched := coalesce(v_patched, pg_temp.anchor_replace(v_def,
    $a$  -- ── a purchase in another currency, at its recorded rate ──────────────$a$,
    $a$  -- ── the acquisition tax of a service bought abroad (0622) ────────────
  -- Dr vat_input (deductible) and Dr expenses (the rest) / Cr vat_output
  -- (the tax owed), on the expense's tax point (#3152).
  if v_default then
    for t in
      select a.expense_id, a.tax_point, a.percent,
             (sum(a.gross_cents - a.net_cents) filter (where a.category = 'acquisition'))::bigint as owed,
             coalesce(sum(a.gross_cents - a.net_cents) filter (where a.category in ('S', 'asset')), 0)::bigint as deductible
        from public.vat_input_amounts(p_workspace_id, p_from, p_to) a
       group by a.expense_id, a.tax_point, a.percent
      having count(*) filter (where a.category = 'acquisition') > 0
       order by a.tax_point, a.expense_id
    loop
      v_grp := public.posting_rate_group(v_country, t.percent, 'S', t.tax_point);
      v_postings := v_postings || public.posting_entry('purchases', 'acquisition_tax', t.tax_point,
        t.expense_id, left(t.expense_id::text, 8),
        (select ws.currency_code from public.workspaces ws where ws.id = p_workspace_id),
        public.posting_line(p_issuer_site_id, 'vat_input', v_grp, t.tax_point, t.deductible, true)
        || public.posting_line(p_issuer_site_id, 'expenses', null, t.tax_point, t.owed - t.deductible, true)
        || public.posting_line(p_issuer_site_id, 'vat_output', v_grp, t.tax_point, t.owed, false));
    end loop;
  end if;

  -- ── a purchase in another currency, at its recorded rate ──────────────$a$));
  if v_patched is null then
    raise exception '0622: compute_postings anchor missing';
  end if;
  execute v_patched;
end
$migration$;

select public.set_deskilo_schema_version(622);
