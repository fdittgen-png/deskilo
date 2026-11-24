-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4165 (0820, A1): a standalone customer invoice. A named customer, itemised
-- ad hoc lines, explicit dates, no member-month. The server computes every
-- amount from exact decimals and freezes the commercial v1 facts; the same
-- request replays, another payload under it is refused, a stale revision
-- refuses before a number is taken, two deliberate invoices of one customer
-- and month coexist with the monthly one, and no client writes a draft.
begin;
select plan(38);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00004165' || lpad(n::text, 4, '0'))::uuid;
$$;
-- The business's own day, by the server's own rule: every date a test gives a quote or an
-- invoice is compared with it, never with the database clock's UTC date, so the verdict is
-- the same at any hour of the day (#4307).
create function pg_temp.today() returns date language sql stable security definer as $$
  select public.workspace_today(pg_temp.u(101))
$$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'sa' || n || '@example.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags,
                               vat_regime, vat_id, legal_id, street, city, postal_code, address)
values (pg_temp.u(101), 'Standalone 4165', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"invoicing": true, "standaloneInvoicing": true}',
        'vat_registered', 'FR40303265045', '30326504500014', '4 avenue de Castelnau', 'Pézenas', '34120',
        '4 avenue de Castelnau, 34120 Pézenas'),
       (pg_temp.u(102), 'Other 4165', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4), '{"invoicing": true, "standaloneInvoicing": true}',
        'vat_registered', 'FR40303265045', '30326504500014', '4 avenue de Castelnau', 'Pézenas', '34120',
        '4 avenue de Castelnau, 34120 Pézenas');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active', '2026-01-01'),
       (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, false, 'active', '2026-01-01'),
       (pg_temp.u(204), pg_temp.u(102), pg_temp.u(4), true, true, 'active', '2026-01-01');
update public.profiles set display_name = 'Ana Martin', company = 'Martin SAS', street = '1 rue X',
       postal_code = '75001', city = 'Paris', country_code = 'FR', legal_id = '12345678900012'
 where id = pg_temp.u(3);
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, active, valid_from)
values (pg_temp.u(301), pg_temp.u(101), 'Normal 20 %', 20, 'S', true, true, '2000-01-01')
on conflict do nothing;

