-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2573 (migration 9999): a purchase line names where its cost belongs, and a
-- member's receipt carries several tax rates and classes. Real roles (definer
-- RPCs and the RLS reads run as `authenticated`), a readback after every
-- refusal:
--   P a member saves and submits a receipt of four lines (20 % cleaning in an
--     office, 5.5 % books for another site, half-deductible 20 % equipment,
--     zero-rated stamps); the lines keep their classes and places and sum
--     exactly; the expense event states no rate of its own; once approved the
--     input-VAT source reads the receipt's lines, one row per rate and class,
--     and nothing from the event. A replayed submit files no second event. A
--     one-rate receipt still files its one-rate payload; input VAT off files
--     none.
--   K the books (compute_postings): equipment with no fixed-assets account
--     blocks the receipt, named, and is never booked as an expense; mapped,
--     it debits fixed assets; operating lines book as before.
--   R a taxed line without its tax or rate, tax amounts that do not follow
--     from the rate, an unqualified deductible share; a resource or a site of
--     another workspace, a resource of another site, a half-named or unknown
--     resource; another workspace's owner reading the detail; a client write.
-- Seeds are direct inserts as postgres (users, workspaces, members, sites,
-- levels, an office, A's book accounts and mappings); the workspaces switch on every flag the RPCs gate on
-- and its parents: purchases under moneyTab, inputVat under vatDeclarations
-- under vatManagement under invoicing. The expense validation's outcome is
-- seeded on the event (pgTAP 206 proves the validation path itself).
begin;
select plan(38);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002573' || lpad((9000 + n)::text, 4, '0'))::uuid;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- The refusal text of running [p_sql] as [p_user]; '' when it worked.
create function pg_temp.as_err(p_user uuid, p_sql text) returns text
language plpgsql as $$
begin
  perform pg_temp.act_as(p_user);
  execute p_sql;
  reset role;
  return '';
exception when others then
  reset role;
  return sqlerrm;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- The jsonb [p_sql] returns as [p_user]; {"error": ...} when it is refused.
create function pg_temp.as_json(p_user uuid, p_sql text) returns jsonb
language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.act_as(p_user);
  execute p_sql into v;
  reset role;
  return v;
exception when others then
  reset role;
  return jsonb_build_object('error', sqlerrm);
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- Saves a member receipt of [p_lines] as member 2 of A under request [p_req].
create function pg_temp.save(p_req int, p_lines jsonb) returns jsonb language sql as $$
  select pg_temp.as_json(pg_temp.u(2), format(
    'select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', current_setting('t.a'),
    ('a0000000-0000-4000-8000-00000000' || lpad(p_req::text, 4, '0'))::uuid,
    jsonb_build_object('kind', 'member_receipt', 'category', 'supplies', 'original_date', current_date,
                       'lines', p_lines)::text));
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- Submits draft [p_purchase] at revision 1 as member 2 under request [p_req].
create function pg_temp.submit(p_req int, p_purchase text) returns jsonb language sql as $$
  select pg_temp.as_json(pg_temp.u(2), format(
    'select public.submit_purchase_v1(%L, %L, 1, %L)', current_setting('t.a'), p_purchase,
    ('a0000000-0000-4000-8000-00000000' || lpad(p_req::text, 4, '0'))::uuid));
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- One line: gross, net, tax, rate, recoverable, class, then its place.
create function pg_temp.line(p_gross int, p_net int, p_tax int, p_rate numeric, p_rec int,
                             p_kind text, p_place jsonb default '{}') returns jsonb language sql as $$
  select jsonb_strip_nulls(jsonb_build_object('description', p_kind, 'gross_cents', p_gross,
    'net_cents', p_net, 'tax_cents', p_tax, 'tax_rate_percent', p_rate,
    'recoverable_tax_cents', p_rec, 'recognition_kind', p_kind)) || p_place;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.events_of_a() returns int language sql as $$
  select count(*)::int from public.events
   where workspace_id = current_setting('t.a')::uuid and type = 'expense';
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.docs_of_a() returns int language sql as $$
  select count(*)::int from public.purchase_documents
   where workspace_id = current_setting('t.a')::uuid;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- The postings of document [p_doc] in A's books today: code:Dn / code:Cn.
create function pg_temp.posted(p_doc text) returns text language sql as $$
  select coalesce(string_agg((l ->> 'account_code') || ':' ||
           case when (l ->> 'debit_cents')::bigint > 0 then 'D' || (l ->> 'debit_cents') else 'C' || (l ->> 'credit_cents') end,
           ',' order by n), '')
    from jsonb_array_elements(pg_temp.as_json(pg_temp.u(1), format('select public.compute_postings(%L, %L, %L, %L)',
           current_setting('t.a'), current_setting('t.site_a1'), current_date - 1, current_date + 1)) -> 'postings') p,
         jsonb_array_elements(p -> 'lines') with ordinality z(l, n)
   where p ->> 'document_id' = p_doc;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.blockers() returns text language sql as $$
  select coalesce(string_agg((b ->> 'block') || ':' || (b ->> 'subject'), ',' order by b ->> 'block', b ->> 'subject'), '')
    from jsonb_array_elements(pg_temp.as_json(pg_temp.u(1), format('select public.compute_postings(%L, %L, %L, %L)',
           current_setting('t.a'), current_setting('t.site_a1'), current_date - 1, current_date + 1)) -> 'blockers') b;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.book(p_role text, p_code text, p_type text) returns void language sql as $$
  insert into public.book_accounts (workspace_id, issuer_site_id, code, name, account_type)
  values (current_setting('t.a')::uuid, current_setting('t.site_a1')::uuid, p_code, p_code, p_type);
  insert into public.book_mappings (workspace_id, issuer_site_id, role, account_id, effective_from)
  select current_setting('t.a')::uuid, current_setting('t.site_a1')::uuid, p_role, a.id, date '2020-01-01'
    from public.book_accounts a
   where a.issuer_site_id = current_setting('t.site_a1')::uuid and a.code = p_code;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@purchase-places.test', '', now(), now(), now()
  from generate_series(1, 3) i;
-- 1 owner of A, 2 a plain member of A, 3 owner of B.

select set_config('t.a', '00000000-0000-4000-8000-0000257390a1', true);
select set_config('t.b', '00000000-0000-4000-8000-0000257390b1', true);
select set_config('t.site_a1', '00000000-0000-4000-8000-0000257391a1', true);
select set_config('t.site_a2', '00000000-0000-4000-8000-0000257391a2', true);
select set_config('t.site_b1', '00000000-0000-4000-8000-0000257391b1', true);
select set_config('t.level_a1', '00000000-0000-4000-8000-0000257392a1', true);
select set_config('t.level_b1', '00000000-0000-4000-8000-0000257392b1', true);
select set_config('t.office_a1', '00000000-0000-4000-8000-0000257393a1', true);

insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment, feature_flags)
values (current_setting('t.a')::uuid, 'Purchase places A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'dev',
        '{"moneyTab": true, "purchases": true, "invoicing": true, "vatManagement": true, "vatDeclarations": true, "inputVat": true}'::jsonb),
       (current_setting('t.b')::uuid, 'Purchase places B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(3), 'dev',
        '{"moneyTab": true, "purchases": true, "invoicing": true, "vatManagement": true, "vatDeclarations": true, "inputVat": true}'::jsonb);

insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values
 (current_setting('t.a')::uuid, pg_temp.u(1), true, true, 'active'),
 (current_setting('t.a')::uuid, pg_temp.u(2), false, false, 'active'),
 (current_setting('t.b')::uuid, pg_temp.u(3), true, true, 'active');

insert into public.sites (id, workspace_id, name) values
 (current_setting('t.site_a1')::uuid, current_setting('t.a')::uuid, 'Rue Haute'),
 (current_setting('t.site_a2')::uuid, current_setting('t.a')::uuid, 'Quai Bas'),
 (current_setting('t.site_b1')::uuid, current_setting('t.b')::uuid, 'Elsewhere');
-- Rue Haute is A's default issuer: it books A's purchases.
update public.sites set is_default = false where workspace_id = current_setting('t.a')::uuid;
update public.sites set is_default = true where id = current_setting('t.site_a1')::uuid;
select pg_temp.book('customers', '411', 'asset');
select pg_temp.book('expenses', '606', 'expense');
select pg_temp.book('vat_input', '44566', 'asset');
insert into public.levels (id, workspace_id, name, site_id) values
 (current_setting('t.level_a1')::uuid, current_setting('t.a')::uuid, 'Ground floor', current_setting('t.site_a1')::uuid),
 (current_setting('t.level_b1')::uuid, current_setting('t.b')::uuid, 'B floor', current_setting('t.site_b1')::uuid);
insert into public.offices (id, workspace_id, level_id, name, x, y, w, h) values
 (current_setting('t.office_a1')::uuid, current_setting('t.a')::uuid, current_setting('t.level_a1')::uuid,
  'Blue room', 0, 0, 10, 10);

