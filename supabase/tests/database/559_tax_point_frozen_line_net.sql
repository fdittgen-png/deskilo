-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #4162 (X1.B, 0943) -- the VAT return reads the net the server froze on a commercial line.
-- `invoice_line_net_cents` gives a version 1 commercial line its frozen `net_minor` and every other
-- line the legacy split of its gross; `vat_return_amounts` and `compute_vat_return` sum it. The
-- fixture: 120.01 at 20 % whose legacy split is 100.01, frozen by a commercial line as 100.00 net +
-- 20.01 tax. The same figures are pinned on the Dart side by vat_return_parity_test.dart.
begin;
select plan(9);

do $seed$
declare
  u uuid := '00000000-0000-4000-8000-000000416201';
  ws uuid;
  m uuid;
  legal jsonb := '{"seller_country": "FR", "vat_exigibility": "invoice"}';
  frozen jsonb := '{"version": 1, "line_id": "l-1", "quantity": "1.5", "supply": "general",
                    "unit": {"code": "hour", "un_ece_code": "HUR", "label": "h"},
                    "unit_price": {"amount": "66.67", "currency": "EUR", "basis": "net", "base_quantity": "1"},
                    "amounts": {"currency": "EUR", "net_minor": "10000", "tax_minor": "2001",
                                "gross_minor": "12001", "rule": "half_up_per_line"}}';
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'frozen-net-' || u || '@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, vat_regime)
  values ('Frozen net', 'FR', 'EUR', 'Europe/Paris', u, 'vat_registered') returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u, true, true) returning id into m;

  -- C: the commercial line, issued on 10 September.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, issued_at, vat_totals, legal_snapshot)
  values (ws, m, m, 'FN-C', 'Commercial',
          jsonb_build_array(jsonb_build_object('kind', 'service', 'label', 'Consulting', 'quantity', 1,
            'amount_cents', 12001, 'vat_percent', 20, 'supply', 'general', 'commercial', frozen)),
          12001, 'EUR', 'M', 'Frozen net', 'M', 's', 'full', '2026-09-10 10:00+00',
          '[{"percent": 20, "category": "S", "gross_cents": 12001, "net_cents": 10000, "vat_cents": 2001}]', legal);
  -- L: the same gross as a legacy line, on 11 September: split as it always was.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, issued_at, vat_totals, legal_snapshot)
  values (ws, m, m, 'FN-L', 'Legacy', '[{"label": "Desk", "amount_cents": 12001, "vat_percent": 20}]',
          12001, 'EUR', 'M', 'Frozen net', 'M', 's', 'full', '2026-09-11 10:00+00',
          '[{"percent": 20, "category": "S"}]', legal);
  -- U: a version this server does not write, on 12 September: never read as version 1.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, issued_at, vat_totals, legal_snapshot)
  values (ws, m, m, 'FN-U', 'Unknown version',
          jsonb_build_array(jsonb_build_object('label', 'Future', 'amount_cents', 12001, 'vat_percent', 20,
            'commercial', frozen || '{"version": 2}')),
          12001, 'EUR', 'M', 'Frozen net', 'M', 's', 'full', '2026-09-12 10:00+00',
          '[{"percent": 20, "category": "S"}]', legal);

  perform set_config('fn.ws', ws::text, false);
  perform set_config('fn.owner', u::text, false);
  perform set_config('fn.frozen', frozen::text, false);
end
$seed$;

-- ------------------------------------------------------------- the rule
select is(
  public.invoice_line_net_cents(jsonb_build_object('amount_cents', 12001, 'vat_percent', 20,
    'commercial', current_setting('fn.frozen')::jsonb)),
  10000::bigint, 'a version 1 commercial line gives the net the server froze');
select is(
  public.invoice_line_net_cents('{"amount_cents": 12001, "vat_percent": 20}'),
  10001::bigint, 'a legacy line gives the split of its gross, as before');
select is(
  public.invoice_line_net_cents(jsonb_build_object('amount_cents', 12001, 'vat_percent', 20,
    'commercial', current_setting('fn.frozen')::jsonb || '{"version": 2}')),
  10001::bigint, 'another version is not read as version 1');
select is(
  public.invoice_line_net_cents(jsonb_build_object('amount_cents', 12001, 'vat_percent', 20,
    'commercial', jsonb_set(current_setting('fn.frozen')::jsonb, '{amounts,net_minor}', '"100.00"'))),
  10001::bigint, 'a frozen net that is not an integer in text is not read');
select is(
  public.invoice_line_net_cents('{"amount_cents": -2400, "vat_percent": 20}'),
  -2000::bigint, 'a negative legacy line keeps its signed split');

-- ------------------------------------------------------- the engine
select results_eq(
  $$ select tax_point, gross_cents, net_cents
       from public.vat_return_amounts(current_setting('fn.ws')::uuid, '2026-09-01', '2026-09-30')
      order by tax_point $$,
  $$ values ('2026-09-10'::date, 12001::bigint, 10000::bigint),
            ('2026-09-11', 12001, 10001),
            ('2026-09-12', 12001, 10001) $$,
  'the commercial invoice declares its frozen net; the legacy and the unknown ones their split');

do $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('fn.owner'), 'role', 'authenticated')::text, true);
end
$act$;
select is(
  (select net_cents from public.compute_vat_return(current_setting('fn.ws')::uuid, '2026-09-01', '2026-09-30')
    where tax_point = '2026-09-10'),
  10000::bigint, 'the return the owner prepares states the frozen net');
select is(
  (select vat_cents from public.compute_vat_return(current_setting('fn.ws')::uuid, '2026-09-01', '2026-09-30')
    where tax_point = '2026-09-10'),
  2001::bigint, 'and the frozen tax, gross less frozen net');

select is(
  has_function_privilege('anon', 'public.invoice_line_net_cents(jsonb)', 'execute'),
  false, 'the helper is not callable anonymously');

select * from finish();
rollback;
