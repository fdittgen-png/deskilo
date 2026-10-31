-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2571 / 0604: a retention clock gives a disposition, never a permission.
-- The rules here are SYNTHETIC (countries ZZ and ZY, confirmed inside this
-- rolled-back transaction) so the mechanism is proved without claiming any
-- country's law. Expected dates are written by hand from those rows.
begin;
select plan(48);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00009999' || lpad(n::text, 4, '0'))::uuid;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- Ids are read once, as the table owner, and kept in settings: a signed-in
-- person's RLS would hide another space's rows from a lookup.
create function pg_temp.ws(p_name text) returns uuid language sql as $$
  select current_setting('t.ws.' || p_name)::uuid;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.site(p_name text) returns uuid language sql as $$
  select current_setting('t.site.' || p_name)::uuid;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.assess(p_site text, p_classes text[], p_day date) returns jsonb language sql as $$
  select public.retention_assess(pg_temp.ws('Keep'), pg_temp.site(p_site), p_classes, p_day);
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@keep.test', '', now(), now(), now()
  from generate_series(1, 5) i;
-- 1 owns Keep, 2 is a plain member of Keep, 3 owns Other, 4 is a member of Keep who erases,
-- 5 is an admin of Keep: viewFinances by the default matrix, not manageBilling.
insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
values ('Keep', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"invoicing": true, "accountingBook": true}'),
       ('Other', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(3), '{}'),
       ('Nowhere', 'GB', 'GBP', 'Europe/London', pg_temp.u(3), '{}');
select set_config('t.ws.' || name, id::text, true) from public.workspaces
 where name in ('Keep', 'Other', 'Nowhere') and created_by in (pg_temp.u(1), pg_temp.u(3));
insert into public.members (workspace_id, user_id, is_owner, is_admin)
values (pg_temp.ws('Keep'), pg_temp.u(1), true, true),
       (pg_temp.ws('Keep'), pg_temp.u(2), false, false),
       (pg_temp.ws('Keep'), pg_temp.u(4), false, false),
       (pg_temp.ws('Keep'), pg_temp.u(5), false, true),
       (pg_temp.ws('Other'), pg_temp.u(3), true, true),
       (pg_temp.ws('Nowhere'), pg_temp.u(3), true, true);
-- Keep has two issuers under different rules; Other has one.
insert into public.sites (workspace_id, name, country_code, is_default)
values (pg_temp.ws('Keep'), 'North', 'ZZ', true),
       (pg_temp.ws('Keep'), 'South', 'ZY', false),
       (pg_temp.ws('Other'), 'Elsewhere', 'ZZ', true);
select set_config('t.site.' || name, id::text, true) from public.sites
 where workspace_id in (pg_temp.ws('Keep'), pg_temp.ws('Other'));
-- ZZ books: 5 years from the fiscal-year end until 2025, then 3 (a later
-- shortening). ZY books: 2 years from the document date. ZZ invoices: 7 years
-- from the document date. ZZ correspondence: unconfirmed.
insert into public.tax_reference (domain, country, key, valid_from, valid_to, value, source, confirmed)
values ('retention', 'ZZ', 'books', '2000-01-01', '2025-01-01', '{"years":5,"from":"fiscal_year_end"}', 'synthetic ZZ books rule', true),
       ('retention', 'ZZ', 'books', '2025-01-01', null, '{"years":3,"from":"fiscal_year_end"}', 'synthetic ZZ books rule, shortened', true),
       ('retention', 'ZY', 'books', '2000-01-01', null, '{"years":2,"from":"document_date"}', 'synthetic ZY books rule', true),
       ('retention', 'ZZ', 'invoice', '2000-01-01', null, '{"years":7,"from":"document_date"}', 'synthetic ZZ invoice rule', true),
       ('retention', 'ZZ', 'correspondence', '2000-01-01', null, '{"years":1,"from":"document_date"}', 'synthetic ZZ letters rule', false),
       ('retention', 'ZZ', 'archive', '2000-01-01', null, '{"years":1,"from":"document_date"}', 'synthetic ZZ archive rule', true);

-- ── the issuer's fiscal calendar ──────────────────────────────────────
select is(pg_temp.assess('North', array['books'], date '2019-06-01') ->> 'disposition', 'review_required',
  'without a book profile the fiscal calendar is assumed: a person reviews it');
select ok((pg_temp.assess('North', array['books'], date '2019-06-01') -> 'reasons') ? 'fiscal_calendar_assumed',
  'and the reason says so');
insert into public.book_profiles (workspace_id, issuer_site_id, functional_currency, fiscal_year_start_month,
                                  fiscal_year_start_day, accounting_basis, effective_from)
values (pg_temp.ws('Keep'), pg_temp.site('North'), 'EUR', 7, 1, 'accrual', '2010-01-01');
select is(pg_temp.assess('North', array['books'], date '2019-06-01') ->> 'retain_until', '2024-06-30',
  'the issuer''s year runs July to June: 2019-06-01 closes 2019-06-30, plus the 5 years in force that day');
