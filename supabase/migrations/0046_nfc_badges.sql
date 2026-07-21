-- SPDX-License-Identifier: 0BSD
-- RFID/NFC badge credentials (kiosk slice 3). NOT YET applied to the
-- hosted reference project — the orchestrator applies it after review.
--
-- A member's physical RFID/NFC card becomes a badge: its stable tag UID
-- (normalized to lowercase hex, no separators) is the credential. The
-- server stores only the SHA-256 hash, exactly like QR badge tokens, and
-- kiosk_act needs NO change — the badge lookup is by hash regardless of
-- how the credential was presented (QR scan, wedge scanner, NFC tap).
--
-- Registration is admin-side ("tap the card once"): unlike QR badges the
-- credential comes from the physical tag, so the client sends the UID and
-- the server hashes it. A UID can be registered once across the
-- workspace (the unique token_hash); re-registering answers a dedicated
-- error the app maps.

-- 1. badge kind, for the manager UI and auditing
alter table public.member_badges
  add column kind text not null default 'qr' check (kind in ('qr','nfc'));

-- 2. register a physical tag as a member's badge
create or replace function public.register_nfc_badge(
  p_workspace_id uuid, p_member_id uuid, p_uid text, p_label text default ''
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_uid text;
  v_id uuid;
begin
  if not public.is_admin_of(p_workspace_id) then
    raise exception 'not an admin of this workspace';
  end if;
  if not exists (select 1 from public.members
                  where id = p_member_id and workspace_id = p_workspace_id
                    and status = 'active' and not is_kiosk) then
    raise exception 'unknown member';
  end if;
  -- Normalization contract (client mirrors it): lowercase hex, no
  -- separators. 4–10 tag-UID bytes → 8–20 hex chars.
  v_uid := lower(regexp_replace(coalesce(p_uid, ''), '[^0-9a-fA-F]', '', 'g'));
  if v_uid !~ '^[0-9a-f]{8,20}$' then
    raise exception 'invalid tag uid';
  end if;
  begin
    insert into public.member_badges
      (workspace_id, member_id, token_hash, label, kind)
    values (p_workspace_id, p_member_id, public.badge_token_hash(v_uid),
            coalesce(p_label, ''), 'nfc')
    returning id into v_id;
  exception when unique_violation then
    -- the client pins this substring
    raise exception 'tag already registered';
  end;
  return v_id;
end;
$$;
revoke execute on function public.register_nfc_badge(uuid, uuid, text, text) from public, anon;
