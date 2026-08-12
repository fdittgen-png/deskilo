-- SPDX-License-Identifier: 0BSD
-- #552: the WhatsApp channel becomes configurable FROM THE APP — the
-- 0106 mirror needed WHATSAPP_TOKEN + WHATSAPP_PHONE_ID as project env
-- secrets, an operator-only step no owner could perform (the #300
-- payment-credentials lesson, again). Per-workspace credentials live in
-- a deny-all table only the service-role edge function and the
-- owner-only RPC below ever touch; the send-whatsapp function reads the
-- workspace's channel first and falls back to the env secrets.

create table public.workspace_channels (
  workspace_id uuid primary key
    references public.workspaces(id) on delete cascade,
  -- {token, phone_id} — the WhatsApp Business Cloud API credentials.
  whatsapp jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- RLS with ZERO policies = deny-all to every client role: secrets are
-- write-only from the app's perspective.
alter table public.workspace_channels enable row level security;

-- Owner-only: MERGE the channel config. Non-blank fields overwrite;
-- blank/absent fields keep the existing value — the owner can fix the
-- phone id without re-typing a token they can never read back.
create or replace function public.set_whatsapp_channel(
  p_workspace_id uuid, p_config jsonb
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_clean jsonb;
begin
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'not the owner of this workspace';
  end if;
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) into v_clean
    from jsonb_each(coalesce(p_config, '{}'::jsonb))
    where key in ('token', 'phone_id')
      and value is not null and trim(both '"' from value::text) <> '';
  if v_clean = '{}'::jsonb then return; end if;

  insert into public.workspace_channels (workspace_id, whatsapp, updated_at)
  values (p_workspace_id, v_clean, now())
  on conflict (workspace_id)
    do update set whatsapp = public.workspace_channels.whatsapp || v_clean,
                  updated_at = now();
end;
$$;
revoke execute on function public.set_whatsapp_channel(uuid, jsonb)
  from public, anon;

-- Owner-only: remove the channel entirely (messages fall back to
-- in-app + push, or to the env secrets if the operator set them).
create or replace function public.clear_whatsapp_channel(
  p_workspace_id uuid
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'not the owner of this workspace';
  end if;
  delete from public.workspace_channels
    where workspace_id = p_workspace_id;
end;
$$;
revoke execute on function public.clear_whatsapp_channel(uuid)
  from public, anon;
