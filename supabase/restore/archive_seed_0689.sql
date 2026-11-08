-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3338 row 8 -- what the archive of `archive_seed.sql` holds once the schema
-- stands at migration 0689 (the first with a durable `prepared` attempt), and
-- the e-invoice work a real instance has in flight at that moment:
--
--   * a PREPARED transmission of ARC-1: the record and the exact bytes that
--     may leave (`invoice_transmission_artifacts`), not yet claimed, never
--     resent by anything but the claim that owns it;
--   * an ACCEPTED transmission of ARC-2 with its upload receipt.
--
-- Applied by `scripts/populated_upgrade_check.sh` in the second case
-- (STAGE_AT=0689), AFTER the 0226 archive has been carried to 0689 and BEFORE
-- migrations 0690..latest run over it. They cross 0694 (the transmission
-- envelope), 0696 and 0697 (the jurisdiction removal facts), which all touch
-- `invoice_transmissions`. Every column here exists at 0689 (0071, 0074, 0112,
-- 0414, 0689). Fixed ids and fixed instants: the snapshot is keyed by them.
begin;

do $seed$
declare
  ws        uuid := '00000000-0000-4000-8000-0000000a0002';
  u_owner   uuid := '00000000-0000-4000-8000-0000000a0001';
  inv_a     uuid := '00000000-0000-4000-8000-0000000a0101';
  inv_b     uuid := '00000000-0000-4000-8000-0000000a0102';
  tx_prep   uuid := '00000000-0000-4000-8000-0000000a0401';
  tx_acc    uuid := '00000000-0000-4000-8000-0000000a0402';
  v_at      timestamptz := '2026-01-15 10:00:00+00';
begin
  insert into public.invoice_transmissions
    (id, workspace_id, invoice_id, provider, status, phase, external_id,
     document_hash, detail, sent_at, by_name, environment, destination, format,
     business_key, binding_hash, requested_by, receipt, receipt_at)
  values
    (tx_prep, ws, inv_a, 'peppol', 'failed', 'prepared', '',
     repeat('a', 64), '', v_at, 'Owner', 'prod', 'government', 'peppolBis',
     ws::text || '|' || inv_a::text || '|peppol|government|prod',
     repeat('f', 64), u_owner, '{}'::jsonb, null),
    (tx_acc, ws, inv_b, 'peppol', 'accepted', 'accepted', 'EXT-ARC-2',
     repeat('c', 64), 'Accepted by the platform', v_at + interval '1 hour',
     'Owner', 'prod', 'government', 'peppolBis',
     ws::text || '|' || inv_b::text || '|peppol|government|prod',
     repeat('d', 64), u_owner,
     '{"platform_id": "EXT-ARC-2", "received": "2026-01-15T11:00:00Z"}'::jsonb,
     v_at + interval '1 hour');

  insert into public.invoice_transmission_artifacts
    (transmission_id, workspace_id, bytes, sha256, file_name, mime_type,
     receiver_scheme, receiver_id)
  values
    (tx_prep, ws, '\x41524331', repeat('e', 64), 'ARC-1.xml', 'application/xml',
     '0088', '1234567890123');
end
$seed$;

commit;