select is(jsonb_array_length(pg_temp.assess('North', array['books'], date '2019-06-01') -> 'rules'), 2,
  'both versions apply: the one in force on the document date and the one in force today');
select is(pg_temp.assess('North', array['books'], date '2019-06-01') ->> 'disposition', 'eligible_for_erasure_review',
  'confirmed rules, every clock ended, no hold: eligible for the erasure review, nothing more');

-- ── two issuers, two rules ────────────────────────────────────────────
select is(pg_temp.assess('South', array['books'], date '2019-06-01') ->> 'retain_until', '2021-06-01',
  'the other issuer of the same space is under its own country''s rule');
select is(pg_temp.assess('South', array['books'], current_date - 30) ->> 'disposition', 'retain',
  'a document inside its clock is retained');
select ok((public.retention_assess(pg_temp.ws('Keep'), pg_temp.site('Elsewhere'), array['books'], date '2001-01-01') -> 'reasons') ? 'wrong_issuer',
  'another space''s site is not an issuer of this one');
select is(public.retention_assess(pg_temp.ws('Keep'), pg_temp.site('Elsewhere'), array['books'], date '2001-01-01') ->> 'disposition',
  'review_required', 'and the wrong issuer is reviewed, never erased');
select is(public.retention_assess(pg_temp.ws('Keep'), null, array['books'], date '2019-06-01') ->> 'issuer_site_id',
  pg_temp.site('North')::text, 'no issuer named: the default site');

-- ── what is missing is never a permission ─────────────────────────────
select is(pg_temp.assess('North', array['books'], null) ->> 'disposition', 'review_required',
  'no trigger date: review');
select ok((pg_temp.assess('North', array['books'], null) -> 'reasons') ? 'missing_trigger', 'named missing_trigger');
select is(pg_temp.assess('North', array['nope'], date '2001-01-01') ->> 'disposition', 'review_required',
  'a class no rule knows: review');
select ok((pg_temp.assess('North', array['nope'], date '2001-01-01') -> 'reasons') ? 'no_rule', 'named no_rule');
select is(pg_temp.assess('North', array['correspondence'], date '2001-01-01') ->> 'disposition', 'review_required',
  'an unconfirmed rule whose clock ended: review');
select ok((pg_temp.assess('North', array['correspondence'], date '2001-01-01') -> 'reasons') ? 'unconfirmed', 'named unconfirmed');
select is(public.retention_assess(pg_temp.ws('Nowhere'), null, array['books'], date '2001-01-01') ->> 'disposition',
  'review_required', 'the GB rows are unconfirmed: an old document of a real country is still reviewed');
update public.workspaces set country_code = 'BQ' where id = pg_temp.ws('Nowhere');
select ok((public.retention_assess(pg_temp.ws('Nowhere'), null, array['books'], date '2001-01-01') -> 'reasons') ? 'default_rule',
  'a country without rows falls to the shared default, which never authorises');

select ok((pg_temp.assess('North', array['archive'], date '1990-01-01') -> 'reasons') ? 'no_rule_on_date',
  'a document older than every version of its rule reads today''s rule, and says it is not its own');

-- ── overlapping rules: the latest end wins ────────────────────────────
select is(pg_temp.assess('North', array['books', 'invoice'], date '2019-06-01') ->> 'retain_until', '2026-06-01',
  'an invoice that is also a book entry: the 7-year invoice rule outlasts the books');

-- ── legal holds ───────────────────────────────────────────────────────
select pg_temp.act_as(pg_temp.u(2));
select throws_ok(format('select public.place_retention_hold(%L, null, null, ''audit'')', pg_temp.ws('Keep')),
  '42501', null, 'a member without billing rights places no hold');
reset role;
select pg_temp.act_as(pg_temp.u(3));
select throws_ok(format('select public.place_retention_hold(%L, null, null, ''audit'')', pg_temp.ws('Keep')),
  '42501', null, 'nor does a stranger');
select throws_ok(format('select public.place_retention_hold(%L, null, null, ''audit'')', pg_temp.ws('Other')),
  '0A000', null, 'with the accounting books off no hold is placed');
reset role;
select pg_temp.act_as(pg_temp.u(1));
select throws_ok(format('select public.place_retention_hold(%L, %L, null, ''audit'')', pg_temp.ws('Keep'), pg_temp.site('Elsewhere')),
  '22023', 'the issuer is not a site of this workspace', 'a hold names an issuer of this space');
select throws_ok(format('select public.place_retention_hold(%L, null, ''nope'', ''audit'')', pg_temp.ws('Keep')),
  '22023', 'no retention rule knows this class of record', 'and a class a rule knows');
select throws_ok(format('select public.place_retention_hold(%L, null, null, ''  '')', pg_temp.ws('Keep')),
  '22023', 'a hold names its reason', 'and its reason');
select set_config('t.hold', public.place_retention_hold(pg_temp.ws('Keep'), pg_temp.site('South'), 'books', 'tax audit 2026') ->> 'id', true);
select is(jsonb_array_length(public.retention_holds(pg_temp.ws('Keep'))), 1, 'the owner reads the hold');
select throws_ok(format('select public.place_retention_hold(%L, %L, ''books'', ''again'')', pg_temp.ws('Keep'), pg_temp.site('South')),
  '23505', 'this hold is already in place', 'a second hold of the same scope is refused, not stacked');
