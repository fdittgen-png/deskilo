-- SPDX-License-Identifier: 0BSD
-- The e-invoice was structurally invalid: EN 16931 rule BR-CO-26 is
-- FATAL and demands at least one seller identifier (BT-29 seller id,
-- BT-30 legal registration id, BT-31 VAT id) — the app carried none, so
-- every exported XML was rejected by any validator. And the tax coding
-- was a guess: category `O` (out of scope) forbids a seller tax
-- identifier (BR-O-02), while a small operator under a national VAT
-- exemption belongs in category `E` WITH an identifier and an exemption
-- reason (BR-E-02, BR-E-10).
--
-- So the workspace now carries a LEGAL IDENTITY (owner-edited), the
-- member profile carries the two buyer facts the norm needs, and every
-- invoice SNAPSHOTS both parties — an issued document must keep saying
-- what it said, even after the workspace changes its VAT regime.

-- 1. The seller's legal identity. Split address parts (BT-35/37/38)
-- beside the free-text `address` the PDF letterhead prints: national
-- CIUS profiles want the city and the post code as their own fields.
alter table public.workspaces
  add column vat_regime text not null default 'not_subject'
    check (vat_regime in ('not_subject', 'exempt', 'vat_registered')),
  add column vat_id text not null default ''
    check (char_length(vat_id) <= 20),
  add column legal_id text not null default ''
    check (char_length(legal_id) <= 30),
  add column tax_exemption_reason text not null default ''
    check (char_length(tax_exemption_reason) <= 120),
  add column street text not null default ''
    check (char_length(street) <= 120),
  add column city text not null default ''
    check (char_length(city) <= 60),
  add column postal_code text not null default ''
    check (char_length(postal_code) <= 12);

comment on column public.workspaces.vat_regime is
  'EN 16931 BT-151 mapping: not_subject → category O (no seller tax id '
  'allowed, BR-O-02), exempt → category E (seller tax id + exemption '
  'reason required, BR-E-02/BR-E-10), vat_registered → the app does not '
  'compute VAT yet, so the XML export refuses.';

-- 2. The buyer facts the norm needs beyond the name: the country (BT-55
-- is mandatory — defaulting it to the workspace country silently
-- mis-declares a foreign customer) and the VAT id of a business member
-- (BT-48).
alter table public.profiles
  add column country_code text not null default ''
    check (country_code = '' or country_code ~ '^[A-Z]{2}$'),
  add column vat_id text not null default ''
    check (char_length(vat_id) <= 20);

-- 3. The immutable snapshot. Legacy invoices keep `parties = null` and
-- render from the flat 0060 columns.
alter table public.invoices add column parties jsonb;

comment on column public.invoices.parties is
  'Issue-time snapshot of both parties for the e-invoice: seller legal '
  'identity + VAT regime, buyer country + VAT id. Frozen like every '
  'other invoice field.';

