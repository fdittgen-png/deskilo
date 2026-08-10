-- SPDX-License-Identifier: 0BSD
-- Messages on WhatsApp (field request): a member who shared a WhatsApp
-- number can OPT IN to receive their DesKilo messages there too — the
-- text as the in-app messenger reads it (reference tokens as labels),
-- each reference as a web link, and a link that opens the app directly
-- on the conversation.
--
-- Delivery: an insert trigger pings the send-whatsapp edge function
-- with {note_id} (the 0089 send-push pattern — best-effort, never
-- fails the note; the function loads the note itself with the service
-- role and checks each recipient's opt-in). The function needs the
-- WHATSAPP_TOKEN + WHATSAPP_PHONE_ID secrets (WhatsApp Business Cloud
-- API) and no-ops politely without them.

alter table public.profiles
  add column whatsapp_notes boolean not null default false;

create or replace function public.notify_member_note_whatsapp()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_cfg public.push_config;
begin
  select * into v_cfg from public.push_config where id;
  if v_cfg.functions_url is not null then
    begin
      perform net.http_post(
        url := v_cfg.functions_url || '/send-whatsapp',
        headers := jsonb_build_object(
          'Authorization', 'Bearer ' || v_cfg.anon_key,
          'Content-Type', 'application/json'
        ),
        body := jsonb_build_object('note_id', new.id),
        timeout_milliseconds := 5000
      );
    exception when others then
      null;  -- best-effort: WhatsApp must never fail the note
    end;
  end if;
  return new;
end;
$$;

create trigger member_notes_whatsapp
  after insert on public.member_notes
  for each row execute function public.notify_member_note_whatsapp();
