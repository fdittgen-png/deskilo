-- SPDX-License-Identifier: 0BSD
-- FCM-only push (#426/#428, ADR 0011 — the F-Droid-era UnifiedPush leg
-- is fully removed). Three pieces:
--
--  * push_endpoints holds `fcm:<token>` rows only (the table was empty
--    in production, so the tightened check rewrites history for nobody).
--  * push_config (single row): where the send-push edge function lives.
--    Seeded with the committed publishable pair (ADR 0002 — the same
--    values every client binary ships); self-hosters update the row.
--  * notify_pending_event v3: computes the notifiable kind and pings
--    the send-push function with {event_id} ONLY — the function loads
--    the event itself, derives recipients (0082 rules), signs FCM v1
--    with the FCM_SERVICE_ACCOUNT secret and sets the APNs badge. The
--    direct pg_net POSTs to UnifiedPush endpoints are gone with the
--    transport.

alter table public.push_endpoints
  drop constraint if exists push_endpoints_endpoint_check;
alter table public.push_endpoints
  add constraint push_endpoints_endpoint_check
  check (endpoint ~ '^fcm:');

create table if not exists public.push_config (
  id boolean primary key default true check (id),
  functions_url text not null,
  anon_key text not null
);
alter table public.push_config enable row level security;
-- Deny-all: only the definer function below reads it.

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
  v_kind text;
  v_cfg public.push_config;
begin
  if new.status = 'pending'
     and (tg_op = 'INSERT' or old.status <> 'pending') then
    v_kind := 'pending_request';
  elsif new.type = 'reservation' and new.action = 'cancelled'
     and new.actor_member_id <> new.subject_member_id
     and (tg_op = 'INSERT'
          or old.actor_member_id = old.subject_member_id) then
    v_kind := 'reservation_cancelled';
  end if;

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
        null;  -- best-effort: push must never fail the event
      end;
    end if;
  end if;
  return new;
end;
$$;
