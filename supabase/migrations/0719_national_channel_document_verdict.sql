-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (the acceptance consumer fires through the real writer and only on a
--  positive document verdict; a sandbox acceptance holds only for the issuer
--  and channel configuration it was recorded with)
--
-- #3746 -- two defects of 0702, split out of #3534:
--
--  1. Its trigger was `UPDATE OF status`. The real writers
--     (record_einvoice_outcome_v1 and record_einvoice_lookup_v1, 0689) set
--     `phase` and `verdict`; a BEFORE trigger derives `status`, and a column
--     trigger follows only the statement's own SET list, so the consumer
--     never fired through them. It now reacts to what the writers change:
--     an AFTER INSERT, and an AFTER UPDATE whose old row did not qualify and
--     whose new row does.
--  2. It qualified a channel on `status = accepted`: the projection of the
--     transport phase. A document the authority rejected after an accepted
--     upload opened the gate. One predicate now says what qualifies:
--     einvoice_document_accepted(phase, verdict) -- the upload accepted AND
--     the provider's own document verdict accepted (`verdict.status`, read
--     by the status query; a person's manual resolution is not the
--     provider's verdict). Transport and verdict stay two facts.
--
-- Every acceptance records national_channel_binding (the recorder stamps
-- it): a digest of the
-- channel, the issuer's identity (VAT and legal id) and the channel's
-- configuration (provider, settings, last change as an epoch, so the digest
-- does not depend on the session's time zone or date style). The gate counts a
-- sandbox acceptance only while that binding is still the current one, so a
-- replaced issuer or configuration does not inherit a test it never passed.
-- A production acceptance is the channel's own answer to real documents and
-- stays as it is.

create or replace function public.einvoice_document_accepted(p_phase text, p_verdict jsonb)
returns boolean language sql immutable set search_path = public as $fn$
  select coalesce(p_phase = 'accepted', false)
     and coalesce(p_verdict ->> 'status', '') = 'accepted'
     and coalesce(p_verdict ->> 'document', '') <> 'rejected'
$fn$;
revoke execute on function public.einvoice_document_accepted(text, jsonb) from public, anon, authenticated;

create or replace function public.national_channel_binding(p_workspace_id uuid, p_channel text)
returns text language sql stable security definer set search_path = public as $fn$
  select encode(sha256(convert_to(concat_ws('|',
           p_channel, w.vat_id, w.legal_id,
           case when p_channel = 'es_verifactu' then ''
                else concat_ws('|', c.provider, c.config::text,
                               extract(epoch from c.updated_at)::text) end),
         'utf8')), 'hex')
    from public.workspaces w
    left join public.einvoice_credentials c on c.workspace_id = w.id
   where w.id = p_workspace_id
$fn$;
revoke execute on function public.national_channel_binding(uuid, text) from public, anon, authenticated;

create or replace function public.national_channel_accepted(p_workspace_id uuid, p_country text)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (select 1 from public.national_channel_acceptances a
                  where a.workspace_id = p_workspace_id
                    and a.country_code = upper(btrim(coalesce(p_country, '')))
                    and (a.environment = 'production'
                         or a.receipt ->> 'binding'
                            = public.national_channel_binding(p_workspace_id, a.channel)))
$fn$;
revoke execute on function public.national_channel_accepted(uuid, text) from public, anon, authenticated;

-- The recorder stamps the binding itself, so every path that records an
-- acceptance (the consumers below, the operator's service-role call) binds
-- it to what was tested. Restated from 0701 with that one change.
create or replace function public.record_national_channel_acceptance_v1(
  p_workspace_id uuid, p_country text, p_channel text, p_environment text,
  p_receipt jsonb, p_accepted_at timestamptz
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_cc text := upper(btrim(coalesce(p_country, '')));
  v_id uuid;
begin
  if not exists (select 1 from public.workspaces w where w.id = p_workspace_id) then
    raise exception 'unknown workspace';
  end if;
  if not coalesce((public.issuing_gate_of(v_cc) ->> 'national_channel_required')::boolean, false) then
    raise exception 'no national channel is required for %', v_cc;
  end if;
  if p_accepted_at is null or p_accepted_at > now() + interval '5 minutes' then
    raise exception 'the acceptance needs its time, not in the future';
  end if;
  insert into public.national_channel_acceptances
    (workspace_id, country_code, channel, environment, receipt, accepted_at)
  values (p_workspace_id, v_cc, p_channel, p_environment,
          case when p_receipt is null or p_receipt = '{}'::jsonb then p_receipt
               else p_receipt || jsonb_build_object('binding',
                      public.national_channel_binding(p_workspace_id, p_channel)) end,
          p_accepted_at)
  on conflict (workspace_id, country_code, channel, environment) do update
    set receipt = excluded.receipt, accepted_at = excluded.accepted_at
    where public.national_channel_acceptances.accepted_at < excluded.accepted_at
  returning id into v_id;
  return jsonb_build_object('recorded', v_id is not null,
                            'gate_open', public.national_channel_accepted(p_workspace_id, v_cc));
end;
$fn$;
revoke execute on function public.record_national_channel_acceptance_v1(uuid, text, text, text, jsonb, timestamptz)
  from public, anon, authenticated;
grant execute on function public.record_national_channel_acceptance_v1(uuid, text, text, text, jsonb, timestamptz)
  to service_role;

-- A sandbox verdict can arrive days after the send. Credentials saved after
-- the transmission was prepared are not what the authority answered, so
-- such a verdict records nothing: the binding is taken when the verdict is
-- recorded, and it must still describe the configuration that sent.
create or replace function public.national_channel_from_transmission()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_cc text := case new.provider
    when 'it_sdi' then 'IT' when 'pl_ksef' then 'PL' when 'ro_efactura' then 'RO' end;
begin
  if new.environment <> 'prod' and exists (
       select 1 from public.einvoice_credentials c
        where c.workspace_id = new.workspace_id and c.updated_at > new.created_datetime) then
    return new;
  end if;
  if v_cc is not null
     and coalesce((public.issuing_gate_of(v_cc) ->> 'national_channel_required')::boolean, false) then
    perform public.record_national_channel_acceptance_v1(
      new.workspace_id, v_cc, new.provider,
      case when new.environment = 'prod' then 'production' else 'sandbox' end,
      jsonb_build_object('transmission_id', new.id, 'external_id', new.external_id,
                         'receipt', coalesce(new.receipt, '{}'::jsonb),
                         'verdict', new.verdict),
      least(coalesce(new.receipt_at, now()), now()));
  end if;
  return new;
end;
$fn$;
revoke execute on function public.national_channel_from_transmission() from public, anon, authenticated;

drop trigger if exists national_channel_from_transmission on public.invoice_transmissions;
drop trigger if exists national_channel_from_transmission_insert on public.invoice_transmissions;
create trigger national_channel_from_transmission_insert
  after insert on public.invoice_transmissions
  for each row when (public.einvoice_document_accepted(new.phase, new.verdict))
  execute function public.national_channel_from_transmission();
drop trigger if exists national_channel_from_transmission_update on public.invoice_transmissions;
create trigger national_channel_from_transmission_update
  after update on public.invoice_transmissions
  for each row when (public.einvoice_document_accepted(new.phase, new.verdict)
                     and not public.einvoice_document_accepted(old.phase, old.verdict))
  execute function public.national_channel_from_transmission();

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(719);
