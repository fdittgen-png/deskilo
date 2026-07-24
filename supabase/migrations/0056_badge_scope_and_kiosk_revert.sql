-- SPDX-License-Identifier: 0BSD
-- Badge scope + kiosk self-revert. NOT YET applied to the hosted
-- reference project — the orchestrator applies it after review.
--
-- Field report 1: a card was READ at the kiosk but "not recognized" —
-- it was registered under the member's OTHER workspace, and the GLOBAL
-- unique(token_hash) then blocked registering the same card in the
-- kiosk's workspace at all. Badges are per-membership, so uniqueness
-- belongs per workspace: the same physical card may serve one member
-- across several workspaces.
alter table public.member_badges
  drop constraint member_badges_token_hash_key;
alter table public.member_badges
  add constraint member_badges_workspace_token_key
    unique (workspace_id, token_hash);

-- Field report 2: a profile flagged as kiosk had no way back from the
-- device itself. The signed-in kiosk account may revert ITSELF: anyone
-- at the pad can already neutralize the kiosk by signing out, so a
-- self-revert adds convenience, not exposure — and flagging a member AS
-- a kiosk stays owner-only (set_member_kiosk, 0043).
create or replace function public.unset_my_kiosk(p_workspace_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_count int;
begin
  update public.members
     set is_kiosk = false
   where workspace_id = p_workspace_id
     and user_id = auth.uid()
     and is_kiosk;
  get diagnostics v_count = row_count;
  if v_count = 0 then raise exception 'not a kiosk of this workspace'; end if;
end;
$$;
revoke execute on function public.unset_my_kiosk(uuid) from public, anon;
