-- SPDX-License-Identifier: 0BSD
-- DesKilo owner-defined workspace ID (#88). Applied 2026-07-08. The
-- invite_code doubles as the human-readable workspace ID shown in the QR;
-- owners may replace the generated one with a memorable alphanumeric ID.
create or replace function public.set_workspace_code(
  p_workspace_id uuid,
  p_code text
) returns text language plpgsql security definer set search_path = public as $$
declare v_code text;
begin
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'only owners may change the workspace ID';
  end if;
  v_code := upper(trim(p_code));
  if v_code !~ '^[A-Z0-9]{4,20}$' then
    raise exception 'workspace ID must be 4-20 letters or digits';
  end if;
  begin
    update public.workspaces set invite_code = v_code where id = p_workspace_id;
  exception when unique_violation then
    raise exception 'workspace ID already taken';
  end;
  return v_code;
end;
$$;
revoke execute on function public.set_workspace_code(uuid, text) from public, anon;
