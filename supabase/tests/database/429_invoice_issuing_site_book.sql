-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3968 (0770) -- an invoice posts in the book of its own issuing site only.
-- Two sites with a book each and a member whose home is the second site: the
-- member's invoice carries the second site, from its seller block, and is in
-- the second book's postings and not in the first's. A credit note follows
-- its invoice; an invoice issued before 0770 takes the site its seller block
-- names, else the default site. A business with one site posts as before.
-- Rolled back.
begin;
select plan(14);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  owner uuid := '00000000-0000-4000-8000-000000003968';
  person_b uuid := '00000000-0000-4000-8000-000000003969';
  person_one uuid := '00000000-0000-4000-8000-000000003970';
  ws uuid; site_a uuid; site_b uuid; member_b uuid;
  one uuid; one_member uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'books-' || right(u::text, 4) || '@deskilo.test', '', now(), now(), now()
    from unnest(array[owner, person_b, person_one]) u;
  insert into public.profiles (id, display_name) values (person_b, 'Bea Site'), (person_one, 'Una Site')
  on conflict (id) do update set display_name = excluded.display_name;
  -- two issuing sites, a book each
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by,
                                 street, city, postal_code, vat_regime, feature_flags)
  values ('BOOKS-TWO-SITES', 'FR', 'EUR', 'Europe/Paris', owner, '1 rue A', 'Pézenas', '34120',
          'not_subject', '{"invoicing": true}') returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at)
  values (ws, owner, true, true, '2026-01-01');
  select id into site_a from public.sites where workspace_id = ws and is_default;
  if site_a is null then
    insert into public.sites (workspace_id, name, country_code, is_default)
    values (ws, 'Site A', 'FR', true) returning id into site_a;
  end if;
  insert into public.sites (workspace_id, name, street, postal_code, city, country_code, sort_order)
  values (ws, 'Site B', '2 rue B', '34000', 'Montpellier', 'FR', 1) returning id into site_b;
  insert into public.book_profiles (workspace_id, issuer_site_id, functional_currency,
                                    fiscal_year_start_month, fiscal_year_start_day, accounting_basis, effective_from)
  values (ws, site_a, 'EUR', 1, 1, 'accrual', '2020-01-01'),
         (ws, site_b, 'EUR', 1, 1, 'accrual', '2020-01-01');
  insert into public.members (workspace_id, user_id, home_site_id, subscription_pct, joined_at)
  values (ws, person_b, site_b, 100, '2026-01-01') returning id into member_b;
  delete from public.fee_bands where workspace_id = ws;
  insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents, overage_fee_cents)
  values (ws, 0, 100, 3500, 1000);
  -- one site
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by,
                                 street, city, postal_code, vat_regime, feature_flags)
  values ('BOOKS-ONE-SITE', 'FR', 'EUR', 'Europe/Paris', owner, '3 rue C', 'Sète', '34200',
          'not_subject', '{"invoicing": true}') returning id into one;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at)
  values (one, owner, true, true, '2026-01-01');
  if not exists (select 1 from public.sites where workspace_id = one and is_default) then
    insert into public.sites (workspace_id, name, country_code, is_default) values (one, 'Sète', 'FR', true);
  end if;
  insert into public.members (workspace_id, user_id, subscription_pct, joined_at)
  values (one, person_one, 100, '2026-01-01') returning id into one_member;
  delete from public.fee_bands where workspace_id = one;
  insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents, overage_fee_cents)
  values (one, 0, 100, 3500, 1000);
  perform set_config('deskilo.test.ws', ws::text, false);
  perform set_config('deskilo.test.site_a', site_a::text, false);
  perform set_config('deskilo.test.site_b', site_b::text, false);
  perform set_config('deskilo.test.member_b', member_b::text, false);
  perform set_config('deskilo.test.one', one::text, false);
  perform set_config('deskilo.test.one_member', one_member::text, false);
  perform set_config('deskilo.test.owner', owner::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.id(p text) returns uuid language sql as $$
  select current_setting('deskilo.test.' || p)::uuid
$$;
create or replace function pg_temp.postings(p_ws text, p_site uuid) returns text language sql as $$
  select public.compute_postings(pg_temp.id(p_ws), p_site, current_date - 1, current_date + 1)::text
$$;
create or replace function pg_temp.invoice_of(p_member text) returns public.invoices language sql as $$
  -- the invoice create_invoice issued: the test's own rows are numbered BOOKS-*
  select i from public.invoices i where i.member_id = pg_temp.id(p_member) and i.number not like 'BOOKS-%'
$$;
grant execute on all functions in schema pg_temp to authenticated;

select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('deskilo.test.owner'), 'role', 'authenticated')::text, true);
set local role authenticated;
select public.create_invoice(pg_temp.id('ws'), pg_temp.id('member_b'), '2026-10');
select public.create_invoice(pg_temp.id('one'), pg_temp.id('one_member'), '2026-10');

-- ── two sites ──
select is((pg_temp.invoice_of('member_b')).site_id, pg_temp.id('site_b'),
  'the invoice of a member of the second site carries that site');