-- ── P: a receipt of several rates and classes ──────────────────────────
select set_config('t.mixed', pg_temp.save(1, jsonb_build_array(
  pg_temp.line(12000, 10000, 2000, 20, 2000, 'operating',
    jsonb_build_object('resource_kind', 'office', 'resource_id', current_setting('t.office_a1'))),
  pg_temp.line(1055, 1000, 55, 5.5, 55, 'operating',
    jsonb_build_object('cost_site_id', current_setting('t.site_a2'))),
  pg_temp.line(24000, 20000, 4000, 20, 2000, 'asset'),
  pg_temp.line(300, 300, 0, 0, 0, 'operating')))::text, true);
select is(current_setting('t.mixed')::jsonb ->> 'state', 'draft',
  'P1 golden: a member saves a receipt of four lines at three rates, equipment beside the rest');
select set_config('t.pm', current_setting('t.mixed')::jsonb ->> 'purchase_id', true);
select is((select string_agg(concat_ws(':', l.line_no, l.recognition_kind, coalesce(l.resource_kind, '-'),
                                        coalesce(l.cost_site_id::text, '-')), ',' order by l.line_no)
             from public.purchase_lines l where l.purchase_id = current_setting('t.pm')::uuid),
  '1:operating:office:' || current_setting('t.site_a1') || ',2:operating:-:' || current_setting('t.site_a2')
  || ',3:asset:-:-,4:operating:-:-',
  'P2 each line keeps its class; the office names its site, a site alone is kept');
select is((select sum(gross_cents)::int from public.purchase_lines where purchase_id = current_setting('t.pm')::uuid),
  37355, 'P3 the lines sum exactly');
select is((select string_agg(e ->> 'place_name', ',' order by (e ->> 'line_no')::int)
             from jsonb_array_elements(pg_temp.as_json(pg_temp.u(2), format('select public.purchase_detail_v1(%L, %L)',
               current_setting('t.a'), current_setting('t.pm'))) -> 'lines') e),
  'Blue room,Quai Bas,,', 'P4 the submitter reads the place of each line by its name');
select set_config('t.sm', pg_temp.submit(2, current_setting('t.pm'))::text, true);
select is(coalesce(current_setting('t.sm')::jsonb ->> 'error', current_setting('t.sm')::jsonb ->> 'state'), 'pending',
  'P5 golden: submitting it files the expense; the receipt awaits its validation');
select is((select (e.payload ->> 'amount_cents') || '/' || (e.payload -> 'vat')::text || '/' || (e.payload ->> 'purchase_id')
             from public.events e where e.id = (current_setting('t.sm')::jsonb ->> 'event_id')::uuid),
  '37355/{"source": "lines"}/' || current_setting('t.pm'),
  'P6 the event carries the whole amount and says its tax lies on the lines, with no rate of its own');
select is(pg_temp.submit(2, current_setting('t.pm')), current_setting('t.sm')::jsonb,
  'P7 replaying the submit returns the committed result');
select is(pg_temp.events_of_a(), 1, 'P8 and files no second event');
update public.events set status = 'confirmed', decided_at = now()
 where id = (current_setting('t.sm')::jsonb ->> 'event_id')::uuid;
select is((select state from public.purchase_documents where id = current_setting('t.pm')::uuid), 'approved',
  'P9 the validation approves the receipt');
select is((select string_agg(concat_ws('/', v.percent, v.category, v.gross_cents, v.net_cents), ','
                             order by v.percent, v.category collate "C")
             from public.vat_input_amounts(current_setting('t.a')::uuid, current_date - 1, current_date + 1) v
            where v.expense_id = (current_setting('t.sm')::jsonb ->> 'event_id')::uuid),
  '5.5/S/1055/1000,20/S/12000/10000,20/asset/22000/20000',
  'P10 input VAT: 0.55 on 10.00 at 5.5 %, 20.00 on 100.00 at 20 %, half of 40.00 on the equipment; the zero-rated line adds none');
select is((select count(*)::int from public.vat_input_amounts(current_setting('t.a')::uuid, current_date - 1, current_date + 1) v
            where v.expense_id = (current_setting('t.sm')::jsonb ->> 'event_id')::uuid), 3,
  'P11 the lines replace the event''s input: no fourth row from the event itself');

-- a one-rate receipt keeps its one-rate payload
select set_config('t.one', pg_temp.save(3, jsonb_build_array(
  pg_temp.line(6000, 5000, 1000, 20, 1000, 'operating'),
  pg_temp.line(1200, 1000, 200, 20, 200, 'operating')))::text, true);
