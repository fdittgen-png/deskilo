-- SPDX-License-Identifier: 0BSD
--
-- #1338 — the populated baseline the upgrade check carries forward.
--
-- Applied by `scripts/populated_upgrade_check.sh` onto a database that
-- stands at migration 0226 (the first schema that writes its own
-- version marker), BEFORE the remaining migrations run over it. It is
-- the archive a real instance has when an upgrade arrives:
--
--   * ARC-1 — an issued invoice signed the modern way (`signature_algo`
--     7, the hash `verify_invoice_signature` recomputes), settled by a
--     payment credit and the match between them;
--   * ARC-2 — a legacy invoice: a signature nothing can recompute and no
--     algorithm stamp, the honest `unverifiable` INVARIANTS.md describes;
--   * ARC-3 — an issued invoice the check voids after the upgrade, to
--     show the permitted transitions still work and nothing else does;
--   * three captured payment intents for the 0240 backfill: one with
--     exactly one matching credit (associated), two sharing one credit
--     (ambiguous, left alone, reported by the reconciliation).
--
-- Every column here exists at 0226, and the signature is computed with
-- the 0174 formula from the same literals the row is built from, so the
-- seed proves itself `verified` before a single later migration runs.
-- Fixed ids: the snapshot the check diffs is keyed by them.
begin;

do $seed$
declare
  u_owner  uuid := '00000000-0000-4000-8000-0000000a0001';
  ws       uuid := '00000000-0000-4000-8000-0000000a0002';
  m        uuid := '00000000-0000-4000-8000-0000000a0003';
  inv_modern uuid := '00000000-0000-4000-8000-0000000a0101';
  inv_legacy uuid := '00000000-0000-4000-8000-0000000a0102';
  inv_open   uuid := '00000000-0000-4000-8000-0000000a0103';
  credit_5000 uuid := '00000000-0000-4000-8000-0000000a0201';
  credit_2500 uuid := '00000000-0000-4000-8000-0000000a0202';
  -- One full invoice per member and period: three periods.
  v_period text := to_char(now(), 'YYYY-MM');
  v_prev text := to_char(now() - interval '1 month', 'YYYY-MM');
  v_older text := to_char(now() - interval '2 months', 'YYYY-MM');
  v_issued timestamptz := date_trunc('day', now()) + interval '9 hours';
  v_lines jsonb := '[{"label": "Desk, one month", "cents": 5000}]'::jsonb;
  v_open_lines jsonb := '[{"label": "Meeting room", "cents": 1000}]'::jsonb;
  v_details jsonb := '{"site": "Archive street"}'::jsonb;
  v_parties jsonb := '{"issuer": {"name": "Archive"}, "customer": {"name": "Member A"}}'::jsonb;
  v_vat jsonb := '{"rate": 20, "net_cents": 4167, "vat_cents": 833}'::jsonb;
  v_open_vat jsonb := '{"rate": 20, "net_cents": 833, "vat_cents": 167}'::jsonb;
begin
  -- The profile comes from the trigger on auth.users; never insert it.
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'archive-owner@deskilo.test', '', now(), now(), now());

  insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by)
  values (ws, 'Archive', 'FR', 'EUR', 'Europe/Paris', u_owner);
  insert into public.members (id, workspace_id, user_id, is_owner, is_admin)
  values (m, ws, u_owner, true, true);

  insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number,
                               issued_at, period, title, lines, total_cents, currency,
                               member_name, member_address, workspace_name,
                               workspace_address, issuer_name, details, parties,
                               vat_totals, kind, signature, signature_algo)
  values
    -- the 0174 formula over the same literals, in the verifier's order
    (inv_modern, ws, m, m, 'ARC-1', v_issued, v_period, 'Archive month', v_lines,
     5000, 'EUR', 'Member A', '1 rue des Archives', 'Archive', '2 rue des Archives',
     'Archive', v_details, v_parties, v_vat, 'full',
     encode(extensions.digest(convert_to(concat_ws('|',
       inv_modern::text, 'ARC-1', ws::text, m::text, 'Member A', '1 rue des Archives',
       'Archive', '2 rue des Archives', 'Archive', v_period, v_lines::text, '5000',
       'EUR', v_issued::date::text, '', '', v_details::text, v_parties::text,
       v_vat::text, 'full'), 'UTF8'), 'sha256'), 'hex'), 7),
    (inv_legacy, ws, m, m, 'ARC-2', v_issued - interval '40 days', v_older,
     'Before the stamp', v_lines, 5000, 'EUR', 'Member A', '1 rue des Archives',
     'Archive', '2 rue des Archives', 'Archive', v_details, v_parties, v_vat, 'full',
     'a-hash-over-fields-a-later-backfill-rewrote', null),
    (inv_open, ws, m, m, 'ARC-3', v_issued, v_prev, 'Meeting room', v_open_lines,
     1000, 'EUR', 'Member A', '1 rue des Archives', 'Archive', '2 rue des Archives',
     'Archive', v_details, v_parties, v_open_vat, 'full',
     encode(extensions.digest(convert_to(concat_ws('|',
       inv_open::text, 'ARC-3', ws::text, m::text, 'Member A', '1 rue des Archives',
       'Archive', '2 rue des Archives', 'Archive', v_prev, v_open_lines::text, '1000',
       'EUR', v_issued::date::text, '', '', v_details::text, v_parties::text,
       v_open_vat::text, 'full'), 'UTF8'), 'sha256'), 'hex'), 7);

  -- The postings: one credit settles ARC-1 through a match; one credit
  -- of 25 € is what two captured intents will both claim.
  insert into public.ledger_entries (id, workspace_id, member_id, kind, category,
                                     amount_cents, description, period)
  values (credit_5000, ws, m, 'credit', 'payment', 5000, 'online payment', v_period),
         (credit_2500, ws, m, 'credit', 'payment', 2500, 'online payment', v_period);
  insert into public.invoice_matches (workspace_id, invoice_id, paid_cents,
                                      resolution, credit_ledger_id)
  values (ws, inv_modern, 5000, 'exact', credit_5000);

  insert into public.payment_intents (id, workspace_id, member_id, provider, order_id,
                                      capture_id, period, amount_cents, currency, status)
  values ('00000000-0000-4000-8000-0000000a0301', ws, m, 'paypal', 'ORDER-1', 'CAP-1',
          v_period, 5000, 'EUR', 'captured'),
         ('00000000-0000-4000-8000-0000000a0302', ws, m, 'paypal', 'ORDER-2', 'CAP-2',
          v_period, 2500, 'EUR', 'captured'),
         ('00000000-0000-4000-8000-0000000a0303', ws, m, 'paypal', 'ORDER-3', 'CAP-3',
          v_period, 2500, 'EUR', 'captured');
end
$seed$;

commit;