reset role;
select pg_temp.act_as(pg_temp.u(5));
select throws_ok(format('select public.place_retention_hold(%L, null, null, ''audit'')', pg_temp.ws('Keep')),
  '42501', null, 'reading the finances is not managing billing: no hold');
reset role;
select pg_temp.act_as(pg_temp.u(3));
select throws_ok(format('select public.retention_holds(%L)', pg_temp.ws('Keep')), '42501', null,
  'a stranger reads no hold');
select throws_ok(format('select public.release_retention_hold(%L, ''not mine'')', current_setting('t.hold')),
  '42501', null, 'and releases none');
reset role;
select is(pg_temp.assess('South', array['books'], date '2019-06-01') ->> 'disposition', 'retain',
  'an ended clock under a hold is retained');
select is((pg_temp.assess('South', array['books'], date '2019-06-01') ->> 'indefinite')::boolean, true,
  'with no end date');
select is(pg_temp.assess('North', array['books'], date '2019-06-01') ->> 'disposition', 'eligible_for_erasure_review',
  'a hold on one issuer leaves the other alone');
select is(pg_temp.assess('South', array['invoice'], date '2001-01-01') -> 'holds', '[]'::jsonb,
  'and a hold on the books leaves another class alone');
select pg_temp.act_as(pg_temp.u(2));
select throws_ok(format('select public.retention_holds(%L)', pg_temp.ws('Keep')), '42501', null,
  'a member without finance rights reads no hold');
reset role;

-- ── the destructive consumer: the reset refuses what must stay ────────
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, created_at, site_id)
select pg_temp.ws('Keep'), m.id, 'charge', 'subscription', 1000, 'old', '2019-06', '2019-06-01 12:00+02', pg_temp.site('South')
  from public.members m where m.user_id = pg_temp.u(1) and m.workspace_id = pg_temp.ws('Keep');
select pg_temp.act_as(pg_temp.u(1));
select throws_ok(format('select public.reset_workspace(%L)', pg_temp.ws('Keep')), 'DKE01',
  'retention: the books of this space are kept under a legal hold: tax audit 2026; nothing was deleted',
  'the reset refuses the held books and names the hold');
select lives_ok(format('select public.release_retention_hold(%L, ''audit closed'')', current_setting('t.hold')),
  'the owner releases the hold with a reason');
select throws_ok(format('select public.release_retention_hold(%L, ''again'')', current_setting('t.hold')),
  '55000', 'this hold is already released', 'a hold is released once');
select lives_ok(format('select public.reset_workspace(%L)', pg_temp.ws('Keep')),
  'released, every clock ended under confirmed rules: the reset runs');
reset role;
select is((select count(*)::int from public.ledger_entries where workspace_id = pg_temp.ws('Keep')), 0,
  'and the books are gone');
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, site_id)
select pg_temp.ws('Keep'), m.id, 'charge', 'subscription', 1000, 'this month', to_char(current_date, 'YYYY-MM'), pg_temp.site('South')
  from public.members m where m.user_id = pg_temp.u(4) and m.workspace_id = pg_temp.ws('Keep');
select pg_temp.act_as(pg_temp.u(1));
select throws_ok(format('select public.reset_workspace(%L)', pg_temp.ws('Keep')), 'DKE01',
  format('retention: the books of this space are kept until %s under synthetic ZY books rule; nothing was deleted',
         to_char((now() at time zone 'Europe/Paris')::date + interval '2 years', 'YYYY-MM-DD')),
  'a book entry of this month: refused, naming the rule and the day it ends');
reset role;
select is((select count(*)::int from public.ledger_entries where workspace_id = pg_temp.ws('Keep')), 1,
  'and the entry is still there');

-- ── erasure keeps the evidence, removes the person ────────────────────
update public.profiles set display_name = 'Erasable Person' where id = pg_temp.u(4);
select pg_temp.act_as(pg_temp.u(4));
select is(public.preview_my_erasure(pg_temp.ws('Keep')) -> 'retained' -> 1 -> 'retention' ->> 'disposition', 'retain',
  'the preview says the member''s ledger rows are retained');
select is(public.preview_my_erasure(pg_temp.ws('Keep')) -> 'retained' -> 1 ->> 'until',
  to_char((now() at time zone 'Europe/Paris')::date + interval '2 years', 'YYYY-MM-DD'),
  'until the day their issuer''s rule ends');
select lives_ok(format('select public.erase_my_membership(%L)', pg_temp.ws('Keep')), 'the member erases their membership');
reset role;
select is((select display_name from public.profiles where id = pg_temp.u(4)), '', 'their name is gone');
select is((select count(*)::int from public.ledger_entries where workspace_id = pg_temp.ws('Keep')), 1,
  'their ledger row stays as the space''s evidence');

select * from finish();
rollback;
