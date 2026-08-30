-- SPDX-License-Identifier: 0BSD
--
-- #737 — the WhatsApp INTEGRATION goes: the 0106 message mirror (a
-- trigger calling the send-whatsapp function through the WhatsApp
-- Business Cloud API) and the 0110 per-workspace credentials. What
-- stays is what a member sets on their own profile: a WhatsApp number
-- (#223), and the group link (#231) — the app opens WhatsApp with them,
-- nothing leaves the server. Credentials are dropped with the table.

drop trigger if exists member_notes_whatsapp on public.member_notes;
drop function if exists public.notify_member_note_whatsapp();
drop function if exists public.set_whatsapp_channel(uuid, jsonb);
drop function if exists public.clear_whatsapp_channel(uuid);
drop table if exists public.workspace_channels;
drop table if exists public.whatsapp_messages;
alter table public.profiles drop column if exists whatsapp_notes;