create function pg_temp.as_user(n int, p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(n), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  execute 'reset role';
  return coalesce(nullif(v, ''), 'ok');
exception when others then
  execute 'reset role';
  return 'ERR ' || sqlstate || ' ' || coalesce(nullif(substr(sqlerrm, 1, 60), ''), '');
end $f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.line(p_qty text, p_price text, p_basis text default 'net', p_supply text default 'general',
                             p_base text default '1') returns jsonb language sql as $$
  select jsonb_build_object('description', 'Consulting', 'quantity', p_qty, 'unit_price', p_price,
    'basis', p_basis, 'supply', p_supply, 'base_quantity', p_base,
    'unit', jsonb_build_object('code', 'hour', 'label', 'h', 'un_ece_code', 'HUR'))
$$;
create function pg_temp.save(p_lines jsonb, p_draft uuid default null, p_rev int default null) returns jsonb
language plpgsql as $f$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(1), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  v := public.save_standalone_invoice_draft_v1(pg_temp.u(101), p_draft, p_rev, pg_temp.u(203),
        pg_temp.today(), pg_temp.today() + 30, 'PO-1', 'ORD-9', p_lines);
  execute 'reset role';
  return v;
end $f$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.numbers() returns text language sql as $$
  select (select count(*) from public.invoices where workspace_id = pg_temp.u(101))::text || '|' ||
         coalesce((select next_value::text from public.number_sequences
                    where workspace_id = pg_temp.u(101) and journal = 'invoice'), '-')
$$;

-- ── the draft ──
select set_config('d.a', (pg_temp.save(jsonb_build_array(pg_temp.line('1.5', '80')))) ->> 'draft_id', false);
select is((select revision from public.standalone_invoice_drafts where id = current_setting('d.a')::uuid), 1,
  'a saved draft starts at revision 1');
select ok((select (lines -> 0 ->> 'line_id') is not null from public.standalone_invoice_drafts
            where id = current_setting('d.a')::uuid), 'every line gets a stable line_id');

-- ── the preview ──
select set_config('p.a', public.preview_standalone_invoice_v1(pg_temp.u(101), current_setting('d.a')::uuid, 1)::text, false);
select is(current_setting('p.a')::jsonb -> 'missing', '[]'::jsonb, 'the preview finds nothing missing: '
  || (current_setting('p.a')::jsonb -> 'missing')::text);
select is((current_setting('p.a')::jsonb #>> '{preview,total_cents}')::int, 14400,
  '1.5 h at 80.00 net, 20 %: the gross is 144.00');
select is(current_setting('p.a')::jsonb #>> '{preview,lines,0,commercial,amounts,net_minor}', '12000',
  'the frozen net is 120.00 in minor units, as text');
select is(current_setting('p.a')::jsonb #>> '{preview,lines,0,commercial,quantity}', '1.5', 'the exact quantity is frozen');
select is(pg_temp.numbers(), '0|-', 'a preview takes no number and leaves no invoice');

-- ── issue ──
select set_config('i.a', public.issue_standalone_invoice_v1(pg_temp.u(101), current_setting('d.a')::uuid, 1,
  '00000000-0000-4000-8000-000000004165'::uuid)::text, false);
select is((select source || '|' || coalesce(period, '~') || '|' || service_date::text from public.invoices
            where id = (current_setting('i.a')::jsonb ->> 'invoice_id')::uuid),
  'standalone|~|' || pg_temp.today()::text, 'the invoice is standalone, with no period and its service date');
select is((select due_on::text || '|' || basis from public.invoice_maturities
            where invoice_id = (current_setting('i.a')::jsonb ->> 'invoice_id')::uuid),
  (pg_temp.today() + 30)::text || '|document_term', 'its due date is its maturity');
select is((select total_cents from public.invoices where id = (current_setting('i.a')::jsonb ->> 'invoice_id')::uuid),
  14400, 'the total is the server''s');
select is(pg_temp.as_user(1, format($$select (public.issue_standalone_invoice_v1(%L, %L, 1, '00000000-0000-4000-8000-000000004165'))->>'replayed'$$,
  pg_temp.u(101), current_setting('d.a'))), 'true', 'the same request replays');
select is(pg_temp.numbers(), '1|2', 'and makes no second invoice nor number');
select ok(pg_temp.as_user(1, format($$select public.issue_standalone_invoice_v1(%L, %L, 2, '00000000-0000-4000-8000-000000004165')::text$$,
  pg_temp.u(101), current_setting('d.a'))) like 'ERR %request conflict%', 'another payload under the same request is refused');
select ok(pg_temp.as_user(1, format($$select public.issue_standalone_invoice_v1(%L, %L, 1, '00000000-0000-4000-8000-000000004166')::text$$,
  pg_temp.u(101), current_setting('d.a'))) like 'ERR DKI01%', 'another request for the issued draft is refused');
select is(pg_temp.numbers(), '1|2', 'without consuming a number');

-- ── a second deliberate invoice, the same customer and month ──
select set_config('d.b', (pg_temp.save(jsonb_build_array(pg_temp.line('2', '60', 'gross')))) ->> 'draft_id', false);
select is((public.issue_standalone_invoice_v1(pg_temp.u(101), current_setting('d.b')::uuid, 1,
  '00000000-0000-4000-8000-000000004167'::uuid) ->> 'replayed'), 'false', 'a second draft issues its own invoice');
select is((select count(*)::int from public.invoices where workspace_id = pg_temp.u(101) and member_id = pg_temp.u(203)), 2,
  'two standalone invoices of one customer and month coexist');
select is((select (vat_totals -> 0 ->> 'net_cents') || '/' || (vat_totals -> 0 ->> 'vat_cents') from public.invoices
            where id = (select issued_invoice_id from public.standalone_invoice_drafts where id = current_setting('d.b')::uuid)),
  '10000/2000', 'a price entered gross: 2 x 60.00 incl. 20 % is 100.00 net and 20.00 tax');

-- ── refusals before a number ──
select set_config('d.c', (pg_temp.save(jsonb_build_array(pg_temp.line('1', '10', 'net', 'goods')))) ->> 'draft_id', false);
select is(public.preview_standalone_invoice_v1(pg_temp.u(101), current_setting('d.c')::uuid, 1) -> 'missing',
  '["line_1_goods_off"]'::jsonb, 'goods with the goods ledger off are refused, never read as a service (#4433)');
select set_config('d.e', (pg_temp.save(jsonb_build_array(pg_temp.line('0.0000001', '10')))) ->> 'draft_id', false);
select is(public.preview_standalone_invoice_v1(pg_temp.u(101), current_setting('d.e')::uuid, 1) -> 'missing',
  '["line_1_quantity"]'::jsonb, 'a quantity with a seventh decimal is refused, not rounded');
select is(public.preview_standalone_invoice_v1(pg_temp.u(101), current_setting('d.e')::uuid, 7) -> 'missing',
  '["draft_stale"]'::jsonb, 'a preview of another revision is stale');
select is(pg_temp.as_user(3, format($$select public.preview_standalone_invoice_v1(%L, %L, 1)::text$$,
  pg_temp.u(101), current_setting('d.e'))) like 'ERR%', true, 'a member who may not issue cannot preview');
select is(pg_temp.as_user(4, format($$select public.preview_standalone_invoice_v1(%L, %L, 1)::text$$,
  pg_temp.u(102), current_setting('d.e'))) like '%draft_unknown%', true, 'another business cannot name this draft');
select is(has_table_privilege('authenticated', 'public.standalone_invoice_drafts', 'insert')
       or has_table_privilege('authenticated', 'public.standalone_invoice_drafts', 'update'), false,
  'no client writes a draft directly');

-- ── the monthly invoice of the same customer and month is untouched ──
select is(pg_temp.as_user(1, format($$select (public.create_invoice(%L, %L, to_char(pg_temp.today(), 'YYYY-MM'), null, false, 'full', true))::text is not null$$,
  pg_temp.u(101), pg_temp.u(203))), 'true', 'the monthly invoice of the same month is still issued beside the standalone ones');
select is((select string_agg(source, ',' order by source) from public.invoices
            where workspace_id = pg_temp.u(101) and member_id = pg_temp.u(203)),
  'monthly,standalone,standalone', 'two standalone and one monthly invoice of one customer and month');

-- ── the facts the draft itself lacks ──
select is(pg_temp.as_user(1, format($$select (public.preview_standalone_invoice_v1(%L,
    (public.save_standalone_invoice_draft_v1(%L, null, null, %L, pg_temp.today(), pg_temp.today() - 1, '', '', '[]'::jsonb) ->> 'draft_id')::uuid, 1) -> 'missing')::text$$,
  pg_temp.u(101), pg_temp.u(101), pg_temp.u(203))), '["due_on_before_issue", "lines"]',
  'a draft with no lines and a due date in the past names both');

-- ── the business's own day (#4309): a zone whose date differs from the database's ──
-- Kiritimati (UTC+14) is on the next day from 10:00 UTC, Pago Pago (UTC-11) on the previous one
-- before 11:00 UTC: at every instant one of them has a date other than the database's.
select set_config('t.zone', (select z from (values ('Pacific/Kiritimati'), ('Pacific/Pago_Pago')) v(z)
                              where (now() at time zone z)::date <> (now() at time zone 'UTC')::date limit 1), false);
update public.workspaces set timezone = current_setting('t.zone') where id = pg_temp.u(101);
select isnt(pg_temp.today(), (now() at time zone 'UTC')::date, 'the business''s day is not the database''s (UTC) day: ' || current_setting('t.zone'));
select is(pg_temp.as_user(1, format($$select (public.preview_standalone_invoice_v1(%L,
    (public.save_standalone_invoice_draft_v1(%L, null, null, %L, pg_temp.today(), pg_temp.today() - 1, '', '', '[]'::jsonb) ->> 'draft_id')::uuid, 1) -> 'missing')::text$$,
  pg_temp.u(101), pg_temp.u(101), pg_temp.u(203))), '["due_on_before_issue", "lines"]',
  'the business''s yesterday is a due date in the past');
select is(pg_temp.as_user(1, format($$select (public.preview_standalone_invoice_v1(%L,
    (public.save_standalone_invoice_draft_v1(%L, null, null, %L, pg_temp.today(), pg_temp.today(), '', '', '[]'::jsonb) ->> 'draft_id')::uuid, 1) -> 'missing')::text$$,
  pg_temp.u(101), pg_temp.u(101), pg_temp.u(203))), '["lines"]',
  'the business''s today is not');
update public.workspaces set timezone = 'Europe/Paris' where id = pg_temp.u(101);

-- ── the existing paths that must not take a standalone invoice ──
select ok(pg_temp.as_user(1, format($$select public.create_invoice(%L, %L, '2026-10', %L)::text$$,
  pg_temp.u(101), pg_temp.u(203), current_setting('i.a')::jsonb ->> 'invoice_id')) like 'ERR DKI01%',
  'a standalone invoice is not replaced by a monthly one');
select is((select voided_at is null from public.invoices where id = (current_setting('i.a')::jsonb ->> 'invoice_id')::uuid),
  true, 'and it was not voided');
select ok(pg_temp.as_user(3, format($$select public.record_payment(%L, %L, 14400, 'x', '', null, null, array[%L]::uuid[])::text$$,
  pg_temp.u(101), pg_temp.u(203), current_setting('i.a')::jsonb ->> 'invoice_id')) like 'ERR DKC14%',
  'a payment declaration naming a standalone invoice is refused up front');
select ok(pg_temp.as_user(3, format($$select public.record_payment(%L, %L, 14400, 'x', '', null, null, array[%L, %L]::uuid[])::text$$,
  pg_temp.u(101), pg_temp.u(203), current_setting('i.a')::jsonb ->> 'invoice_id',
  (select id::text from public.invoices where member_id = pg_temp.u(203) and source = 'monthly'))) like 'ERR DKC14%',
  'nor one that mixes it with a monthly invoice');
select ok(pg_temp.as_user(1, format($$select public.issue_standalone_invoice_v1(%L, %L, null, '00000000-0000-4000-8000-000000004168')::text$$,
  pg_temp.u(101), current_setting('d.e'))) like 'ERR DKI01%', 'an issue without a revision is stale, never unguarded');
select is(public.preview_standalone_invoice_v1(pg_temp.u(101), current_setting('d.e')::uuid, null) -> 'missing',
  '["draft_stale"]'::jsonb, 'and so is a preview without one');

-- ── the currency's own minor unit ──
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags,
                               vat_regime, vat_id, legal_id, street, city, postal_code, address)
select pg_temp.u(n), 'Cur ' || c, 'FR', c, 'Europe/Paris', pg_temp.u(1), '{"invoicing": true, "standaloneInvoicing": true}',
       'vat_registered', 'FR40303265045', '30326504500014', '4 avenue de Castelnau', 'Pézenas', '34120', '4 avenue de Castelnau, 34120 Pézenas'
  from (values (103, 'JPY'), (104, 'KWD')) v(n, c);
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(213), pg_temp.u(103), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(214), pg_temp.u(104), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(223), pg_temp.u(103), pg_temp.u(3), false, false, 'active', '2026-01-01'),
       (pg_temp.u(224), pg_temp.u(104), pg_temp.u(3), false, false, 'active', '2026-01-01');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, active, valid_from)
