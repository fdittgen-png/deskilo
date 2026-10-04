-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1917: vat_tax_point reads current_date, so it is STABLE, never
-- IMMUTABLE; its answers are unchanged: a finished period ends on its
-- last day, a running one on today.
begin;
select plan(4);

select is((select provolatile::text from pg_proc where oid = 'public.vat_tax_point(text)'::regprocedure),
  's', 'the tax point of a period depends on today, so it is stable and not immutable');
select is(public.vat_tax_point('2020-02'), date '2020-02-29', 'a finished period ends on its last day');
select is(public.vat_tax_point(to_char(current_date, 'YYYY-MM')), current_date, 'the running period ends on today');
select is(public.vat_tax_point(to_char(current_date + interval '2 months', 'YYYY-MM')), current_date,
  'and a future period is not later than today');

select * from finish();
rollback;