select is((pg_temp.invoice_of('member_b')).parties #>> '{seller,site_id}', pg_temp.id('site_b')::text,
  'the site its seller block names');
select ok(position((pg_temp.invoice_of('member_b')).number in pg_temp.postings('ws', pg_temp.id('site_b'))) > 0,
  'it posts in the second site''s book');
select ok(position((pg_temp.invoice_of('member_b')).number in pg_temp.postings('ws', pg_temp.id('site_a'))) = 0,
  'and not in the first site''s');

-- ── one site: as before ──
select is((pg_temp.invoice_of('one_member')).site_id,
  (select id from public.sites where workspace_id = pg_temp.id('one') and is_default),
  'a business with one site issues from it');
select set_config('deskilo.test.one_after',
  pg_temp.postings('one', (pg_temp.invoice_of('one_member')).site_id), false);
reset role;
-- the same invoice as one issued before 0770, with no site (test data: the
-- guard is lifted for this row's change and armed again)
alter table public.invoices disable trigger invoices_no_mutation;
update public.invoices set site_id = null where member_id = pg_temp.id('one_member');
alter table public.invoices enable trigger invoices_no_mutation;
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('deskilo.test.owner'), 'role', 'authenticated')::text, true);
set local role authenticated;
select is(pg_temp.postings('one', (select id from public.sites where workspace_id = pg_temp.id('one') and is_default)),
  current_setting('deskilo.test.one_after'),
  'its book posts the same whether the invoice names its site or not');
reset role;

-- ── a credit note, an invoice issued before ──
insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                             currency, member_name, workspace_name, issuer_name, signature,
                             replaces_invoice_id, replaces_number, parties)
select i.workspace_id, i.member_id, i.member_id, 'BOOKS-CN-0001', 'Credit', '[]'::jsonb, -i.total_cents,
       i.currency, i.member_name, i.workspace_name, i.issuer_name, 'sig', i.id, i.number, '{}'::jsonb
  from public.invoices i where i.id = (pg_temp.invoice_of('member_b')).id;
select is((select site_id from public.invoices where number = 'BOOKS-CN-0001'), pg_temp.id('site_b'),
  'a credit note follows the invoice it replaces');
insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                             currency, member_name, workspace_name, issuer_name, signature, parties, site_id)
select i.workspace_id, i.member_id, i.member_id, n, 'Named', '[]'::jsonb, 0, i.currency, i.member_name,
       i.workspace_name, i.issuer_name, 'sig', i.parties, s
  from public.invoices i,
       (values ('BOOKS-NAMED-0001', pg_temp.id('site_a')),
               ('BOOKS-NAMED-0002', (select id from public.sites
                                      where workspace_id = pg_temp.id('one') and is_default))) v(n, s)
 where i.id = (pg_temp.invoice_of('member_b')).id;
select is((select site_id from public.invoices where number = 'BOOKS-NAMED-0001'), pg_temp.id('site_a'),
  'a site of the business the server names for an invoice stays');
select is((select site_id from public.invoices where number = 'BOOKS-NAMED-0002'), pg_temp.id('site_b'),
  'a site of another business gives way to the one its seller block names');
select is(public.invoice_issuing_site(pg_temp.id('ws'),
            '{"seller": {"site": "Site B", "site_default": false}}'::jsonb),
  pg_temp.id('site_b'), 'an invoice issued before takes the site its seller block names');
select is(public.invoice_issuing_site(pg_temp.id('ws'), '{"seller": {"site": "", "site_default": true}}'::jsonb),
  pg_temp.id('site_a'), 'and the default site where it names none');

-- ── the stamp of an invoice that has none ──
-- the one-site invoice has no site since the case above. A signed-in caller
-- has no update of invoices at all; the privilege and a policy are given for
-- this test only, to reach the guard itself as one.
grant update on public.invoices to authenticated;
create policy invoices_update_for_this_test on public.invoices for update to authenticated
  using (true) with check (true);
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('deskilo.test.owner'), 'role', 'authenticated')::text, true);
set local role authenticated;
select throws_ok(format($$update public.invoices set site_id = %L where member_id = %L$$,
    (select id from public.sites where workspace_id = pg_temp.id('one') and is_default), pg_temp.id('one_member')),
  'P0001', 'invoices are immutable', 'a signed-in caller does not choose the book of an invoice');
reset role;
drop policy invoices_update_for_this_test on public.invoices;
revoke update on public.invoices from authenticated;
select lives_ok(format($$update public.invoices set site_id = %L where member_id = %L$$,
    (select id from public.sites where workspace_id = pg_temp.id('one') and is_default), pg_temp.id('one_member')),
  'the server stamps the site of an invoice that has none');
select throws_ok(format($$update public.invoices set site_id = %L where member_id = %L$$,
    pg_temp.id('site_b'), pg_temp.id('one_member')),
  'P0001', 'invoices are immutable', 'and only once');

select * from finish();
rollback;
