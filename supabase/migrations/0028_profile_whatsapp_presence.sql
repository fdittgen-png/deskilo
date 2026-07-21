-- SPDX-License-Identifier: 0BSD
-- DesKilo member-directory groundwork (epic #222, issue #223). NOT YET
-- applied to the hosted reference project — the orchestrator applies it
-- after review.
--
-- profiles gains two columns:
--  * whatsapp — opt-in WhatsApp number. '' means "not shared" (mirrors
--    display_name's not-null-empty convention from 0001). The client
--    normalizes input to '+' + digits; the check re-validates that wire
--    shape ('+', then 6–19 digits — 20 chars max) so a raw write can
--    never smuggle in free text.
--  * last_seen_at — foreground-heartbeat timestamp; null until the
--    member's first heartbeat. "Online" is a pure client-side derivation
--    (last_seen_at younger than 5 minutes, see PresenceRules).
--
-- RLS: deliberately NO new policies. 0002's profiles_select already
-- exposes whole profile rows to self + shares_workspace_with(id), so
-- both new columns ride along for exactly the audience issue #223 wants
-- (members sharing a workspace, the #224 directory readers). Writes:
-- profiles_update stays self-only, which covers the whatsapp edit; the
-- heartbeat goes through the dedicated RPC below so it stays a
-- single-column, auth.uid()-scoped write with no broader update grant.

alter table public.profiles
  add column whatsapp text not null default ''
    check (whatsapp = '' or whatsapp ~ '^\+[0-9]{6,19}$'),
  add column last_seen_at timestamptz;

-- Foreground heartbeat (#223): stamps only the caller's own row.
-- SECURITY DEFINER on purpose — the row it touches is derived from
-- auth.uid() inside the body, so it cannot be pointed at anyone else.
create or replace function public.touch_last_seen()
returns void
language sql
security definer
set search_path = public
as $$
  update public.profiles set last_seen_at = now() where id = auth.uid();
$$;

-- Grant discipline mirrors 0004: RPCs are callable by authenticated only.
revoke execute on function public.touch_last_seen() from public, anon;
grant execute on function public.touch_last_seen() to authenticated;
