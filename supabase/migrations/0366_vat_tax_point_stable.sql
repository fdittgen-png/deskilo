-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0366 (#1917) -- vat_tax_point reads the clock, so it is not IMMUTABLE.
--
-- `vat_tax_point(period)` returns the last day of the period, or today
-- when the period is not over yet (least(period end, current_date)). It
-- was declared IMMUTABLE, which promises the same answer for the same
-- argument forever; for the running month the answer moves every day.
-- Declared that way the planner may fold the call into a plan or an
-- expression it keeps (invoice_lines_for and member_statement both call
-- it), so a statement prepared before midnight could keep yesterday's tax
-- point.
--
-- STABLE is the honest class: one answer within a statement, free to move
-- between statements. Only the declaration changes; the body, the grants
-- and every caller are untouched, and no index or generated column depends
-- on it (checked on the hosted catalogue). This is the volatility fix only:
-- the statutory tax point itself (service, receipt, deposit, election) is a
-- separate decision and remains with the rest of #1917.

alter function public.vat_tax_point(text) stable;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(366);
