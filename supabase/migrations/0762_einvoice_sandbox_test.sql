-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (invoice_transmissions.invoice_id becomes optional for one new kind of row;
--  every existing row is an invoice's and stays as it is)
--
-- 0762 (#3883) -- a workspace whose country routes every invoice through a
-- national channel opens its issuing gate with a sandbox test document. The
-- gate (0701, 0719) opens on the channel's own verdict on a document, and no
-- invoice can be issued before it: the test document is the first one.
--
-- A test document is a transmission of kind `test`:
--  * it belongs to no invoice: it takes no number from the invoice sequence
--    and creates no invoice, ledger entry, posting or customer;
--  * it goes to the sandbox only (environment `uat`), to the government
--    destination;
--  * members never read it from the table: the select policy reads the
--    invoice it belongs to (0144), and it belongs to none. Lists, exports and
--    counts of a workspace's transmissions therefore leave it out;
--  * one at a time: while a test awaits its verdict, another is refused; a
--    rejected or failed test can be sent again.
-- Its accepted verdict records a sandbox acceptance through the trigger of
-- 0719, bound to the issuer and the configuration that sent it: changing the
-- credentials or the seller's identity closes the gate again.

alter table public.invoice_transmissions
  add column if not exists kind text not null default 'invoice';
alter table public.invoice_transmissions
  drop constraint if exists invoice_transmissions_kind_check;
alter table public.invoice_transmissions
  add constraint invoice_transmissions_kind_check
  check (kind in ('invoice', 'test'));
alter table public.invoice_transmissions
  alter column invoice_id drop not null;
alter table public.invoice_transmissions
  drop constraint if exists invoice_transmissions_kind_invoice_check;
alter table public.invoice_transmissions
  add constraint invoice_transmissions_kind_invoice_check
  check ((kind = 'invoice') = (invoice_id is not null)
         and (kind = 'invoice' or (environment = 'uat' and destination = 'government')));
comment on column public.invoice_transmissions.kind is
  '#3883 -- invoice (an invoice''s transmission) | test (a sandbox test document of the national channel, no invoice)';

-- Whether a test transmission still awaits the channel's verdict: not yet
-- uploaded, uploaded with no document verdict, or unsettled.
create or replace function public.einvoice_test_pending(p_phase text, p_verdict jsonb)
returns boolean language sql immutable set search_path = public as $fn$
  select p_phase in ('prepared', 'sent', 'uncertain')
      or (p_phase = 'accepted'
          and coalesce(p_verdict ->> 'status', '') not in ('accepted', 'rejected')
          and coalesce(p_verdict ->> 'document', '') <> 'rejected')
$fn$;
revoke execute on function public.einvoice_test_pending(text, jsonb) from public, anon, authenticated;

-- The preparation of a test document: the record and its artifact, written
-- before anything leaves (as prepare_einvoice_v1, 0694). The Edge Function
-- calls it after checking who asks and the sandbox credentials.
create or replace function public.prepare_einvoice_test_v1(
  p_workspace_id uuid, p_provider text, p_actor uuid, p_by_name text,
  p_format text, p_hash text, p_file_name text, p_mime_type text,
  p_bytes bytea, p_declared jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path = public
as $fn$
declare
  v_id uuid := gen_random_uuid();
  v_key text := concat_ws('|', p_workspace_id, 'test', v_id);
  v_pending public.invoice_transmissions;
begin
  if not exists (select 1 from public.workspaces where id = p_workspace_id) then
    raise exception 'unknown workspace' using errcode = '22023';
  end if;
  if coalesce(p_hash, '') = '' or p_bytes is null or octet_length(p_bytes) = 0 then
    raise exception 'a test document needs its bytes' using errcode = '22023';
  end if;
  -- one at a time: a workspace's tests queue on the workspace
  perform pg_advisory_xact_lock(hashtextextended(p_workspace_id::text, 3883));
  select * into v_pending from public.invoice_transmissions
   where workspace_id = p_workspace_id and kind = 'test'
     and public.einvoice_test_pending(phase, verdict)
   order by sent_at desc limit 1;
  if found then
    return jsonb_build_object('outcome', 'test_pending', 'id', v_pending.id,
      'phase', v_pending.phase);
  end if;
  insert into public.invoice_transmissions (id, workspace_id, invoice_id, kind,
    provider, status, phase, document_hash, by_name, environment,
    destination, format, business_key, binding_hash, requested_by)
  values (v_id, p_workspace_id, null, 'test', p_provider, 'failed', 'prepared',
    p_hash, coalesce(p_by_name, ''), 'uat', 'government', p_format, v_key,
    encode(sha256(convert_to(concat_ws('|', p_hash, p_format), 'utf8')), 'hex'),
    p_actor);
  insert into public.invoice_transmission_artifacts (transmission_id,
    workspace_id, bytes, sha256, file_name, mime_type, receiver_scheme,
    receiver_id)
  values (v_id, p_workspace_id, p_bytes, p_hash, coalesce(p_file_name, ''),
    coalesce(p_mime_type, 'application/xml'), '', '');
  perform public.record_provenance(p_workspace_id, 'transmission', v_id,
    jsonb_build_object('actor_user_id', p_actor, 'provider', p_provider,
                       'destination', 'government', 'environment', 'uat',
                       'business_key', v_key, 'kind', 'test'),
    p_declared,
    jsonb_build_object('sha256', p_hash, 'format', p_format,
                       'bytes', octet_length(p_bytes)));
  return jsonb_build_object('outcome', 'prepared', 'id', v_id, 'phase', 'prepared');
end;
$fn$;
revoke execute on function public.prepare_einvoice_test_v1(uuid, text, uuid, text, text, text, text, text, bytea, jsonb)
  from public, anon, authenticated;
grant execute on function public.prepare_einvoice_test_v1(uuid, text, uuid, text, text, text, text, text, bytea, jsonb)
  to service_role;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(762);
