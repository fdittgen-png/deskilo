-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0695 (#3336) -- the linked-document correction route of a stopped capability.
--
-- Servicing completes admitted work and refuses new work (0692); it must not
-- admit arbitrary new issuance labelled a correction. The one new delivery it
-- admits is the correction of a document this very connection delivered and the
-- target acknowledged:
--   * the capability is SERVICING (a stored state; retired admits nothing, and a
--     feature that is off admits nothing whatever the state says);
--   * the document is an invoice row of the connection's own workspace whose
--     replaces_invoice_id points to an invoice of the same workspace that has an
--     ACKNOWLEDGED delivery on THIS connection. Only the direct link counts: a
--     chain needs each step acknowledged before the next;
--   * the link is read from the invoice row, never from the request: a caller
--     supplies no label that could make something a correction.
-- Everything else keeps the unchanged 0A000. Authority (actor, native token,
-- manageBilling) is untouched. The delivery's provenance context records
-- linked_correction and the replaced invoice, server-derived.

create or replace function public.capability_linked_correction(p_connection_id uuid, p_document_kind text, p_document_id uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1
      from public.accounting_connections c
      join public.capability_states s
        on s.workspace_id = c.workspace_id and s.capability_key = 'accountingConnectors' and s.state = 'servicing'
      join public.invoices i
        on i.id = p_document_id and i.workspace_id = c.workspace_id
      join public.invoices o
        on o.id = i.replaces_invoice_id and o.workspace_id = c.workspace_id
      join public.accounting_deliveries d
        on d.connection_id = c.id and d.workspace_id = c.workspace_id
       and d.document_id = o.id and d.status = 'acknowledged'
     where c.id = p_connection_id
       and c.revoked_at is null and c.status = 'connected'
       and btrim(p_document_kind) in ('invoice', 'credit_note')
       and public.feature_effective(c.workspace_id, 'accountingConnectors'));
$fn$;
revoke execute on function public.capability_linked_correction(uuid, text, uuid) from public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.record_accounting_delivery(p_connection_id uuid, p_document_kind text, p_document_id uuid, p_event_date date, p_document_number text, p_period_from date, p_period_to date, p_payload_sha256 text, p_status text, p_remote jsonb, p_error text, p_in_flight_seconds integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  c public.accounting_connections;
  d public.accounting_deliveries;
  v_identity text;
  v_remote_id text := coalesce(p_remote ->> 'id', '');
  v_status text := p_status;
  v_error text := left(coalesce(p_error, ''), 1000);
  v_outcome text;
  v_corr boolean := false;
begin
  select * into c from public.accounting_connections where id = p_connection_id;
  if c.id is null then raise exception 'unknown connection' using errcode = 'P0002'; end if;
  if p_status not in ('generated', 'sent', 'acknowledged', 'conflict', 'failed') then
    raise exception 'unknown delivery status %', p_status using errcode = '22023';
  end if;
  v_identity := 'c:' || c.id || ':' || btrim(p_document_kind) || ':' || p_document_id || ':' || p_event_date;
  select * into d from public.accounting_deliveries
   where workspace_id = c.workspace_id and identity_key = v_identity for update;
  if d.id is null and not public.capability_admits(c.workspace_id, 'accountingConnectors') then
    -- #3336 -- servicing completes work already begun: the one new delivery it
    -- admits is the explicitly linked correction of a document this very
    -- connection delivered and the target acknowledged
    v_corr := public.capability_linked_correction(c.id, p_document_kind, p_document_id);
    if not v_corr then
      raise exception 'accounting connections are switched off in this space' using errcode = '0A000';
    end if;
  end if;
  if d.id is null and c.remote_tenant_id <> '' then
    -- the same document, delivered by a revoked connection to the same company
    select dd.* into d from public.accounting_deliveries dd
      join public.accounting_connections pc on pc.id = dd.connection_id
     where dd.workspace_id = c.workspace_id and pc.id <> c.id and pc.revoked_at is not null
       and pc.issuer_site_id = c.issuer_site_id and pc.target_id = c.target_id
       and pc.remote_tenant_id = c.remote_tenant_id
       and dd.document_kind = btrim(p_document_kind) and dd.document_id = p_document_id
       and dd.event_date = p_event_date
     order by dd.created_datetime desc limit 1 for update of dd;
    if d.id is not null then
      update public.accounting_deliveries
         set connection_id = c.id, identity_key = v_identity
       where id = d.id
      returning * into d;
    end if;
  end if;
  if d.id is null then
    if c.revoked_at is not null or c.status <> 'connected' then
      raise exception 'this connection cannot deliver: %', c.status using errcode = '23514';
    end if;
    insert into public.accounting_deliveries
      (workspace_id, issuer_site_id, connection_id, target_id, identity_key, idempotency_key,
       period_from, period_to, document_kind, document_id, document_number, event_date,
       payload_sha256, status, error, sent_at)
    values (c.workspace_id, c.issuer_site_id, c.id, c.target_id, v_identity,
            public.accounting_idempotency_key(v_identity), p_period_from, p_period_to,
            btrim(p_document_kind), p_document_id, coalesce(p_document_number, ''), p_event_date,
            lower(p_payload_sha256), case when p_status = 'acknowledged' then 'sent' else p_status end,
            v_error, case when p_status in ('sent', 'acknowledged') then now() end)
    returning * into d;
    -- #3336 -- the issuer context of the first durable preparation, pinned once and
    -- kept through every later outcome of this delivery
    perform public.record_provenance(c.workspace_id, 'accounting_delivery', d.id,
      jsonb_build_object('issuer_site_id', c.issuer_site_id, 'target_id', c.target_id,
                         'connection_id', c.id, 'document_kind', btrim(p_document_kind))
      || case when v_corr then jsonb_build_object('linked_correction', true,
           'replaces_invoice_id', (select i.replaces_invoice_id from public.invoices i where i.id = p_document_id))
         else '{}'::jsonb end,
      '{}'::jsonb,
      jsonb_build_object('payload_sha256', lower(p_payload_sha256)));
    if p_status <> 'acknowledged' then
      return public.accounting_delivery_json(d) || jsonb_build_object('outcome', 'created');
    end if;
  end if;
  if d.status = 'acknowledged' then
    if d.payload_sha256 = lower(p_payload_sha256) and (v_remote_id = '' or v_remote_id = d.remote_id) then
      return public.accounting_delivery_json(d) || jsonb_build_object('outcome', 'unchanged');
    end if;
    if d.payload_sha256 <> lower(p_payload_sha256) then
      raise exception 'this document was acknowledged with another content: it needs a correction, not a second delivery'
        using errcode = '23514';
    end if;
  end if;
  -- Preparing a delivery that already exists changes nothing: a send whose
  -- outcome is unknown stays so until a readback resolves it.
  if p_status = 'generated' then
    if coalesce(p_in_flight_seconds, 0) > 0 and d.status in ('generated', 'sent')
       and greatest(d.created_datetime, coalesce(d.sent_at, d.created_datetime))
           > now() - make_interval(secs => p_in_flight_seconds) then
      return public.accounting_delivery_json(d) || jsonb_build_object('outcome', 'in_flight');
    end if;
    return public.accounting_delivery_json(d) || jsonb_build_object('outcome', 'existing');
  end if;
  if v_remote_id <> '' and d.remote_id <> '' and v_remote_id <> d.remote_id then
    v_status := 'conflict';
    v_error := left('the remote holds ' || d.remote_id || ' and answered ' || v_remote_id, 1000);
  elsif v_status = 'acknowledged' and v_remote_id = '' and d.remote_id = '' then
    raise exception 'an acknowledged delivery names its remote id' using errcode = '22023';
  end if;
  update public.accounting_deliveries set
    status = v_status,
    error = case when v_status in ('conflict', 'failed') then v_error else '' end,
    payload_sha256 = lower(p_payload_sha256),
    document_number = coalesce(nullif(p_document_number, ''), document_number),
    remote_id = case when v_status = 'conflict' then remote_id else coalesce(nullif(v_remote_id, ''), remote_id) end,
    remote_number = coalesce(nullif(p_remote ->> 'number', ''), remote_number),
    remote_version = coalesce(nullif(p_remote ->> 'version', ''), remote_version),
    remote_state = coalesce(nullif(p_remote ->> 'state', ''), remote_state),
    attempts = attempts + case when v_status = 'sent' and d.status <> 'generated' then 1 else 0 end,
    sent_at = case when v_status = 'sent' then now() else sent_at end,
    acknowledged_at = case when v_status = 'acknowledged' then now() else acknowledged_at end
  where id = d.id
  returning * into d;
  v_outcome := case when v_status = 'conflict' and p_status <> 'conflict' then 'conflict' else 'updated' end;
  return public.accounting_delivery_json(d) || jsonb_build_object('outcome', v_outcome);
end;
$function$;

-- the ACL it was born with, stated here for the grants lint: the service role only
revoke execute on function public.record_accounting_delivery(uuid, text, uuid, date, text, date, date, text, text, jsonb, text, integer)
  from public, anon, authenticated;

select public.set_deskilo_schema_version(695);
