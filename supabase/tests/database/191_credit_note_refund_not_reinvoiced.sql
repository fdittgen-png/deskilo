-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2570 — a credit note refunded by bank transfer is settled by its match
-- row and is NOT charged back on the member's next invoice. INV-2 is
-- issued, CN-1 credits it, settle_credit_invoice(CN-1) refunds it: the
-- ledger row is a `refund`, invoice_lines_for for the month carries no
-- adjustment line, the VAT return of the month holds the credit note's
-- own VAT and nothing from the refund, and the money
-- returned is still on the member's ledger.
begin;
select plan(7);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  uo uuid := '00000000-0000-4000-8000-000000257001';
  um uuid := '00000000-0000-4000-8000-000000257002';
  ws uuid; mo uuid; mm uuid; cn uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner@refund2570.test','',now(),now(),now()),
          (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','member@refund2570.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,vat_regime)
   values ('Refund 2570','FR','EUR','Europe/Paris',uo,'vat_registered') returning id into ws;
  insert into public.members(workspace_id,user_id,is_owner,is_admin) values (ws,uo,true,true) returning id into mo;
  insert into public.members(workspace_id,user_id) values (ws,um) returning id into mm;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, issued_at, vat_totals, legal_snapshot)
  values (ws, mm, mo, 'INV-2', 'Desk', '[{"label": "Desk", "amount_cents": 12000, "vat_percent": 20}]',
          12000, 'EUR', 'M', 'Refund 2570', 'O', 's', 'full', now() - interval '3 days',
          '[{"percent": 20, "category": "S"}]', '{"seller_country": "FR"}');
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, issued_at, vat_totals, legal_snapshot)
  values (ws, mm, mo, 'CN-1', 'Credit', '[{"label": "Refund", "amount_cents": -2400, "vat_percent": 20}]',
          -2400, 'EUR', 'M', 'Refund 2570', 'O', 's', 'full', now() - interval '2 days',
          '[{"percent": 20, "category": "S"}]', '{"seller_country": "FR"}')
  returning id into cn;
  perform set_config('rf.ws', ws::text, false);
  perform set_config('rf.m', mm::text, false);
  perform set_config('rf.cn', cn::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', uo, 'role', 'authenticated')::text, false);
end;
$seed$;

select pg_temp.seed();

create or replace function pg_temp.vat_sum() returns bigint language sql as $$
  select coalesce(sum(vat_cents), 0)::bigint
    from public.compute_vat_return(current_setting('rf.ws')::uuid,
           (date_trunc('month', now()) - interval '1 month')::date,
           (date_trunc('month', now()) + interval '2 month')::date);
$$;
select lives_ok($$select public.settle_credit_invoice(current_setting('rf.cn')::uuid, 'bank transfer')$$,
  'the credit note is settled by a refund');

select is((select count(*)::int from public.ledger_entries
            where member_id = current_setting('rf.m')::uuid
              and category = 'refund' and kind = 'charge' and amount_cents = 2400),
  1, 'the money returned is one ledger row of the refund category');
select is((select count(*)::int from public.ledger_entries
            where member_id = current_setting('rf.m')::uuid and category = 'adjustment'),
  0, 'and no adjustment is booked');
select is((select paid_cents from public.invoice_matches
            where invoice_id = current_setting('rf.cn')::uuid and resolution = 'refunded'),
  2400, 'the match row carries the refund as the settlement of the credit note');
select is((select count(*)::int
             from jsonb_array_elements(public.invoice_lines_for(
                    current_setting('rf.m')::uuid, to_char(now(), 'YYYY-MM'))) l
            where l->>'kind' = 'adjustment' or l->>'label' like 'Refund%'),
  0, 'the next invoice carries no positive adjustment line for the refund');
select is(pg_temp.vat_sum(), -400::bigint,
  'the VAT return declares the credit note once (20 % of 24.00), the refund adds nothing');
select is((select count(*)::int from public.ledger_entries
            where member_id = current_setting('rf.m')::uuid and description like 'Refund CN-1%'),
  1, 'the member statement still has the refund on the ledger');

select * from finish();
rollback;
