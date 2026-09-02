-- SPDX-License-Identifier: 0BSD
-- 0148 — #831: a settlement carries its sources' LINES, and a settled
-- source is documentation only.
--
--  * settle_invoices v3 — the regrouping invoice's lines are the lines
--    of every source, each tagged with the source's number, and its
--    vat_totals are aggregated from them the way create_invoice does:
--    the document the member pays is complete on its own. The settles
--    snapshot, the numbering, the signature and the validation event
--    stay as in v2 (0144).
--  * record_invoice_reminder — refuses a settled source, as the sweep
--    already does: the settlement is what is chased.

create or replace function public.settle_invoices(
  p_workspace_id uuid,
  p_member_id uuid,
  p_invoice_ids uuid[],
  p_note text default ''
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_subject public.members;
  v_workspace public.workspaces;
  v_latest public.invoices;
  v_lines jsonb := '[]'::jsonb;
  v_settles jsonb := '[]'::jsonb;
  v_vat jsonb;
  v_zero_category text;
  v_total int := 0;
  v_count int;
  v_number text;
  v_id uuid;
  v_signature text;
  v_issuer_name text;
  v_src public.invoices;
  v_line jsonb;
  v_n int := 0;
  v_has_policy boolean;
begin
  -- #816 — the matrix alone decides; the feature must be on.
  v_actor := public.issuing_member(p_workspace_id);
  select * into v_workspace from public.workspaces where id = p_workspace_id;
  if not coalesce((v_workspace.feature_flags ->> 'invoiceSettlement')::boolean, true) then
    raise exception 'invoice settlement is not enabled';
  end if;

  select * into v_subject from public.members
    where id = p_member_id and workspace_id = p_workspace_id
      and status = 'active' and not is_kiosk;
  if v_subject.id is null then raise exception 'unknown subject member'; end if;

  if p_invoice_ids is null or array_length(p_invoice_ids, 1) is null
     or array_length(p_invoice_ids, 1) < 2 then
    raise exception 'settle at least two invoices';
  end if;

  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));

  for v_src in
    select * from public.invoices
     where id = any(p_invoice_ids)
     order by issued_at, number
  loop
    v_n := v_n + 1;
    if v_src.workspace_id <> p_workspace_id then
      raise exception 'invoice % is not in this workspace', v_src.number;
    end if;
    if v_src.member_id <> p_member_id then
      raise exception 'invoice % belongs to another member', v_src.number;
    end if;
    if v_src.voided_at is not null then
      raise exception 'invoice % is void', v_src.number;
    end if;
    if v_src.settled_by_invoice_id is not null then
      raise exception 'invoice % is already settled', v_src.number;
    end if;
    if v_src.kind = 'settlement' then
      raise exception 'invoice % is itself a settlement', v_src.number;
    end if;
    if exists (select 1 from public.invoice_matches m
                where m.invoice_id = v_src.id) then
      raise exception 'invoice % already has a payment', v_src.number;
    end if;

    v_total := v_total + v_src.total_cents;
    -- #831 — every position of the source, tagged with where it came
    -- from, so the regrouping reads as the invoices it replaces.
    for v_line in select * from jsonb_array_elements(v_src.lines) loop
      v_lines := v_lines || (v_line || jsonb_build_object(
        'source_number', v_src.number,
        'source_id', v_src.id));
    end loop;
    v_settles := v_settles || jsonb_build_object(
      'invoice_id', v_src.id,
      'number', v_src.number,
      'period', v_src.period,
      'kind', v_src.kind,
      'issued_at', v_src.issued_at,
      'total_cents', v_src.total_cents,
      'currency', v_src.currency,
      'lines', v_src.lines,
      'vat_totals', v_src.vat_totals);
    v_latest := v_src;
  end loop;

  if v_n <> array_length(p_invoice_ids, 1) then
    raise exception 'unknown invoice in the selection';
  end if;

  -- The VAT breakdown of the carried lines, as create_invoice (0142)
  -- builds it: one entry per rate, charges only.
  v_zero_category := case coalesce(v_workspace.vat_regime, 'not_subject')
                       when 'exempt' then 'E' else 'O' end;
  with charges as (
    select coalesce((l->>'vat_percent')::numeric, 0) as percent,
           (l->>'amount_cents')::int as gross,
           round((l->>'amount_cents')::int * 100.0
                 / (100 + coalesce((l->>'vat_percent')::numeric, 0)))::int as net
      from jsonb_array_elements(v_lines) l
     where (l->>'amount_cents')::int > 0
  ), by_rate as (
    select percent, sum(gross)::int as gross, sum(net)::int as net
      from charges group by percent
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'percent', percent,
      'category', case when percent > 0 then 'S' else v_zero_category end,
      'gross_cents', gross,
      'net_cents', net,
      'vat_cents', gross - net) order by percent desc), '[]'::jsonb)
    into v_vat from by_rate;

  select coalesce(display_name, '') into v_issuer_name
    from public.profiles where id = v_actor.user_id;

  select count(*) into v_count from public.invoices
    where workspace_id = p_workspace_id
      and date_part('year', issued_at) = date_part('year', now());
  v_number := 'INV-' || date_part('year', now())::int || '-'
      || lpad((v_count + 1)::text, 4, '0');

  v_id := gen_random_uuid();
  v_signature := encode(extensions.digest(convert_to(concat_ws('|',
      v_id::text, v_number, p_workspace_id::text, v_subject.id::text,
      v_lines::text, v_total::text, v_settles::text,
      now()::date::text, 'settlement'),
      'UTF8'), 'sha256'), 'hex');

  insert into public.invoices
    (id, workspace_id, member_id, issuer_member_id, number, period, title,
     lines, total_cents, currency, member_name, member_address,
     workspace_name, workspace_address, issuer_name, signature,
     parties, vat_totals, kind, settles)
  values
    (v_id, p_workspace_id, p_member_id, v_actor.id, v_number,
     null, coalesce(nullif(p_note, ''), v_number),
     v_lines, v_total, v_latest.currency,
     v_latest.member_name, v_latest.member_address,
     v_latest.workspace_name, v_latest.workspace_address,
     v_issuer_name, v_signature,
     v_latest.parties,
     v_vat, 'settlement', v_settles);

  update public.invoices
     set settled_by_invoice_id = v_id
   where id = any(p_invoice_ids);

  v_has_policy := exists (
    select 1 from public.validation_policies vp
    where vp.workspace_id = p_workspace_id
      and vp.event_type = 'invoice_payment');
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     payload, status, decided_at)
  values
    (p_workspace_id, 'invoice_payment', 'submitted', v_actor.id, p_member_id,
     jsonb_build_object(
       'invoice_id', v_id, 'number', v_number, 'kind', 'settlement',
       'amount_cents', v_total, 'currency', v_latest.currency,
       'settled_count', v_n,
       'settled_numbers', (select jsonb_agg(s->>'number')
                             from jsonb_array_elements(v_settles) s)),
     case when v_has_policy then 'pending' else 'confirmed' end,
     case when v_has_policy then null else now() end);

  return v_id;
end;
$$;
revoke execute on function
  public.settle_invoices(uuid, uuid, uuid[], text) from public, anon;
grant execute on function
  public.settle_invoices(uuid, uuid, uuid[], text) to authenticated;

-- record_invoice_reminder: a settled source is chased through its
-- settlement, never on its own. Patched in place: the live body is the
-- 0144 v2 text; the anchor is asserted.
do $patch$
declare v_def text; v_anchor text; v_guard text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'record_invoice_reminder';
  v_anchor := E'  if v_invoice.voided_at is not null then\n    raise exception ''invoice is voided'';\n  end if;\n';
  v_guard := v_anchor || E'  if v_invoice.settled_by_invoice_id is not null then\n    raise exception ''invoice is settled'';\n  end if;\n';
  if position(v_anchor in v_def) = 0 then
    raise exception 'record_invoice_reminder anchor not found';
  end if;
  if position('invoice is settled' in v_def) = 0 then
    execute replace(v_def, v_anchor, v_guard);
  end if;
end $patch$;

notify pgrst, 'reload schema';