select set_config('t.so', pg_temp.submit(4, current_setting('t.one')::jsonb ->> 'purchase_id')::text, true);
select is(coalesce(current_setting('t.so')::jsonb ->> 'error',
                   (select (e.payload -> 'vat')::text from public.events e where e.id = (current_setting('t.so')::jsonb ->> 'event_id')::uuid)),
  '{"percent": 20, "deductible_pct": 100}', 'P12 a receipt of one rate and one class files ONE rate and share, as before');
update public.events set status = 'confirmed', decided_at = now()
 where id = (current_setting('t.so')::jsonb ->> 'event_id')::uuid;
select is((select string_agg(concat_ws('/', v.percent, v.category, v.gross_cents, v.net_cents), ',')
             from public.vat_input_amounts(current_setting('t.a')::uuid, current_date - 1, current_date + 1) v
            where v.expense_id = (current_setting('t.so')::jsonb ->> 'event_id')::uuid),
  '20/S/7200/6000', 'P13 and its input VAT is read from that payload, once');

-- ── K: what a line is for decides its debit ────────────────────────────
select ok(pg_temp.blockers() like '%unmappedRole:fixed_assets%',
  'K1 equipment with no fixed-assets account blocks the receipt, named');
select ok(pg_temp.posted(current_setting('t.pm')) not like '%22000%',
  'K2 and the equipment is never booked as an operating cost');
select pg_temp.book('fixed_assets', '2183', 'asset');
select is(pg_temp.posted(current_setting('t.pm')), '606:D10000,44566:D2000,606:D1000,44566:D55,2183:D22000,44566:D2000,606:D300,411:C37355',
  'K3 mapped, the equipment debits fixed assets: cost 200.00 plus the 20.00 not recovered');
select is(pg_temp.posted(current_setting('t.so')::jsonb ->> 'purchase_id'), '606:D5000,44566:D1000,606:D1000,44566:D200,411:C7200',
  'K4 a receipt of operating lines books its expenses as before');

-- a receipt with equipment and no tax at all
select set_config('t.notax', pg_temp.save(5, jsonb_build_array(
  pg_temp.line(5000, 5000, 0, 0, 0, 'asset'),
  pg_temp.line(800, 800, 0, 0, 0, 'operating')))::text, true);
select set_config('t.sn', pg_temp.submit(6, current_setting('t.notax')::jsonb ->> 'purchase_id')::text, true);
select is((select (e.payload ? 'vat')::text || '/' || (e.payload ->> 'amount_cents')
             from public.events e where e.id = (current_setting('t.sn')::jsonb ->> 'event_id')::uuid),
  'false/5800', 'P14 equipment beside other untaxed lines is filed, with no VAT');

-- ── R: refusals ────────────────────────────────────────────────────────
select set_config('t.unstated', pg_temp.save(7, jsonb_build_array(
  pg_temp.line(12000, 10000, 2000, 20, 2000, 'operating'),
  jsonb_build_object('description', 'Taxi', 'gross_cents', 2500, 'recognition_kind', 'operating')))::text, true);
select ok(pg_temp.submit(8, current_setting('t.unstated')::jsonb ->> 'purchase_id') ->> 'error' like '%state the tax and the rate%',
  'R1 a taxed receipt with a line whose tax is not stated is refused');
select is((select state from public.purchase_documents where id = (current_setting('t.unstated')::jsonb ->> 'purchase_id')::uuid),
  'draft', 'R1 readback: still a draft');
select set_config('t.norate', pg_temp.save(9, jsonb_build_array(
  pg_temp.line(1200, 1000, 200, 0, 200, 'operating')))::text, true);
select ok(pg_temp.submit(10, current_setting('t.norate')::jsonb ->> 'purchase_id') ->> 'error' like '%state the tax and the rate%',
  'R2 a taxed line at no stated rate is refused');
select set_config('t.drift', pg_temp.save(11, jsonb_build_array(
  pg_temp.line(1000, 900, 100, 20, 100, 'operating'),
  pg_temp.line(1055, 1000, 55, 5.5, 55, 'operating')))::text, true);
select ok(pg_temp.submit(12, current_setting('t.drift')::jsonb ->> 'purchase_id') ->> 'error' like '%do not follow from the rate%',
  'R3 tax amounts that do not follow from their rate are refused');
select set_config('t.unq', pg_temp.save(13, jsonb_build_array(
  pg_temp.line(1200, 1000, 200, 20, null, 'operating'),
  pg_temp.line(1055, 1000, 55, 5.5, 55, 'operating')))::text, true);
select ok(pg_temp.submit(14, current_setting('t.unq')::jsonb ->> 'purchase_id') ->> 'error' like '%qualify the deductible tax%',
  'R4 an unqualified deductible share is refused, never defaulted');