select pg_temp.u(n), pg_temp.u(m), 'Normal', 20, 'S', true, true, '2000-01-01' from (values (303, 103), (304, 104)) v(n, m)
on conflict do nothing;
create function pg_temp.preview_in(p_ws int, p_subject int, p_line jsonb) returns jsonb language plpgsql as $f$
declare v jsonb; d uuid;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(1), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  d := (public.save_standalone_invoice_draft_v1(pg_temp.u(p_ws), null, null, pg_temp.u(p_subject),
        pg_temp.today(), pg_temp.today() + 30, '', '', jsonb_build_array(p_line)) ->> 'draft_id')::uuid;
  v := public.preview_standalone_invoice_v1(pg_temp.u(p_ws), d, 1);
  execute 'reset role';
  return v;
end $f$;
grant execute on all functions in schema pg_temp to authenticated, anon;
select is(pg_temp.preview_in(103, 223, pg_temp.line('1.5', '1200')) #>> '{preview,lines,0,commercial,amounts}',
  '{"rule": "half_up_per_line", "currency": "JPY", "net_minor": "1800", "tax_minor": "360", "gross_minor": "2160"}',
  'a zero-decimal currency: 1.5 x 1200 JPY is 1800 net, no minor unit');
select is(pg_temp.preview_in(104, 224, pg_temp.line('1', '12.345')) #>> '{preview,lines,0,commercial,amounts,gross_minor}',
  '14814', 'a three-decimal currency: 12.345 KWD net at 20 % is 14.814 gross');

select * from finish();
rollback;
