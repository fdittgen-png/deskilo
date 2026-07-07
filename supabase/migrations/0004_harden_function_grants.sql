-- SPDX-License-Identifier: MIT
-- DesKilo hardening (issue #31, driven by Supabase security advisors).
-- Applied to the hosted reference project on 2026-07-07.
--
-- Principle: trigger functions are not callable at all; helper predicates and
-- RPCs are callable by authenticated only (they are the intended API surface);
-- nothing SECURITY DEFINER is callable by anon.

alter extension btree_gist set schema extensions;

-- trigger-only functions: no direct execution by any API role
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.protect_last_owner() from public, anon, authenticated;
-- server-side default helper: not an API
revoke execute on function public.gen_invite_code() from public, anon, authenticated;

-- RLS helper predicates: authenticated only (policies evaluate as the caller)
revoke execute on function public.is_member_of(uuid) from public, anon;
revoke execute on function public.is_admin_of(uuid) from public, anon;
revoke execute on function public.is_owner_of(uuid) from public, anon;
revoke execute on function public.shares_workspace_with(uuid) from public, anon;

-- RPCs: authenticated only (they raise on missing auth.uid() anyway)
revoke execute on function public.create_workspace(text, text, text, text) from public, anon;
revoke execute on function public.join_workspace(text) from public, anon;
revoke execute on function public.leave_workspace(uuid) from public, anon;