-- 4. create_invoice v7: the 0068 body plus the parties snapshot, which
-- joins the signed content (a changed identity must break the
-- fingerprint like any other change).
create or replace function public.create_invoice(
  p_workspace_id uuid,
  p_member_id uuid,
  p_period text,
  p_replaces uuid default null,
  p_detailed boolean default false
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_subject public.members;
  v_workspace public.workspaces;
  v_replaced public.invoices;
  v_replaces_number text := '';
  v_lines jsonb;
  v_details jsonb := null;
  v_parties jsonb;
  v_tz text;
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_total int := 0;
  v_count int;
  v_number text;
  v_member_name text;
  v_member_address text;
  v_member_country text;
  v_member_vat text;
  v_issuer_name text;
  v_id uuid;
  v_signature text;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid()
      and status = 'active' and (is_admin or is_owner);
  if v_actor.id is null then raise exception 'not an admin of this workspace'; end if;
  if not public.is_owner_of(p_workspace_id) and not coalesce(
    (select w.feature_flags -> 'adminInvoicing' = to_jsonb(true)
       from public.workspaces w where w.id = p_workspace_id), false) then
    raise exception 'admins may not issue invoices here';
  end if;

  select * into v_subject from public.members
    where id = p_member_id and workspace_id = p_workspace_id
      and status = 'active' and not is_kiosk;
  if v_subject.id is null then raise exception 'unknown subject member'; end if;
  if p_period is null or p_period !~ '^[0-9]{4}-[0-9]{2}$' then
    raise exception 'invalid period';
  end if;
  -- 0067: one ACTIVE invoice per member+month. Voided (erronée)
  -- invoices free their month; the one being replaced is voided below
  -- in this same transaction, so it does not count either.
  if exists (
    select 1 from public.invoices i
    where i.member_id = v_subject.id and i.period = p_period
      and i.voided_at is null and i.id is distinct from p_replaces
  ) then
    raise exception 'period already invoiced for this member';
  end if;

  v_lines := public.invoice_lines_for(p_member_id, p_period);
  if jsonb_array_length(v_lines) = 0 then
    raise exception 'nothing to invoice for this period';
  end if;
  select coalesce(sum((l->>'amount_cents')::int), 0) into v_total
    from jsonb_array_elements(v_lines) l;

  select * into v_workspace from public.workspaces where id = p_workspace_id;
  select coalesce(display_name, ''), coalesce(address, ''),
         coalesce(country_code, ''), coalesce(vat_id, '')
    into v_member_name, v_member_address, v_member_country, v_member_vat
    from public.profiles where id = v_subject.user_id;
  select coalesce(display_name, '') into v_issuer_name
    from public.profiles where id = v_actor.user_id;

  v_parties := jsonb_build_object(
    'seller', jsonb_build_object(
      'name', v_workspace.name,
      'street', coalesce(nullif(v_workspace.street, ''),
                         coalesce(v_workspace.address, '')),
      'city', coalesce(v_workspace.city, ''),
      'postal_code', coalesce(v_workspace.postal_code, ''),
      'country', v_workspace.country_code,
      'vat_id', coalesce(v_workspace.vat_id, ''),
      'legal_id', coalesce(v_workspace.legal_id, ''),
      'vat_regime', coalesce(v_workspace.vat_regime, 'not_subject'),
      'tax_exemption_reason',
        coalesce(v_workspace.tax_exemption_reason, '')),
    'buyer', jsonb_build_object(
      'name', v_member_name,
      'street', v_member_address,
      -- A member who never set a country is invoiced where the
      -- workspace is established; the client says so explicitly.
      'country', coalesce(nullif(v_member_country, ''),
                          v_workspace.country_code),
      'vat_id', v_member_vat));

  if p_detailed then
    v_tz := v_workspace.timezone;
    v_period_start := to_timestamp(p_period || '-01', 'YYYY-MM-DD') at time zone v_tz;
    v_period_end := (to_timestamp(p_period || '-01', 'YYYY-MM-DD') + interval '1 month') at time zone v_tz;
    v_details := jsonb_build_object(
      'ledger', coalesce((
        select jsonb_agg(jsonb_build_object(
            'on', le.created_at::date::text,
            'category', le.category,
            'description', le.description,
            'amount_cents', case when le.kind = 'credit'
                                 then -le.amount_cents
                                 else le.amount_cents end)
          order by le.created_at)
        from public.ledger_entries le
        where le.member_id = p_member_id and le.period = p_period
      ), '[]'::jsonb),
      'attendance', coalesce((
        select jsonb_agg(jsonb_build_object(
            'starts_at', to_char(r.starts_at at time zone v_tz,
                                 'YYYY-MM-DD"T"HH24:MI'),
            'ends_at', to_char(r.ends_at at time zone v_tz,
                               'YYYY-MM-DD"T"HH24:MI'),
            'status', r.status,
            'space', coalesce(
              (select s.name || ' · ' || d.name
                 from public.seats s
                 join public.desks d on d.id = s.desk_id
                where s.id = r.seat_id),
              (select d.name from public.desks d where d.id = r.desk_id),
              (select o.name from public.offices o where o.id = r.office_id),
              (select l.name from public.levels l where l.id = r.level_id),
              ''))
          order by r.starts_at)
        from public.reservations r
        where r.member_id = p_member_id
          and r.status in ('reserved', 'checked_in', 'completed')
          and r.starts_at >= v_period_start and r.starts_at < v_period_end
      ), '[]'::jsonb));
  end if;

  if p_replaces is not null then
    select * into v_replaced from public.invoices
      where id = p_replaces and workspace_id = p_workspace_id;
    if v_replaced.id is null then raise exception 'unknown invoice'; end if;
    if exists (select 1 from public.invoices
                where replaces_invoice_id = p_replaces) then
      raise exception 'invoice already replaced';
    end if;
    if exists (select 1 from public.invoice_matches
                where invoice_id = p_replaces) then
      -- 0068: a paid invoice is definitive — no replacement either.
      raise exception 'invoice is matched';
    end if;
    if v_replaced.voided_at is null then
      update public.invoices
         set voided_at = now(), voided_by_name = v_issuer_name
       where id = p_replaces;
    end if;
    v_replaces_number := v_replaced.number;
  end if;

  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));
  select count(*) into v_count from public.invoices
    where workspace_id = p_workspace_id
      and date_part('year', issued_at) = date_part('year', now());
  v_number := 'INV-' || date_part('year', now())::int || '-'
      || lpad((v_count + 1)::text, 4, '0');

  v_id := gen_random_uuid();
  v_signature := encode(extensions.digest(convert_to(concat_ws('|',
      v_id::text, v_number, p_workspace_id::text, v_subject.id::text,
      v_member_name, v_member_address, v_workspace.name,
      coalesce(v_workspace.address, ''), v_issuer_name,
      p_period, v_lines::text, v_total::text, v_workspace.currency_code,
      now()::date::text, coalesce(p_replaces::text, ''),
      v_replaces_number, coalesce(v_details::text, ''),
      v_parties::text),
      'UTF8'), 'sha256'), 'hex');

  insert into public.invoices
    (id, workspace_id, member_id, issuer_member_id, number, period, title,
     lines, total_cents, currency, member_name, member_address,
     workspace_name, workspace_address, issuer_name, signature,
     replaces_invoice_id, replaces_number, details, parties)
  values
    (v_id, p_workspace_id, v_subject.id, v_actor.id, v_number, p_period,
     p_period, v_lines, v_total, v_workspace.currency_code,
     v_member_name, v_member_address, v_workspace.name,
     coalesce(v_workspace.address, ''), v_issuer_name, v_signature,
     p_replaces, v_replaces_number, v_details, v_parties);
  return v_id;
end;
$$;
revoke execute on function
  public.create_invoice(uuid, uuid, text, uuid, boolean) from public, anon;
