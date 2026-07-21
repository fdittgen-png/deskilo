-- SPDX-License-Identifier: 0BSD
-- UnifiedPush endpoints + pending-event push fan-out (issue #72, v1.1).
-- Applied to the hosted reference project on 2026-07-08.
--
-- Privacy: the pushed payload is a generic {"kind":"pending_request"}
-- ping — no names, amounts or times ever transit the push distributor.

create extension if not exists pg_net with schema extensions;

create table public.push_endpoints (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.members(id) on delete cascade,
  endpoint text not null check (endpoint ~ '^https://'),
  created_at timestamptz not null default now(),
  unique (member_id, endpoint)
);
create index push_endpoints_member_idx on public.push_endpoints (member_id);

alter table public.push_endpoints enable row level security;

-- Members manage only their own device endpoints.
create policy push_endpoints_own on public.push_endpoints
  for all using (
    exists (
      select 1 from public.members m
      where m.id = push_endpoints.member_id and m.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.members m
      where m.id = push_endpoints.member_id and m.user_id = auth.uid()
    )
  );

-- Push a generic ping to everyone who must decide a pending event,
-- mirroring the respond_to_event decider rule (#107):
--   expenses / self-recorded payments → the other active admins;
--   everything else → the subject (when someone else acted).
create or replace function public.notify_pending_event()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_endpoint record;
begin
  if new.status <> 'pending' then return new; end if;
  if tg_op = 'UPDATE' and old.status = 'pending' then return new; end if;

  for v_endpoint in
    select pe.endpoint
    from public.push_endpoints pe
    join public.members m on m.id = pe.member_id
    where m.workspace_id = new.workspace_id
      and m.status = 'active'
      and m.id <> new.actor_member_id
      and (
        case
          when new.type = 'expense'
               or (new.type = 'payment'
                   and new.actor_member_id = new.subject_member_id)
            then (m.is_admin or m.is_owner)
          else m.id = new.subject_member_id
        end
      )
  loop
    begin
      perform net.http_post(
        url := v_endpoint.endpoint,
        body := jsonb_build_object(
          'kind', 'pending_request',
          'workspace_id', new.workspace_id
        ),
        timeout_milliseconds := 5000
      );
    exception when others then
      -- Push is best-effort: a dead endpoint must never fail the event.
      null;
    end;
  end loop;
  return new;
end;
$$;

create trigger events_notify_pending
after insert or update of status on public.events
for each row execute function public.notify_pending_event();

revoke execute on function public.notify_pending_event()
  from public, anon, authenticated;
