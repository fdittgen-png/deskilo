-- SPDX-License-Identifier: 0BSD
-- Self-service badges. NOT YET applied to the hosted reference project —
-- the orchestrator applies it after review.
--
-- A member manages their OWN kiosk credentials (field request): mint the
-- printable QR badge and register their RFID/NFC card themselves, from
-- Settings — no admin needed. Bodies mirror the admin RPCs (0043/0046)
-- with the subject fixed to the caller's own active membership; the
-- admin paths stay untouched.

create or replace function public.issue_my_badge(
  p_workspace_id uuid, p_label text default ''
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_member public.members;
  v_token text;
  v_id uuid;
begin
  select * into v_member from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid()
      and status = 'active' and not is_kiosk;
  if v_member.id is null then raise exception 'not an active member'; end if;
  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  insert into public.member_badges (workspace_id, member_id, token_hash, label)
  values (p_workspace_id, v_member.id, public.badge_token_hash(v_token),
          coalesce(p_label, ''))
  returning id into v_id;
  return jsonb_build_object('badge_id', v_id, 'token', v_token);
end;
$$;
revoke execute on function public.issue_my_badge(uuid, text) from public, anon;

create or replace function public.register_my_nfc_badge(
  p_workspace_id uuid, p_uid text, p_label text default ''
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_member public.members;
  v_uid text;
  v_id uuid;
begin
  select * into v_member from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid()
      and status = 'active' and not is_kiosk;
  if v_member.id is null then raise exception 'not an active member'; end if;
  -- Normalization contract (0046): lowercase hex, no separators.
  v_uid := lower(regexp_replace(coalesce(p_uid, ''), '[^0-9a-fA-F]', '', 'g'));
  if v_uid !~ '^[0-9a-f]{8,20}$' then
    raise exception 'invalid tag uid';
  end if;
  begin
    insert into public.member_badges
      (workspace_id, member_id, token_hash, label, kind)
    values (p_workspace_id, v_member.id, public.badge_token_hash(v_uid),
            coalesce(p_label, ''), 'nfc')
    returning id into v_id;
  exception when unique_violation then
    -- the client pins this substring
    raise exception 'tag already registered';
  end;
  return v_id;
end;
$$;
revoke execute on function public.register_my_nfc_badge(uuid, text, text)
  from public, anon;

-- Revoke MY badge: only badges of the caller's own membership.
create or replace function public.revoke_my_badge(p_badge_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_count int;
begin
  update public.member_badges b
    set revoked_at = now()
    where b.id = p_badge_id and b.revoked_at is null
      and exists (select 1 from public.members m
                   where m.id = b.member_id and m.user_id = auth.uid());
  get diagnostics v_count = row_count;
  if v_count = 0 then raise exception 'unknown badge'; end if;
end;
$$;
revoke execute on function public.revoke_my_badge(uuid) from public, anon;
