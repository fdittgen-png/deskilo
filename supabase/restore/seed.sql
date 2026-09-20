-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1310 S1 — the fixture the restore drill dumps, restores and counts.
--
-- Every pgTAP file in this repository rolls back, so there was nothing
-- on disk to dump: a backup procedure documented in OPERATIONS.md that
-- nobody had ever run. This seed is the one thing that persists, and it
-- is deliberately small and deliberately REAL: two workspaces (so the
-- copy can be checked for tenancy, not only for row counts), a floor
-- plan in each, bookings across two months, and an invoice with the
-- credit ledger row and the match that settle it — the three legs
-- `reconcile_workspace` compares.
--
-- Shapes follow 22_reconciliation.sql and 23_domain_invariants.sql,
-- which already prove they satisfy the constraints and reconcile clean.
--
-- It lives in `supabase/restore/` and NOT in `supabase/tests/`: the
-- latter is swept by `supabase test db`, which would run this file as
-- a pgTAP test. It has no plan, so that run fails — and because this
-- one commits, it would also leave its rows behind and the drill's own
-- apply would then collide on them. It did exactly that once.
begin;

do $seed$
declare
  u_a uuid := '00000000-0000-4000-8000-00000000d001';
  u_b uuid := '00000000-0000-4000-8000-00000000d002';
  ws_a uuid; ws_b uuid; m_a uuid; m_b uuid;
  lvl uuid; office uuid; desk uuid; seat_a uuid; seat_b uuid;
  inv uuid; credit uuid;
begin
  -- The profile comes from the trigger on auth.users; never insert it.
  insert into auth.users (id, instance_id, aud, role, email,
                          encrypted_password, email_confirmed_at,
                          created_at, updated_at)
  values (u_a, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'restore-a@deskilo.test', '', now(), now(), now()),
         (u_b, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'restore-b@deskilo.test', '', now(), now(), now());

  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Restore A', 'FR', 'EUR', 'Europe/Paris', u_a) returning id into ws_a;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Restore B', 'DE', 'EUR', 'Europe/Berlin', u_b) returning id into ws_b;

  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws_a, u_a, true, true) returning id into m_a;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws_b, u_b, true, true) returning id into m_b;

  -- A seat is the bookable unit, and it only exists at the end of a
  -- chain: level → office → desk → seat. One in each workspace.
  insert into public.levels (workspace_id, name) values (ws_a, 'Ground')
  returning id into lvl;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
  values (ws_a, lvl, 'Open space', 0, 0, 10, 10) returning id into office;
  insert into public.desks (workspace_id, office_id, x, y, w, h)
  values (ws_a, office, 1, 1, 4, 2) returning id into desk;
  insert into public.seats (workspace_id, desk_id, x, y)
  values (ws_a, desk, 1, 1) returning id into seat_a;

  insert into public.levels (workspace_id, name) values (ws_b, 'Erdgeschoss')
  returning id into lvl;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
  values (ws_b, lvl, 'Großraum', 0, 0, 10, 10) returning id into office;
  insert into public.desks (workspace_id, office_id, x, y, w, h)
  values (ws_b, office, 1, 1, 4, 2) returning id into desk;
  insert into public.seats (workspace_id, desk_id, x, y)
  values (ws_b, desk, 1, 1) returning id into seat_b;

  -- Bookings across two months, in both workspaces: a restore that lost
  -- a month or a workspace has to show up as a count.
  insert into public.reservations (workspace_id, seat_id, member_id, starts_at, ends_at)
  values (ws_a, seat_a, m_a,
          date_trunc('month', now()) + interval '3 days 9 hours',
          date_trunc('month', now()) + interval '3 days 17 hours'),
         (ws_a, seat_a, m_a,
          date_trunc('month', now()) - interval '25 days',
          date_trunc('month', now()) - interval '25 days' + interval '4 hours'),
         (ws_b, seat_b, m_b,
          date_trunc('month', now()) + interval '4 days 9 hours',
          date_trunc('month', now()) + interval '4 days 17 hours');

  -- One invoice, settled: invoice ↔ ledger ↔ match, the three legs.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature)
  values (ws_a, m_a, m_a, 'RST-1', 'Restore month', '[]'::jsonb, 5000, 'EUR',
          'Member A', 'Restore A', 'Member A', 'sig') returning id into inv;
  insert into public.ledger_entries (workspace_id, member_id, kind, category,
                                     amount_cents, description, period)
  values (ws_a, m_a, 'credit', 'payment', 5000, 'bank transfer',
          to_char(now(), 'YYYY-MM')) returning id into credit;
  insert into public.invoice_matches (workspace_id, invoice_id, paid_cents,
                                      resolution, credit_ledger_id)
  values (ws_a, inv, 5000, 'exact', credit);
end
$seed$;

commit;
