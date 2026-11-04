-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2380 (0677) — the QR reference is frozen at issue and collision-free.
--
-- `F-2026-0402` and `U-2026-04-02` share the reference the client derives
-- from a number's digits. Inserted after 0677, each is given its own QRR in
-- `legal_snapshot.qrr`: 27 digits, a valid recursive modulus-10 check digit,
-- apart from every derived reference (leading 1), never chosen by the caller,
-- never changed afterwards. A credit note gets none; an invoice issued
-- before the trigger existed keeps none and is matched by its derived one.
begin;
select plan(9);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-0000000003a1';
  ws uuid; m uuid;
  a uuid; b uuid; chosen uuid; credit uuid; legacy uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'qrr@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('QRR', 'CH', 'CHF', 'Europe/Zurich', u) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u, true, true) returning id into m;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature)
  values (ws, m, m, 'F-2026-0402', 'April', '[]'::jsonb, 5000, 'CHF', 'Member',
          'QRR', 'Member', 'sig') returning id into a;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature)
  values (ws, m, m, 'U-2026-04-02', 'April', '[]'::jsonb, 2400, 'CHF', 'Member',
          'QRR', 'Member', 'sig') returning id into b;
  -- A caller naming its own reference.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature, legal_snapshot)
  values (ws, m, m, 'F-2026-0403', 'April', '[]'::jsonb, 1000, 'CHF', 'Member',
          'QRR', 'Member', 'sig',
          '{"qrr": "000000000000000000000000000"}'::jsonb) returning id into chosen;
  -- A credit note asks for no payment.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature, legal_snapshot)
  values (ws, m, m, 'AV-2026-0001', 'April', '[]'::jsonb, -1000, 'CHF', 'Member',
          'QRR', 'Member', 'sig',
          '{"qrr": "100000000000000000000000017"}'::jsonb) returning id into credit;
  -- An invoice issued before 0677: the trigger did not exist yet.
  alter table public.invoices disable trigger invoice_qrr_freeze;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature)
  values (ws, m, m, 'F-2025-0001', 'Old', '[]'::jsonb, 3000, 'CHF', 'Member',
          'QRR', 'Member', 'sig') returning id into legacy;
  alter table public.invoices enable trigger invoice_qrr_freeze;
  perform set_config('deskilo.test.a', a::text, false);
  perform set_config('deskilo.test.b', b::text, false);
  perform set_config('deskilo.test.chosen', chosen::text, false);
  perform set_config('deskilo.test.credit', credit::text, false);
  perform set_config('deskilo.test.legacy', legacy::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.qrr(p text) returns text language sql as $$
  select legal_snapshot ->> 'qrr' from public.invoices
   where id = current_setting('deskilo.test.' || p)::uuid
$$;

-- What the client derives from a number: its digits, zero-padded, checked.
create or replace function pg_temp.derived(p_number text) returns text language sql as $$
  select lpad(regexp_replace(p_number, '\D', '', 'g'), 26, '0')
      || public.qrr_check_digit(lpad(regexp_replace(p_number, '\D', '', 'g'), 26, '0'))::text
$$;

select is(pg_temp.derived('F-2026-0402'), pg_temp.derived('U-2026-04-02'),
  'the two numbers share one derived reference: the collision this fixes');

select ok(pg_temp.qrr('a') ~ '^1[0-9]{26}$' and pg_temp.qrr('b') ~ '^1[0-9]{26}$',
  'each invoice that asks for money is given a 27-digit frozen QRR');

select isnt(pg_temp.qrr('a'), pg_temp.qrr('b'),
  'the two invoices get two different frozen references');

select ok(
  public.qrr_check_digit(substr(pg_temp.qrr('a'), 1, 26)) = substr(pg_temp.qrr('a'), 27)::int
  and public.qrr_check_digit(substr(pg_temp.qrr('b'), 1, 26)) = substr(pg_temp.qrr('b'), 27)::int,
  'the 27th digit is the recursive modulus-10 check digit');

-- The guidelines' example reference 21 00000 00003 13947 14300 09017.
select is(public.qrr_check_digit('21000000000313947143000901'), 7,
  'the check digit of the guidelines'' example');

select ok(pg_temp.qrr('a') <> pg_temp.derived('F-2026-0402')
      and pg_temp.qrr('a') <> pg_temp.derived('U-2026-04-02'),
  'a frozen reference is never one a number derives');

select ok(pg_temp.qrr('chosen') <> '000000000000000000000000000'
      and pg_temp.qrr('chosen') ~ '^1[0-9]{26}$'
      and pg_temp.qrr('credit') is null,
  'the caller never chooses the reference, and a credit note gets none');

select throws_ok(
  format($$update public.invoices
             set legal_snapshot = legal_snapshot || '{"qrr": "100000000000000000000000017"}'
           where id = %L$$, current_setting('deskilo.test.a')),
  'invoices are immutable',
  'an issued invoice''s reference never changes');

select ok(pg_temp.qrr('legacy') is null,
  'an invoice issued before 0677 keeps no frozen reference (matched by its derived one)');

select * from finish();
rollback;