select is(pg_temp.events_of_a(), 3, 'R1-R4 readback: none of them filed an expense');
select set_config('t.docs', pg_temp.docs_of_a()::text, true);
select ok(pg_temp.save(15, jsonb_build_array(pg_temp.line(1200, 1000, 200, 20, 200, 'operating',
    jsonb_build_object('resource_kind', 'level', 'resource_id', current_setting('t.level_b1'))))) ->> 'error' like '%unknown resource%',
  'R5 a level of another workspace is refused');
select ok(pg_temp.save(16, jsonb_build_array(pg_temp.line(1200, 1000, 200, 20, 200, 'operating',
    jsonb_build_object('cost_site_id', current_setting('t.site_b1'))))) ->> 'error' like '%unknown site%',
  'R6 a site of another workspace is refused');
select ok(pg_temp.save(17, jsonb_build_array(pg_temp.line(1200, 1000, 200, 20, 200, 'operating',
    jsonb_build_object('resource_kind', 'office', 'resource_id', current_setting('t.office_a1'),
                       'cost_site_id', current_setting('t.site_a2'))))) ->> 'error' like '%another site%',
  'R7 an office of one site named for another is refused');
select ok(pg_temp.save(18, jsonb_build_array(pg_temp.line(1200, 1000, 200, 20, 200, 'operating',
    jsonb_build_object('resource_kind', 'office')))) ->> 'error' like '%kind and its id%',
  'R8 a resource named by its kind alone is refused');
select ok(pg_temp.save(19, jsonb_build_array(pg_temp.line(1200, 1000, 200, 20, 200, 'operating',
    jsonb_build_object('resource_kind', 'room', 'resource_id', current_setting('t.office_a1'))))) ->> 'error' like '%unknown resource kind%',
  'R9 a kind of resource that does not exist is refused');
select ok(pg_temp.save(20, jsonb_build_array(pg_temp.line(1200, 1000, 200, 20, 200, 'operating',
    jsonb_build_object('resource_kind', 'desk', 'resource_id', current_setting('t.office_a1'))))) ->> 'error' like '%unknown resource%',
  'R10 an office named as a desk is not a desk of the space');
select is(pg_temp.docs_of_a(), current_setting('t.docs')::int, 'R5-R10 readback: no draft was saved');
select ok(pg_temp.as_json(pg_temp.u(3), format('select public.purchase_detail_v1(%L, %L)',
    current_setting('t.a'), current_setting('t.pm'))) ->> 'error' like '%unknown purchase%',
  'R11 the owner of another workspace does not read the receipt');
select ok(pg_temp.as_json(pg_temp.u(1), format('select public.purchase_detail_v1(%L, %L)',
    current_setting('t.a'), current_setting('t.pm'))) -> 'lines' -> 0 ->> 'place_name' = 'Blue room',
  'R11 positive control: the owner of A does');
select ok(pg_temp.as_err(pg_temp.u(2), format('update public.purchase_lines set cost_site_id = %L where purchase_id = %L',
    current_setting('t.site_a1'), current_setting('t.pm'))) like '%permission denied%',
  'R12 a client cannot write a line''s place directly');
select is((select cost_site_id::text from public.purchase_lines where purchase_id = current_setting('t.pm')::uuid and line_no = 2),
  current_setting('t.site_a2'), 'R12 readback: unchanged');
select is((select count(*)::int from public.purchase_lines l
            where l.workspace_id = current_setting('t.a')::uuid and l.cost_site_id is not null
              and not exists (select 1 from public.sites s where s.id = l.cost_site_id and s.workspace_id = l.workspace_id)), 0,
  'R13 no line of A names a site outside A');

-- input VAT off: the receipt files no VAT at all
update public.workspaces set feature_flags = feature_flags || '{"inputVat": false}'::jsonb
 where id = current_setting('t.a')::uuid;
select set_config('t.off', pg_temp.save(21, jsonb_build_array(
  pg_temp.line(1200, 1000, 200, 20, 200, 'operating'),
  pg_temp.line(1055, 1000, 55, 5.5, 55, 'operating')))::text, true);
select set_config('t.soff', pg_temp.submit(22, current_setting('t.off')::jsonb ->> 'purchase_id')::text, true);
select is((select (e.payload ? 'vat')::text from public.events e where e.id = (current_setting('t.soff')::jsonb ->> 'event_id')::uuid),
  'false', 'R14 with input VAT off a mixed receipt files its expense with no VAT');
select is(pg_temp.events_of_a(), 4, 'R14 positive control: and it was filed');

select * from finish();
rollback;
