-- DesKilo #155 — per-workspace payment instructions (spec §7: "Optional
-- per-workspace payment instructions (IBAN, reference format) are shown
-- on unpaid statements"). One jsonb blob like feature_flags: the owner
-- writes it wholesale under the existing workspaces_update RLS; members
-- read it through the existing select policy. Keys the app writes:
-- iban, paypal_me, reference (all optional strings).
alter table public.workspaces
  add column if not exists payment_instructions jsonb not null
    default '{}'::jsonb;
