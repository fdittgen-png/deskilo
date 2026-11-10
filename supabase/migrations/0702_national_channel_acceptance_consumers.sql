-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (two trigger functions, two triggers; no table, no policy)
--
-- #3159 -- 0701's acceptance is recorded where a channel's accepted answer is
-- already persisted, so the gate lifts on the channel's own answer and never
-- on a hand-typed row:
--
--  * invoice_transmissions -- a row of a national channel's connector
--    (`it_sdi` SdI, `pl_ksef` KSeF, `ro_efactura` e-Factura) that becomes
--    `accepted` records the acceptance of that channel's country. The
--    environment is the transmission's own: `prod` is a production
--    acceptance, `uat` and `dev` a sandbox one -- a sandbox acceptance opens
--    the gate, as #3159 asks; the row says which it was.
--  * verifactu_records -- a record the AEAT `accepted` (Verifactu) records
--    Spain's; a production workspace's is a production acceptance, any other
--    a sandbox one. `accepted_with_errors` and `rejected` record nothing.
--
-- A rejected, failed or pending answer records nothing, and a connector of a
-- country without a national channel is ignored: the triggers never refuse
-- the write that fires them.

create or replace function public.national_channel_from_transmission()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_cc text := case new.provider
    when 'it_sdi' then 'IT' when 'pl_ksef' then 'PL' when 'ro_efactura' then 'RO' end;
begin
  if v_cc is not null
     and coalesce((public.issuing_gate_of(v_cc) ->> 'national_channel_required')::boolean, false) then
    perform public.record_national_channel_acceptance_v1(
      new.workspace_id, v_cc, new.provider,
      case when new.environment = 'prod' then 'production' else 'sandbox' end,
      jsonb_build_object('transmission_id', new.id, 'external_id', new.external_id,
                         'receipt', coalesce(new.receipt, '{}'::jsonb)),
      least(coalesce(new.receipt_at, now()), now()));
  end if;
  return new;
end;
$fn$;
revoke execute on function public.national_channel_from_transmission() from public, anon, authenticated;

drop trigger if exists national_channel_from_transmission on public.invoice_transmissions;
create trigger national_channel_from_transmission
  after insert or update of status on public.invoice_transmissions
  for each row when (new.status = 'accepted')
  execute function public.national_channel_from_transmission();

create or replace function public.national_channel_from_verifactu()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if coalesce((public.issuing_gate_of('ES') ->> 'national_channel_required')::boolean, false) then
    perform public.record_national_channel_acceptance_v1(
      new.workspace_id, 'ES', 'es_verifactu',
      case when (select w.environment from public.workspaces w where w.id = new.workspace_id) = 'prod'
           then 'production' else 'sandbox' end,
      jsonb_build_object('verifactu_record_id', new.id, 'huella', new.huella,
                         'detail', new.submission_detail),
      now());
  end if;
  return new;
end;
$fn$;
revoke execute on function public.national_channel_from_verifactu() from public, anon, authenticated;

drop trigger if exists national_channel_from_verifactu on public.verifactu_records;
create trigger national_channel_from_verifactu
  after update of submission_status on public.verifactu_records
  for each row when (new.submission_status = 'accepted' and old.submission_status <> 'accepted')
  execute function public.national_channel_from_verifactu();

select public.set_deskilo_schema_version(702);
