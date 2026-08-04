-- SPDX-License-Identifier: 0BSD
-- Member-to-member notifications (#456): any active member can send a
-- short note to another member; admins (and the owner) can broadcast to
-- ALL admins including the owner. Delivery: the trigger pings the
-- send-push edge function (v2 understands {note_id}) — the push itself
-- stays content-free (0012 privacy doctrine, 'You have a new message');
-- the app reads the note over RLS and renders the localized
-- notification with sender and text on-device. Realtime (0080 pattern)
-- pushes the row to foregrounded apps.

create table public.member_notes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id)
    on delete cascade,
  from_member_id uuid not null references public.members(id)
    on delete cascade,
  -- null = broadcast to all admins incl. the owner (sender must be an
  -- admin/owner — send_member_note enforces it).
  to_member_id uuid references public.members(id) on delete cascade,
  body text not null check (length(btrim(body)) between 1 and 500),
  created_at timestamptz not null default now()
);

create index member_notes_recipient
  on public.member_notes (to_member_id, created_at desc);
create index member_notes_workspace
  on public.member_notes (workspace_id, created_at desc);

alter table public.member_notes enable row level security;

-- Read: the recipient, the sender, and — for broadcasts — every
-- admin/owner of the workspace.
create policy member_notes_select on public.member_notes
  for select using (
    exists (
      select 1 from public.members m
      where m.user_id = auth.uid()
        and m.workspace_id = member_notes.workspace_id
        and m.status = 'active'
        and (
          m.id = member_notes.to_member_id
          or m.id = member_notes.from_member_id
          or (member_notes.to_member_id is null
              and (m.is_admin or m.is_owner))
        )
    )
  );
-- Writes go through send_member_note only (no insert/update/delete
-- policies): the RPC validates sender, target and broadcast rights.

create or replace function public.send_member_note(
  p_workspace_id uuid,
  p_to_member_id uuid,
  p_body text
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_sender public.members;
  v_target public.members;
  v_note_id uuid;
begin
  select * into v_sender from public.members
    where workspace_id = p_workspace_id
      and user_id = auth.uid() and status = 'active';
  if v_sender.id is null then
    raise exception 'not an active member of this workspace';
  end if;
  if length(btrim(coalesce(p_body, ''))) not between 1 and 500 then
    raise exception 'the message must be 1-500 characters';
  end if;

  if p_to_member_id is null then
    -- Broadcast to all admins incl. the owner: an admin surface.
    if not (v_sender.is_admin or v_sender.is_owner) then
      raise exception 'only admins may notify all admins';
    end if;
  else
    select * into v_target from public.members
      where id = p_to_member_id and workspace_id = p_workspace_id
        and status = 'active';
    if v_target.id is null then
      raise exception 'unknown recipient';
    end if;
    if v_target.id = v_sender.id then
      raise exception 'you cannot notify yourself';
    end if;
  end if;

  insert into public.member_notes
      (workspace_id, from_member_id, to_member_id, body)
    values (p_workspace_id, v_sender.id, p_to_member_id, btrim(p_body))
    returning id into v_note_id;
  return v_note_id;
end;
$$;
revoke execute on function public.send_member_note(uuid, uuid, text)
  from public, anon;

-- Push fanout: same best-effort ping as notify_pending_event (0084),
-- with {note_id} — send-push v2 loads the note itself and never trusts
-- the caller.
create or replace function public.notify_member_note()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_cfg public.push_config;
begin
  select * into v_cfg from public.push_config where id;
  if v_cfg.functions_url is not null then
    begin
      perform net.http_post(
        url := v_cfg.functions_url || '/send-push',
        headers := jsonb_build_object(
          'Authorization', 'Bearer ' || v_cfg.anon_key,
          'Content-Type', 'application/json'
        ),
        body := jsonb_build_object('note_id', new.id),
        timeout_milliseconds := 5000
      );
    exception when others then
      null;  -- best-effort: push must never fail the note
    end;
  end if;
  return new;
end;
$$;

create trigger member_notes_push
  after insert on public.member_notes
  for each row execute function public.notify_member_note();

-- Foregrounded apps learn about new notes live (0080 pattern; RLS
-- scopes what each client actually receives).
alter publication supabase_realtime add table public.member_notes;
