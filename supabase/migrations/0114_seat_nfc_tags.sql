-- SPDX-License-Identifier: 0BSD
-- Seat NFC/RFID tags (#585): a chair carries a physical tag; tapping it
-- resolves to the seat exactly like scanning its printed QR card.
--
-- The uid is an IDENTIFIER, not a credential — the printed space QR
-- already exposes the seat id in plain text — so unlike member badges
-- (0046, hashed) it is stored plainly. Same normalization contract as
-- badge uids: lowercase hex, no separators, 4–10 tag-UID bytes.
--
-- One tag maps to at most one seat per workspace; the app maps the
-- unique violation to "tag already linked to another chair".

alter table public.seats add column nfc_uid text
  check (nfc_uid is null or nfc_uid ~ '^[0-9a-f]{8,20}$');

create unique index seats_nfc_uid_unique
  on public.seats (workspace_id, nfc_uid)
  where nfc_uid is not null;
