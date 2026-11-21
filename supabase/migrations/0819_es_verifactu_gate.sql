-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- #3932 -- the Spanish connector's sandbox test opens the Spanish issuing gate
-- as the other channels' do: an `es_verifactu` transmission whose upload the
-- AEAT accepted and whose document verdict is accepted records the national
-- channel's acceptance (environment sandbox when it was a test), bound to the
-- issuer's identity as 0719 binds Spain's acceptance. Restated from 0719 with
-- that one provider added; the Verifactu live chain (verifactu_records and its
-- own acceptance consumer, 0702) is not touched.

create or replace function public.national_channel_from_transmission()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_cc text := case new.provider
    when 'it_sdi' then 'IT' when 'pl_ksef' then 'PL' when 'ro_efactura' then 'RO'
    when 'es_verifactu' then 'ES' end;
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

select public.set_deskilo_schema_version(819);
