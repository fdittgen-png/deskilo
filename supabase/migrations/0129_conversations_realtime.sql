-- SPDX-License-Identifier: 0BSD
-- 0129 — the messaging centre gets its live wire (#702).
--
-- `member_notes` has been published since 0089, but the CONVERSATION
-- tables never were: 0125 created them after the last publication
-- change and nobody went back. So a group you were just added to, a
-- group someone renamed, a member who left — none of it reached a
-- client until the list was refetched by hand.
--
-- The client half of the same fix maps these tables (and, at last,
-- `member_notes`) onto the conversation caches. Before it, an incoming
-- message invalidated only the OLD bell feed: the list, the unread
-- badge and any open thread all sat on caches nothing refreshed. A
-- messenger where messages arrive when you pull down is not a messenger.
--
-- RLS still decides who sees what: realtime replays each change through
-- the subscriber's own policies, and 0125 already restricts both tables
-- to participants via `in_conversation()`.

alter publication supabase_realtime add table public.conversations;
alter publication supabase_realtime add table public.conversation_participants;

-- REPLICA IDENTITY FULL, on both.
--
-- The default (primary key only) is enough for an INSERT, but a DELETE
-- and an UPDATE ship only the key — and the client filters what it
-- receives by workspace. A row that arrives without its workspace_id
-- cannot be placed, so a member leaving a group would either be
-- dropped or, worse, applied to whatever workspace happened to be open.
alter table public.conversations replica identity full;
alter table public.conversation_participants replica identity full;
