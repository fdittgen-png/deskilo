-- SPDX-License-Identifier: 0BSD
-- FCM transport (#426, F-Droid dropped by owner decision). Three pieces:
--
--  * push_endpoints accepts `fcm:<token>` rows next to the UnifiedPush
--    https:// URLs.
--  * push_config (single row): where the send-push edge function lives.
--    Seeded with the committed publishable pair (ADR 0002 — the same
--    values every client binary ships); self-hosters update the row.
--  * notify_pending_event v3: UnifiedPush endpoints keep their direct
--    pg_net POST; additionally ONE ping with {event_id} goes to the
--    send-push function, which loads the event itself and fans out to
--    the fcm: rows (FCM v1 needs OAuth signing pg_net cannot do; the
--    function trusts no caller input beyond the id).

alter table public.push_endpoints
  drop constraint if exists push_endpoints_endpoint_check;
alter table public.push_endpoints
  add constraint push_endpoints_endpoint_check
  check (endpoint ~ '^https://' or endpoint ~ '^fcm:');

create table if not exists public.push_config (
  id boolean primary key default true check (id),
  functions_url text not null,
  anon_key text not null
);
alter table public.push_config enable row level security;
-- Deny-all: only the definer functions below read it.

insert into public.push_config (id, functions_url, anon_key)
values (
  true,
  'https://zwzbynivewivvjmripeb.supabase.co/functions/v1',
  'sb_publishable_PqXoa0tyQTjsZCPD_LrEQw_P7LJtalL'
)
on conflict (id) do nothing;

create or replace function public.notify_pending_event()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_endpoint record;
  v_kind text;
  v_cfg public.push_config;
begin
  if new.status = 'pending'
     and (tg_op = 'INSERT' or old.status <> 'pending') then
    v_kind := 'pending_request';
    for v_endpoint in
      select pe.endpoint
      from public.push_endpoints pe
      join public.members m on m.id = pe.member_id
      where m.workspace_id = new.workspace_id
        and m.status = 'active'
        and m.id <> new.actor_member_id
        and pe.endpoint ~ '^https://'
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
            'kind', v_kind,
            'workspace_id', new.workspace_id
          ),
          timeout_milliseconds := 5000
        );
      exception when others then
        null;  -- best-effort: a dead endpoint never fails the event
      end;
    end loop;
  elsif new.type = 'reservation' and new.action = 'cancelled'
     and new.actor_member_id <> new.subject_member_id
     and (tg_op = 'INSERT'
          or old.actor_member_id = old.subject_member_id) then
    v_kind := 'reservation_cancelled';
    for v_endpoint in
      select pe.endpoint
      from public.push_endpoints pe
      join public.members m on m.id = pe.member_id
      where m.workspace_id = new.workspace_id
        and m.status = 'active'
        and m.id <> new.actor_member_id
        and pe.endpoint ~ '^https://'
        and (m.id = new.subject_member_id or m.is_admin or m.is_owner)
    loop
      begin
        perform net.http_post(
          url := v_endpoint.endpoint,
          body := jsonb_build_object(
            'kind', v_kind,
            'workspace_id', new.workspace_id
          ),
          timeout_milliseconds := 5000
        );
      exception when others then
        null;
      end;
    end loop;
  end if;

  -- FCM leg (#426): one ping per notifiable event; the function computes
  -- recipients and content itself. No-ops when unconfigured.
  if v_kind is not null then
    select * into v_cfg from public.push_config where id;
    if v_cfg.functions_url is not null then
      begin
        perform net.http_post(
          url := v_cfg.functions_url || '/send-push',
          headers := jsonb_build_object(
            'Authorization', 'Bearer ' || v_cfg.anon_key,
            'Content-Type', 'application/json'
          ),
          body := jsonb_build_object('event_id', new.id),
          timeout_milliseconds := 5000
        );
      exception when others then
        null;
      end;
    end if;
  end if;
  return new;
end;
$$;
