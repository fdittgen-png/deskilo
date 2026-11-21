-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #4166 (cut 1) -- a customer quote: a priced offer to a billing customer, its
-- revisions, the acceptance the issuer records, and its conversion into ONE
-- initial standalone invoice. Access code: every function is guarded, nothing
-- here touches a receivable, a payment, a stock movement or a posting before the
-- invoice is issued by #4165's own issuer.
--
--   * `customer_quotes`: the quote (seller, customer subject = `members.id`, its
--     own reference from the `quote` number series, never an invoice number).
--     Status draft -> sent -> accepted | declined | cancelled -> converted.
--     Expiry is DERIVED from the stated validity and the business clock
--     (`customer_quotes_v1`); it stops a late acceptance, never an accepted quote.
--   * `customer_quote_revisions`: the offer's content. A revision is editable
--     only while it is a draft (an expected `draft_version`); SENDING freezes the
--     exact content (lines with stable `line_id`, the totals the real issuer
--     computes, the terms) and its digest. A correction is a new revision.
--   * `customer_quote_decisions`: the acceptance or refusal of one immutable
--     revision. It is what the ISSUER recorded (actor, when, source, the date the
--     customer decided); it is never a customer's signature.
--   * `customer_quote_conversions`: PRIMARY KEY (quote_id): a quote produces at
--     most one initial invoice, ever, whatever the request id and whatever later
--     happens to that invoice. The invoice draft it came from carries
--     `origin_quote_id`, so invoice <- draft <- quote revision is one chain, and the
--     line identities (`line_id`) travel unchanged.
--
-- Not here: the customer's own acceptance (it needs #4164's billing grant), the
-- quote document and screens (cut 2), the operation registry (cut 3).

-- ── 0. the two seams of #4165, now naming the billing customer ──────────
-- #4165 isolated who a standalone invoice may be made out to (`standalone_invoice_subject`)
-- and what its buyer block says (`standalone_invoice_buyer`) so #4164 could widen them.
-- Both are restated whole: the subject is any billable subject of the business, a
-- customer-only one included (`billing_customer_ok`), and the buyer is the seller's
-- billing identity when there is one (`billing_party_buyer`), else the profile or the
-- managed identity exactly as before. A quote and its invoice read the same customer.
create or replace function public.standalone_invoice_subject(p_workspace_id uuid, p_subject uuid)
returns public.members language plpgsql stable security definer set search_path = public as $fn$
declare
  v_subject public.members;
begin
  select * into v_subject from public.members m
   where m.id = p_subject and m.workspace_id = p_workspace_id
     and public.billing_customer_ok(p_workspace_id, m.id);
  if v_subject.id is null then
    raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'unknown_subject';
  end if;
  return v_subject;
end $fn$;
revoke execute on function public.standalone_invoice_subject(uuid, uuid) from public, anon, authenticated;

-- The buyer block of a standalone invoice (a seam, as above): the fields
-- `create_invoice` freezes for a member, from the profile or the managed identity.
create or replace function public.standalone_invoice_buyer(p_workspace_id uuid, p_subject uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_ws public.workspaces;
  v_subject public.members;
  v_name text; v_address text; v_country text; v_vat text; v_company text; v_street text;
  v_postal text; v_city text; v_legal text; v_email text; v_phone text; v_person text; v_courtesy text;
begin
  select * into v_ws from public.workspaces where id = p_workspace_id;
  select * into v_subject from public.members where id = p_subject and workspace_id = p_workspace_id;
  select coalesce(nullif(public.profile_full_name(pr), ''), pr.display_name, ''),
         coalesce(nullif(public.profile_postal_block(pr, v_ws.country_code, v_ws.default_locale), ''),
                  pr.address, ''),
         coalesce(pr.country_code, ''), coalesce(pr.vat_id, ''),
         coalesce(pr.company, ''), coalesce(pr.street, ''),
         coalesce(pr.postal_code, ''), coalesce(pr.city, ''),
         coalesce(pr.legal_id, ''), coalesce(pr.email, ''), coalesce(pr.phone, ''),
         coalesce(public.profile_person_name(pr), ''), coalesce(pr.courtesy, '')
    into v_name, v_address, v_country, v_vat, v_company, v_street, v_postal, v_city,
         v_legal, v_email, v_phone, v_person, v_courtesy
    from jsonb_populate_record(null::public.profiles,
           coalesce(public.billing_party_buyer(p_workspace_id, v_subject.id),
                    (select to_jsonb(p) from public.profiles p where p.id = v_subject.user_id),
                    coalesce((select mi.identity from public.managed_identities mi
                               where mi.member_id = v_subject.id), '{}'::jsonb))) pr;
  return jsonb_build_object(
    'name', v_name, 'company', v_company, 'person', v_person, 'courtesy', v_courtesy,
    'street', case when v_street <> '' then v_street else v_address end,
    'postal_code', v_postal, 'city', v_city, 'legal_id', v_legal,
    'member_number', coalesce(v_subject.member_number, ''),
    'email', v_email, 'phone', v_phone,
    'country', coalesce(nullif(v_country, ''), v_ws.country_code),
    'vat_id', v_vat,
    'vat_treatment', coalesce(v_subject.vat_treatment, 'auto'),
    'tax_exemption_reason', coalesce(v_subject.vat_exemption_reason, ''));
end $fn$;
revoke execute on function public.standalone_invoice_buyer(uuid, uuid) from public, anon, authenticated;

-- ── 1. the quote series ──────────────────────────────────────────────────
-- A quote has a reference of its own, from its own series (`journal = 'quote'`).
create or replace function public.number_sequence_defaults(p_journal text)
returns table (prefix text, date_part text, reset text)
language sql immutable as $fn$
  select case p_journal when 'invoice' then 'INV-' when 'credit_note' then 'CN-'
                        when 'vat_declaration' then 'DECL-' when 'member' then 'M-'
                        when 'payment' then 'PAY-' when 'quote' then 'QUO-' else '' end,
         case p_journal when 'member' then 'none' else 'year' end,
         case p_journal when 'member' then 'never' else 'yearly' end;
$fn$;
revoke execute on function public.number_sequence_defaults(text) from public, anon;
grant execute on function public.number_sequence_defaults(text) to authenticated, service_role;

-- ── 2. the tables ────────────────────────────────────────────────────────
create table public.customer_quotes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  subject_member_id uuid not null,
  reference text,
  status text not null default 'draft'
    check (status in ('draft', 'sent', 'accepted', 'declined', 'cancelled', 'converted')),
  foreign key (workspace_id, subject_member_id)
    references public.members (workspace_id, id) on delete restrict,
  unique (workspace_id, id),
  check ((status = 'draft') or reference is not null)
);
select public.ensure_system_columns('customer_quotes');
create unique index customer_quotes_reference_key
  on public.customer_quotes (workspace_id, reference) where reference is not null;
create index customer_quotes_workspace_idx on public.customer_quotes (workspace_id, status);

create table public.customer_quote_revisions (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null,
  workspace_id uuid not null,
  revision integer not null check (revision >= 1),
  status text not null default 'draft' check (status in ('draft', 'sent')),
  draft_version integer not null default 1 check (draft_version >= 1),
  issued_on date not null,
  valid_until date not null,
  buyer_reference text not null default '' check (char_length(buyer_reference) <= 120),
  purchase_order text not null default '' check (char_length(purchase_order) <= 120),
  notes text not null default '' check (char_length(notes) <= 2000),
  lines jsonb not null default '[]'::jsonb check (jsonb_typeof(lines) = 'array'),
  frozen jsonb,
  content_digest text,
  sent_at timestamptz,
  sent_by_member_id uuid,
  superseded_at timestamptz,
  unique (quote_id, revision),
  unique (workspace_id, id),
  foreign key (workspace_id, quote_id)
    references public.customer_quotes (workspace_id, id) on delete restrict,
  check (valid_until >= issued_on),
  check ((status = 'sent') = (sent_at is not null and frozen is not null and content_digest is not null))
);
select public.ensure_system_columns('customer_quote_revisions');

create table public.customer_quote_decisions (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null unique,
  workspace_id uuid not null,
  revision_id uuid not null,
  decision text not null check (decision in ('accepted', 'declined')),
  decided_on date not null,
  source text not null check (source in ('received_outside_app', 'verbal', 'email', 'other')),
  evidence text not null default '' check (char_length(evidence) <= 1000),
  recorded_by_member_id uuid not null,
  recorded_at timestamptz not null default now(),
  -- what this is: the issuer's record of a decision, never a customer's signature
  recorded_by_issuer boolean not null default true check (recorded_by_issuer),
  foreign key (workspace_id, quote_id) references public.customer_quotes (workspace_id, id) on delete restrict,
  foreign key (workspace_id, revision_id) references public.customer_quote_revisions (workspace_id, id) on delete restrict
);
select public.ensure_system_columns('customer_quote_decisions');

create table public.customer_quote_conversions (
  quote_id uuid primary key,
  workspace_id uuid not null,
  revision_id uuid not null,
  draft_id uuid not null unique,
  invoice_id uuid not null unique,
  line_map jsonb not null default '[]'::jsonb,
  converted_by_member_id uuid not null,
  converted_at timestamptz not null default now(),
  foreign key (workspace_id, quote_id) references public.customer_quotes (workspace_id, id) on delete restrict,
  foreign key (workspace_id, revision_id) references public.customer_quote_revisions (workspace_id, id) on delete restrict,
  foreign key (workspace_id, invoice_id) references public.invoices (workspace_id, id) on delete restrict
);
select public.ensure_system_columns('customer_quote_conversions');

-- The invoice draft a quote became: one chain from the invoice back to the revision.
alter table public.standalone_invoice_drafts
  add column origin_quote_id uuid references public.customer_quotes (id) on delete restrict;
create unique index standalone_invoice_drafts_one_per_quote
  on public.standalone_invoice_drafts (origin_quote_id) where origin_quote_id is not null;

-- ── 3. access: issuers and finance readers read; nobody writes directly ──
create or replace function public.customer_quotes_readable(p_workspace uuid) returns boolean
language sql stable security definer set search_path = public as $fn$
  select auth.uid() is not null and not public.mcp_is_delegated()
     and (public.has_permission(p_workspace, 'issueInvoices')
          or public.has_permission(p_workspace, 'viewFinances'));
$fn$;
revoke execute on function public.customer_quotes_readable(uuid) from public, anon;
grant execute on function public.customer_quotes_readable(uuid) to authenticated;

alter table public.customer_quotes enable row level security;
revoke all on public.customer_quotes from public, anon, authenticated;
grant select on public.customer_quotes to authenticated;
create policy customer_quotes_read on public.customer_quotes for select to authenticated
  using (public.customer_quotes_readable(workspace_id));
create policy mcp_delegated_deny on public.customer_quotes as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

alter table public.customer_quote_revisions enable row level security;
revoke all on public.customer_quote_revisions from public, anon, authenticated;
grant select on public.customer_quote_revisions to authenticated;
create policy customer_quote_revisions_read on public.customer_quote_revisions for select to authenticated
  using (public.customer_quotes_readable(workspace_id));
create policy mcp_delegated_deny on public.customer_quote_revisions as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

alter table public.customer_quote_decisions enable row level security;
revoke all on public.customer_quote_decisions from public, anon, authenticated;
grant select on public.customer_quote_decisions to authenticated;
create policy customer_quote_decisions_read on public.customer_quote_decisions for select to authenticated
  using (public.customer_quotes_readable(workspace_id));
create policy mcp_delegated_deny on public.customer_quote_decisions as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

alter table public.customer_quote_conversions enable row level security;
revoke all on public.customer_quote_conversions from public, anon, authenticated;
grant select on public.customer_quote_conversions to authenticated;
create policy customer_quote_conversions_read on public.customer_quote_conversions for select to authenticated
  using (public.customer_quotes_readable(workspace_id));
create policy mcp_delegated_deny on public.customer_quote_conversions as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── 4. what never changes ────────────────────────────────────────────────
-- A SENT revision is its frozen content: only `superseded_at` may be set (when a
-- newer revision is sent), and it is never deleted. A decision and a conversion
-- are never changed or deleted. A quote with anything sent is never deleted.
create or replace function public.customer_quote_frozen() returns trigger
language plpgsql set search_path = public as $fn$
begin
  if tg_table_name = 'customer_quote_revisions' then
    if tg_op = 'DELETE' then
      if old.status = 'sent' then
        raise exception 'a sent revision is never deleted' using errcode = 'DKQ05';
      end if;
      return old;
    end if;
    if old.status = 'sent' and (
         (to_jsonb(new) - 'superseded_at' - public.system_column_names())
         is distinct from (to_jsonb(old) - 'superseded_at' - public.system_column_names())) then
      raise exception 'a sent revision cannot be edited: amend the quote' using errcode = 'DKQ05';
    end if;
    return new;
  elsif tg_table_name = 'customer_quotes' then
    if tg_op = 'DELETE' and (old.status <> 'draft' or exists (
         select 1 from public.customer_quote_revisions r
          where r.quote_id = old.id and r.status = 'sent')) then
      raise exception 'a quote that was sent is never deleted' using errcode = 'DKQ05';
    end if;
    return case tg_op when 'DELETE' then old else new end;
  end if;
  raise exception 'a decision or a conversion is never changed' using errcode = 'DKQ05';
end
$fn$;
revoke execute on function public.customer_quote_frozen() from public, anon, authenticated;
create trigger customer_quote_revisions_frozen before update or delete on public.customer_quote_revisions
  for each row execute function public.customer_quote_frozen();
create trigger customer_quotes_frozen before delete on public.customer_quotes
  for each row execute function public.customer_quote_frozen();
create trigger customer_quote_decisions_frozen before update or delete on public.customer_quote_decisions
  for each row execute function public.customer_quote_frozen();
create trigger customer_quote_conversions_frozen before update or delete on public.customer_quote_conversions
  for each row execute function public.customer_quote_frozen();

-- ── 5. helpers ───────────────────────────────────────────────────────────
-- The issuer of the business (the right to issue), never an assistant.
create or replace function public.customer_quote_actor(p_workspace uuid) returns public.members
language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if public.mcp_is_delegated() then
    raise exception 'quotes are made in the app, not by an assistant' using errcode = 'DKQ07';
  end if;
  return public.issuing_member(p_workspace);
end
$fn$;
revoke execute on function public.customer_quote_actor(uuid) from public, anon, authenticated;

-- One line as it is stored: the keys of #4165's standalone line, structurally checked
-- (the amounts are computed by the real issuer at send, never taken from a client).
-- Returns {line, missing}.
create or replace function public.customer_quote_line_clean(p_line jsonb, p_index integer)
returns jsonb language plpgsql stable set search_path = public as $fn$
declare
  v_missing text[] := '{}';
  v_pre text := 'line_' || p_index || '_';
  v_dec constant text := '^[0-9]{1,12}(\.[0-9]{1,6})?$';
  v_desc text := btrim(coalesce(p_line ->> 'description', ''));
  v_qty text := btrim(coalesce(p_line ->> 'quantity', ''));
  v_price text := btrim(coalesce(p_line ->> 'unit_price', ''));
  v_base text := btrim(coalesce(nullif(p_line ->> 'base_quantity', ''), '1'));
  v_basis text := coalesce(nullif(p_line ->> 'basis', ''), 'net');
  v_supply text := coalesce(p_line ->> 'supply', '');
  v_unit jsonb := coalesce(p_line -> 'unit', '{}'::jsonb);
  v_line_id uuid;
  v_rate uuid;
begin
  if p_line is null or jsonb_typeof(p_line) <> 'object' then
    return jsonb_build_object('line', null, 'missing', to_jsonb(array[v_pre || 'shape']));
  end if;
  if v_desc = '' or char_length(v_desc) > 300 then v_missing := v_missing || (v_pre || 'description'); end if;
  if v_qty !~ v_dec or v_qty::numeric <= 0 then v_missing := v_missing || (v_pre || 'quantity'); end if;
  if v_price !~ v_dec then v_missing := v_missing || (v_pre || 'unit_price'); end if;
  if v_base !~ v_dec or v_base::numeric <= 0 then v_missing := v_missing || (v_pre || 'base_quantity'); end if;
  if v_basis not in ('net', 'gross') then v_missing := v_missing || (v_pre || 'basis'); end if;
  if v_supply not in ('general', 'property') then v_missing := v_missing || (v_pre || 'supply'); end if;
  if btrim(coalesce(v_unit ->> 'code', '')) = '' or char_length(v_unit ->> 'code') > 20
     or btrim(coalesce(v_unit ->> 'label', '')) = '' or char_length(v_unit ->> 'label') > 20
     or (coalesce(v_unit ->> 'un_ece_code', '') <> '' and (v_unit ->> 'un_ece_code') !~ '^[A-Z0-9]{2,3}$') then
    v_missing := v_missing || (v_pre || 'unit');
  end if;
  begin v_line_id := coalesce((p_line ->> 'line_id')::uuid, gen_random_uuid());
  exception when others then v_line_id := null; v_missing := v_missing || (v_pre || 'line_id'); end;
  begin v_rate := nullif(p_line ->> 'vat_rate_id', '')::uuid;
  exception when others then v_missing := v_missing || (v_pre || 'vat_rate'); end;
  if cardinality(v_missing) > 0 then
    return jsonb_build_object('line', null, 'missing', to_jsonb(v_missing));
  end if;
  return jsonb_build_object('missing', '[]'::jsonb, 'line', jsonb_strip_nulls(jsonb_build_object(
    'line_id', v_line_id, 'description', v_desc, 'quantity', trim_scale(v_qty::numeric)::text,
    'unit_price', trim_scale(v_price::numeric)::text, 'base_quantity', trim_scale(v_base::numeric)::text,
    'basis', v_basis, 'supply', v_supply,
    'unit', jsonb_build_object('code', btrim(v_unit ->> 'code'), 'label', btrim(v_unit ->> 'label'),
                               'un_ece_code', coalesce(v_unit ->> 'un_ece_code', '')),
    'vat_rate_id', v_rate)));
end
$fn$;
revoke execute on function public.customer_quote_line_clean(jsonb, integer) from public, anon, authenticated;

create or replace function public.customer_quote_lines_clean(p_lines jsonb) returns jsonb
language plpgsql stable set search_path = public as $fn$
declare
  v_out jsonb := '[]'::jsonb;
  v_missing text[] := '{}';
  v_idx integer := 0;
  v_one jsonb;
  v_ids uuid[] := '{}';
begin
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' then
    raise exception 'a quote needs its lines' using errcode = 'DKQ06', detail = 'lines';
  end if;
  if jsonb_array_length(p_lines) = 0 then v_missing := v_missing || 'lines'; end if;
  if jsonb_array_length(p_lines) > 100 then v_missing := v_missing || 'lines_too_many'; end if;
  if cardinality(v_missing) = 0 then
    for v_one in select e from jsonb_array_elements(p_lines) e loop
      v_idx := v_idx + 1;
      v_one := public.customer_quote_line_clean(v_one, v_idx);
      if jsonb_array_length(v_one -> 'missing') > 0 then
        v_missing := v_missing || array(select jsonb_array_elements_text(v_one -> 'missing'));
      else
        if (v_one #>> '{line,line_id}')::uuid = any (v_ids) then
          v_missing := v_missing || ('line_' || v_idx || '_line_id');
        end if;
        v_ids := v_ids || (v_one #>> '{line,line_id}')::uuid;
        v_out := v_out || jsonb_build_array(v_one -> 'line');
      end if;
    end loop;
  end if;
  if cardinality(v_missing) > 0 then
    raise exception 'the quote is not complete' using errcode = 'DKQ06', detail = array_to_string(v_missing, ',');
  end if;
  return v_out;
end
$fn$;
revoke execute on function public.customer_quote_lines_clean(jsonb) from public, anon, authenticated;

-- What the real issuer would say of these lines on [p_on], rolled back: the lines it
-- computes, the totals, the tax facts, or what is missing. The same dry run the invoice
-- preview uses; it takes no number.
create or replace function public.customer_quote_dry_run(
  p_workspace uuid, p_actor public.members, p_subject uuid, p_lines jsonb, p_on date)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_draft public.standalone_invoice_drafts;
  v_id uuid;
  v_inv public.invoices;
  v_detail text;
begin
  v_draft := jsonb_populate_record(null::public.standalone_invoice_drafts, jsonb_build_object(
    'id', gen_random_uuid(), 'workspace_id', p_workspace, 'subject_member_id', p_subject,
    'revision', 1, 'status', 'draft', 'service_date', p_on,
    'due_on', greatest(p_on, current_date) + 30, 'buyer_reference', '', 'purchase_order', '',
    'lines', p_lines));
  begin
    v_id := public.standalone_invoice_issue_core(p_workspace, p_actor, v_draft);
    select * into v_inv from public.invoices where id = v_id;
    raise exception using message = 'dry run', errcode = 'DKI02', detail = jsonb_build_object(
      'lines', v_inv.lines, 'vat_totals', v_inv.vat_totals, 'total_cents', v_inv.total_cents,
      'currency', v_inv.currency)::text;
  exception
    when sqlstate 'DKI01' then
      get stacked diagnostics v_detail = pg_exception_detail;
      return jsonb_build_object('missing', to_jsonb(string_to_array(v_detail, ',')), 'result', null);
    when sqlstate 'DKI02' then
      get stacked diagnostics v_detail = pg_exception_detail;
      return jsonb_build_object('missing', '[]'::jsonb, 'result', v_detail::jsonb);
  end;
end
$fn$;
revoke execute on function public.customer_quote_dry_run(uuid, public.members, uuid, jsonb, date)
  from public, anon, authenticated;

create or replace function public.customer_quote_json(q public.customer_quotes) returns jsonb
language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
    'quote_id', q.id, 'subject_id', q.subject_member_id, 'reference', q.reference, 'status', q.status,
    -- derived, never stored: an unaccepted offer past its validity on the business clock
    'expired', q.status = 'sent' and not exists (
      select 1 from public.customer_quote_revisions r
       where r.quote_id = q.id and r.status = 'sent' and r.superseded_at is null
         and r.valid_until >= public.workspace_today(q.workspace_id)),
    'revisions', coalesce((select jsonb_agg(jsonb_build_object(
        'revision', r.revision, 'status', r.status, 'draft_version', r.draft_version,
        'issued_on', r.issued_on, 'valid_until', r.valid_until,
        'buyer_reference', r.buyer_reference, 'purchase_order', r.purchase_order, 'notes', r.notes,
        'lines', case when r.status = 'sent' then r.frozen -> 'lines' else r.lines end,
        'totals', case when r.status = 'sent' then r.frozen -> 'totals' else null end,
        'content_digest', r.content_digest, 'sent_at', r.sent_at, 'superseded', r.superseded_at is not null)
        order by r.revision)
      from public.customer_quote_revisions r where r.quote_id = q.id), '[]'::jsonb),
    'decision', (select jsonb_build_object(
        'decision', d.decision, 'revision', r.revision, 'decided_on', d.decided_on,
        'source', d.source, 'evidence', d.evidence, 'recorded_at', d.recorded_at,
        'recorded_by_issuer', true)
      from public.customer_quote_decisions d
      join public.customer_quote_revisions r on r.id = d.revision_id where d.quote_id = q.id),
    'conversion', (select jsonb_build_object('invoice_id', c.invoice_id, 'converted_at', c.converted_at)
      from public.customer_quote_conversions c where c.quote_id = q.id));
$fn$;
revoke execute on function public.customer_quote_json(public.customer_quotes) from public, anon, authenticated;

-- ── 6. the commands ──────────────────────────────────────────────────────
-- Create (p_quote_id null) or edit the working draft revision at its expected
-- version. Returns {quote_id, revision, version}.
create or replace function public.save_customer_quote_draft_v1(
  p_workspace_id uuid, p_quote_id uuid, p_expected_version integer, p_subject uuid,
  p_issued_on date, p_valid_until date, p_buyer_reference text, p_purchase_order text,
  p_notes text, p_lines jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_q public.customer_quotes;
  v_rev public.customer_quote_revisions;
  v_lines jsonb;
  v_on date;
  v_until date;
begin
  v_actor := public.customer_quote_actor(p_workspace_id);
  perform public.standalone_invoice_subject(p_workspace_id, p_subject);
  v_lines := public.customer_quote_lines_clean(p_lines);
  v_on := coalesce(p_issued_on, public.workspace_today(p_workspace_id));
  v_until := coalesce(p_valid_until, v_on + 30);
  if v_until < v_on or v_until > v_on + 365 then
    raise exception 'the validity is out of range' using errcode = 'DKQ06', detail = 'valid_until';
  end if;
  if p_quote_id is null then
    insert into public.customer_quotes (workspace_id, subject_member_id)
    values (p_workspace_id, p_subject) returning * into v_q;
    insert into public.customer_quote_revisions
      (quote_id, workspace_id, revision, issued_on, valid_until, buyer_reference, purchase_order, notes, lines)
    values (v_q.id, p_workspace_id, 1, v_on, v_until, coalesce(btrim(p_buyer_reference), ''),
            coalesce(btrim(p_purchase_order), ''), coalesce(btrim(p_notes), ''), v_lines)
    returning * into v_rev;
    -- the series exists before the first number, so the owner may set it first
    insert into public.number_sequences (workspace_id, journal, prefix, date_part, reset)
    select p_workspace_id, 'quote', d.prefix, d.date_part, d.reset
      from public.number_sequence_defaults('quote') d
    on conflict (workspace_id, journal) do nothing;
  else
    select * into v_q from public.customer_quotes
     where id = p_quote_id and workspace_id = p_workspace_id for update;
    if v_q.id is null then raise exception 'unknown quote' using errcode = 'DKQ01'; end if;
    if v_q.subject_member_id is distinct from p_subject then
      raise exception 'a quote keeps its customer' using errcode = 'DKQ03';
    end if;
    select * into v_rev from public.customer_quote_revisions r
     where r.quote_id = v_q.id and r.status = 'draft' order by r.revision desc limit 1 for update;
    if v_rev.id is null then
      raise exception 'no draft revision: amend the quote first' using errcode = 'DKQ03';
    end if;
    if v_rev.draft_version is distinct from p_expected_version then
      raise exception 'the draft changed since it was read' using errcode = 'DKQ02';
    end if;
    update public.customer_quote_revisions set
      issued_on = v_on, valid_until = v_until,
      buyer_reference = coalesce(btrim(p_buyer_reference), ''),
      purchase_order = coalesce(btrim(p_purchase_order), ''),
      notes = coalesce(btrim(p_notes), ''), lines = v_lines,
      draft_version = draft_version + 1
     where id = v_rev.id returning * into v_rev;
  end if;
  return jsonb_build_object('quote_id', v_q.id, 'revision', v_rev.revision, 'version', v_rev.draft_version);
end
$fn$;
revoke execute on function public.save_customer_quote_draft_v1(uuid, uuid, integer, uuid, date, date, text, text, text, jsonb)
  from public, anon;
grant execute on function public.save_customer_quote_draft_v1(uuid, uuid, integer, uuid, date, date, text, text, text, jsonb)
  to authenticated;

-- A new draft revision of a SENT quote, from the latest sent one: same lines and the
-- same line identities.
create or replace function public.amend_customer_quote_v1(p_workspace_id uuid, p_quote_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_q public.customer_quotes;
  v_last public.customer_quote_revisions;
  v_new public.customer_quote_revisions;
begin
  perform public.customer_quote_actor(p_workspace_id);
  select * into v_q from public.customer_quotes
   where id = p_quote_id and workspace_id = p_workspace_id for update;
  if v_q.id is null then raise exception 'unknown quote' using errcode = 'DKQ01'; end if;
  if v_q.status <> 'sent' then
    raise exception 'only a sent quote is amended' using errcode = 'DKQ03';
  end if;
  if exists (select 1 from public.customer_quote_revisions r where r.quote_id = v_q.id and r.status = 'draft') then
    raise exception 'an amendment is already open' using errcode = 'DKQ03';
  end if;
  select * into v_last from public.customer_quote_revisions r
   where r.quote_id = v_q.id order by r.revision desc limit 1;
  insert into public.customer_quote_revisions
    (quote_id, workspace_id, revision, issued_on, valid_until, buyer_reference, purchase_order, notes, lines)
  values (v_q.id, v_q.workspace_id, v_last.revision + 1,
          greatest(v_last.issued_on, public.workspace_today(v_q.workspace_id)),
          greatest(v_last.valid_until, public.workspace_today(v_q.workspace_id)),
          v_last.buyer_reference, v_last.purchase_order, v_last.notes, v_last.frozen -> 'lines_input')
  returning * into v_new;
  return jsonb_build_object('quote_id', v_q.id, 'revision', v_new.revision, 'version', v_new.draft_version);
end
$fn$;
revoke execute on function public.amend_customer_quote_v1(uuid, uuid) from public, anon;
grant execute on function public.amend_customer_quote_v1(uuid, uuid) to authenticated;

-- Send: freeze the working revision. The real issuer's dry run gives the totals; what
-- it says is missing refuses the send. The first send takes the quote's reference.
create or replace function public.send_customer_quote_v1(
  p_workspace_id uuid, p_quote_id uuid, p_revision integer, p_expected_version integer)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_q public.customer_quotes;
  v_rev public.customer_quote_revisions;
  v_dry jsonb;
  v_frozen jsonb;
begin
  v_actor := public.customer_quote_actor(p_workspace_id);
  select * into v_q from public.customer_quotes
   where id = p_quote_id and workspace_id = p_workspace_id for update;
  if v_q.id is null then raise exception 'unknown quote' using errcode = 'DKQ01'; end if;
  select * into v_rev from public.customer_quote_revisions r
   where r.quote_id = v_q.id and r.revision = p_revision for update;
  if v_rev.id is null then raise exception 'unknown revision' using errcode = 'DKQ01'; end if;
  if v_rev.status = 'sent' then
    -- sending again answers the same frozen revision, with no second reference
    return jsonb_build_object('quote_id', v_q.id, 'reference', v_q.reference,
                              'revision', v_rev.revision, 'replayed', true);
  end if;
  if v_q.status not in ('draft', 'sent') then
    raise exception 'this quote can no longer be sent' using errcode = 'DKQ03';
  end if;
  if v_rev.draft_version is distinct from p_expected_version then
    raise exception 'the draft changed since it was read' using errcode = 'DKQ02';
  end if;
  if v_rev.valid_until < public.workspace_today(p_workspace_id) then
    raise exception 'the offer is already past its validity' using errcode = 'DKQ04';
  end if;
  v_dry := public.customer_quote_dry_run(p_workspace_id, v_actor, v_q.subject_member_id,
                                         v_rev.lines, v_rev.issued_on);
  if jsonb_array_length(v_dry -> 'missing') > 0 then
    raise exception 'the quote is not complete' using errcode = 'DKQ06',
      detail = array_to_string(array(select jsonb_array_elements_text(v_dry -> 'missing')), ',');
  end if;
  if v_q.reference is null then
    update public.customer_quotes
       set reference = public.next_document_number(p_workspace_id, 'quote')
     where id = v_q.id returning * into v_q;
  end if;
  v_frozen := jsonb_build_object(
    'reference', v_q.reference, 'revision', v_rev.revision, 'subject_id', v_q.subject_member_id,
    'issued_on', v_rev.issued_on, 'valid_until', v_rev.valid_until,
    'buyer_reference', v_rev.buyer_reference, 'purchase_order', v_rev.purchase_order, 'notes', v_rev.notes,
    'lines_input', v_rev.lines,
    'lines', v_dry #> '{result,lines}',
    'totals', jsonb_build_object('total_cents', v_dry #> '{result,total_cents}',
                                 'currency', v_dry #> '{result,currency}',
                                 'vat_totals', v_dry #> '{result,vat_totals}'));
  update public.customer_quote_revisions r
     set superseded_at = now()
   where r.quote_id = v_q.id and r.status = 'sent' and r.superseded_at is null;
  update public.customer_quote_revisions set
    status = 'sent', frozen = v_frozen, sent_at = now(), sent_by_member_id = v_actor.id,
    content_digest = encode(sha256(convert_to(v_frozen::text, 'UTF8')), 'hex')
   where id = v_rev.id returning * into v_rev;
  update public.customer_quotes set status = 'sent' where id = v_q.id;
  return jsonb_build_object('quote_id', v_q.id, 'reference', v_q.reference,
                            'revision', v_rev.revision, 'digest', v_rev.content_digest, 'replayed', false);
end
$fn$;
revoke execute on function public.send_customer_quote_v1(uuid, uuid, integer, integer) from public, anon;
grant execute on function public.send_customer_quote_v1(uuid, uuid, integer, integer) to authenticated;

-- Record the customer's decision on one sent, current revision. The issuer records it
-- (the answer says so); the date the customer decided must lie inside the offer's validity.
create or replace function public.record_customer_quote_decision_v1(
  p_workspace_id uuid, p_quote_id uuid, p_revision integer, p_decision text,
  p_decided_on date, p_source text, p_evidence text)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_q public.customer_quotes;
  v_rev public.customer_quote_revisions;
  v_today date := public.workspace_today(p_workspace_id);
begin
  v_actor := public.customer_quote_actor(p_workspace_id);
  if p_decision not in ('accepted', 'declined') then
    raise exception 'unknown decision' using errcode = 'DKQ06', detail = 'decision';
  end if;
  select * into v_q from public.customer_quotes
   where id = p_quote_id and workspace_id = p_workspace_id for update;
  if v_q.id is null then raise exception 'unknown quote' using errcode = 'DKQ01'; end if;
  if v_q.status <> 'sent' then
    raise exception 'only a sent quote is decided' using errcode = 'DKQ03';
  end if;
  select * into v_rev from public.customer_quote_revisions r
   where r.quote_id = v_q.id and r.revision = p_revision;
  if v_rev.id is null or v_rev.status <> 'sent' or v_rev.superseded_at is not null then
    raise exception 'only the current sent revision is decided' using errcode = 'DKQ03';
  end if;
  if exists (select 1 from public.customer_quote_revisions r where r.quote_id = v_q.id and r.status = 'draft') then
    raise exception 'an amendment is open: discard it first' using errcode = 'DKQ03';
  end if;
  if p_decided_on is null or p_decided_on > v_today or p_decided_on < v_rev.issued_on then
    raise exception 'the date of the decision is out of range' using errcode = 'DKQ06', detail = 'decided_on';
  end if;
  if p_decision = 'accepted' and p_decided_on > v_rev.valid_until then
    raise exception 'the offer had expired on that date' using errcode = 'DKQ04';
  end if;
  insert into public.customer_quote_decisions
    (quote_id, workspace_id, revision_id, decision, decided_on, source, evidence, recorded_by_member_id)
  values (v_q.id, p_workspace_id, v_rev.id, p_decision, p_decided_on, p_source,
          coalesce(btrim(p_evidence), ''), v_actor.id);
  update public.customer_quotes set status = p_decision where id = v_q.id;
  return jsonb_build_object('quote_id', v_q.id, 'decision', p_decision, 'revision', v_rev.revision,
                            'recorded_by_issuer', true);
end
$fn$;
revoke execute on function public.record_customer_quote_decision_v1(uuid, uuid, integer, text, date, text, text)
  from public, anon;
grant execute on function public.record_customer_quote_decision_v1(uuid, uuid, integer, text, date, text, text)
  to authenticated;

-- Withdraw a sent, undecided quote. Nothing financial ever existed for it.
create or replace function public.cancel_customer_quote_v1(p_workspace_id uuid, p_quote_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare v_q public.customer_quotes;
begin
  perform public.customer_quote_actor(p_workspace_id);
  select * into v_q from public.customer_quotes
   where id = p_quote_id and workspace_id = p_workspace_id for update;
  if v_q.id is null then raise exception 'unknown quote' using errcode = 'DKQ01'; end if;
  if v_q.status <> 'sent' then
    raise exception 'only a sent quote is cancelled' using errcode = 'DKQ03';
  end if;
  update public.customer_quotes set status = 'cancelled' where id = v_q.id;
  return jsonb_build_object('quote_id', v_q.id, 'status', 'cancelled');
end
$fn$;
revoke execute on function public.cancel_customer_quote_v1(uuid, uuid) from public, anon;
grant execute on function public.cancel_customer_quote_v1(uuid, uuid) to authenticated;

-- Discard an unsent draft: a draft quote entirely, or the open amendment of a sent one.
create or replace function public.discard_customer_quote_draft_v1(p_workspace_id uuid, p_quote_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_q public.customer_quotes;
  v_rev public.customer_quote_revisions;
begin
  perform public.customer_quote_actor(p_workspace_id);
  select * into v_q from public.customer_quotes
   where id = p_quote_id and workspace_id = p_workspace_id for update;
  if v_q.id is null then raise exception 'unknown quote' using errcode = 'DKQ01'; end if;
  select * into v_rev from public.customer_quote_revisions r
   where r.quote_id = v_q.id and r.status = 'draft' order by r.revision desc limit 1;
  if v_rev.id is null then raise exception 'there is no draft to discard' using errcode = 'DKQ03'; end if;
  delete from public.customer_quote_revisions where id = v_rev.id;
  if v_q.status = 'draft' then delete from public.customer_quotes where id = v_q.id; end if;
  return jsonb_build_object('quote_id', v_q.id, 'discarded', true);
end
$fn$;
revoke execute on function public.discard_customer_quote_draft_v1(uuid, uuid) from public, anon;
grant execute on function public.discard_customer_quote_draft_v1(uuid, uuid) to authenticated;

-- ── 7. the conversion ────────────────────────────────────────────────────
-- Prepare: the invoice draft of an ACCEPTED quote (one per quote ever), from the
-- accepted revision's lines with the same line identities, for the service and due
-- dates the issuer states, and #4165's real preview of it. Nothing is issued.
create or replace function public.prepare_quote_conversion_v1(
  p_workspace_id uuid, p_quote_id uuid, p_service_date date, p_due_on date)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_q public.customer_quotes;
  v_rev public.customer_quote_revisions;
  v_draft public.standalone_invoice_drafts;
  v_preview jsonb;
begin
  perform public.customer_quote_actor(p_workspace_id);
  select * into v_q from public.customer_quotes
   where id = p_quote_id and workspace_id = p_workspace_id for update;
  if v_q.id is null then raise exception 'unknown quote' using errcode = 'DKQ01'; end if;
  if exists (select 1 from public.customer_quote_conversions c where c.quote_id = v_q.id) then
    raise exception 'this quote was already converted' using errcode = 'DKQ03';
  end if;
  if v_q.status <> 'accepted' then
    raise exception 'only an accepted quote is converted' using errcode = 'DKQ03';
  end if;
  select r.* into v_rev from public.customer_quote_decisions d
    join public.customer_quote_revisions r on r.id = d.revision_id where d.quote_id = v_q.id;
  select * into v_draft from public.standalone_invoice_drafts d
   where d.origin_quote_id = v_q.id and d.workspace_id = p_workspace_id for update;
  if v_draft.id is null then
    insert into public.standalone_invoice_drafts
      (workspace_id, subject_member_id, service_date, due_on, buyer_reference, purchase_order, lines, origin_quote_id)
    values (p_workspace_id, v_q.subject_member_id, p_service_date, p_due_on,
            v_rev.buyer_reference, v_rev.purchase_order, v_rev.lines, v_q.id)
    returning * into v_draft;
  else
    update public.standalone_invoice_drafts
       set service_date = p_service_date, due_on = p_due_on, revision = revision + 1
     where id = v_draft.id returning * into v_draft;
  end if;
  v_preview := public.preview_standalone_invoice_v1(p_workspace_id, v_draft.id, v_draft.revision);
  return jsonb_build_object(
    'draft_id', v_draft.id, 'draft_revision', v_draft.revision, 'quote_revision', v_rev.revision,
    'preview', v_preview,
    -- the authoritative difference between what was accepted and what would be issued now
    'accepted_total_cents', v_rev.frozen #>> '{totals,total_cents}',
    'context_changed', (v_preview #>> '{preview,total_cents}') is distinct from (v_rev.frozen #>> '{totals,total_cents}')
                       or (v_preview #> '{preview,vat_totals}') is distinct from (v_rev.frozen #> '{totals,vat_totals}'),
    'review_digest', encode(sha256(convert_to(coalesce((v_preview -> 'preview')::text, ''), 'UTF8')), 'hex'));
end
$fn$;
revoke execute on function public.prepare_quote_conversion_v1(uuid, uuid, date, date) from public, anon;
grant execute on function public.prepare_quote_conversion_v1(uuid, uuid, date, date) to authenticated;

-- Convert: issue the one initial invoice of an accepted quote. The quote row is the
-- lock, so two actors with different request ids meet here and the second gets the
-- first's invoice. A changed invoice context (total or tax facts differing from the
-- accepted ones) needs the reviewed digest of exactly what would be issued.
create or replace function public.convert_customer_quote_v1(
  p_workspace_id uuid, p_quote_id uuid, p_draft_revision integer, p_request_id uuid,
  p_reviewed_digest text default null)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_q public.customer_quotes;
  v_rev public.customer_quote_revisions;
  v_conv public.customer_quote_conversions;
  v_draft public.standalone_invoice_drafts;
  v_prep jsonb;
  v_res jsonb;
  v_inv public.invoices;
begin
  v_actor := public.customer_quote_actor(p_workspace_id);
  if p_request_id is null then
    raise exception 'a request identity is needed' using errcode = 'DKQ06', detail = 'request_id';
  end if;
  select * into v_q from public.customer_quotes
   where id = p_quote_id and workspace_id = p_workspace_id for update;
  if v_q.id is null then raise exception 'unknown quote' using errcode = 'DKQ01'; end if;
  select * into v_conv from public.customer_quote_conversions c where c.quote_id = v_q.id;
  if v_conv.quote_id is not null then
    select * into v_inv from public.invoices where id = v_conv.invoice_id;
    return jsonb_build_object('invoice_id', v_conv.invoice_id, 'number', v_inv.number, 'replayed', true);
  end if;
  if v_q.status <> 'accepted' then
    raise exception 'only an accepted quote is converted' using errcode = 'DKQ03';
  end if;
  select r.* into v_rev from public.customer_quote_decisions d
    join public.customer_quote_revisions r on r.id = d.revision_id where d.quote_id = v_q.id;
  select * into v_draft from public.standalone_invoice_drafts d
   where d.origin_quote_id = v_q.id and d.workspace_id = p_workspace_id for update;
  if v_draft.id is null then
    raise exception 'prepare the conversion first' using errcode = 'DKQ03';
  end if;
  if v_draft.revision is distinct from p_draft_revision then
    raise exception 'the invoice draft changed since it was previewed' using errcode = 'DKQ02';
  end if;
  v_prep := public.preview_standalone_invoice_v1(p_workspace_id, v_draft.id, v_draft.revision);
  if jsonb_array_length(v_prep -> 'missing') = 0
     and ((v_prep #>> '{preview,total_cents}') is distinct from (v_rev.frozen #>> '{totals,total_cents}')
          or (v_prep #> '{preview,vat_totals}') is distinct from (v_rev.frozen #> '{totals,vat_totals}'))
     and p_reviewed_digest is distinct from
         encode(sha256(convert_to(coalesce((v_prep -> 'preview')::text, ''), 'UTF8')), 'hex') then
    raise exception 'the invoice differs from what was accepted: review it first'
      using errcode = 'DKQ08',
            detail = encode(sha256(convert_to(coalesce((v_prep -> 'preview')::text, ''), 'UTF8')), 'hex');
  end if;
  v_res := public.issue_standalone_invoice_v1(p_workspace_id, v_draft.id, v_draft.revision, p_request_id);
  insert into public.customer_quote_conversions
    (quote_id, workspace_id, revision_id, draft_id, invoice_id, line_map, converted_by_member_id)
  values (v_q.id, p_workspace_id, v_rev.id, v_draft.id, (v_res ->> 'invoice_id')::uuid,
          (select coalesce(jsonb_agg(jsonb_build_object('line_id', l ->> 'line_id')), '[]'::jsonb)
             from jsonb_array_elements(v_rev.lines) l),
          v_actor.id);
  update public.customer_quotes set status = 'converted' where id = v_q.id;
  return v_res;
end
$fn$;
revoke execute on function public.convert_customer_quote_v1(uuid, uuid, integer, uuid, text) from public, anon;
grant execute on function public.convert_customer_quote_v1(uuid, uuid, integer, uuid, text) to authenticated;

-- ── 8. reading ───────────────────────────────────────────────────────────
create or replace function public.customer_quotes_v1(p_workspace_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
begin
  if not public.customer_quotes_readable(p_workspace_id) then
    raise exception 'reading quotes needs the right to issue or read finances' using errcode = 'DKN01';
  end if;
  return coalesce((select jsonb_agg(public.customer_quote_json(q) order by q.created_datetime desc, q.id)
                     from public.customer_quotes q where q.workspace_id = p_workspace_id), '[]'::jsonb);
end
$fn$;
revoke execute on function public.customer_quotes_v1(uuid) from public, anon;
grant execute on function public.customer_quotes_v1(uuid) to authenticated;

create or replace function public.customer_quote_v1(p_workspace_id uuid, p_quote_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare v_q public.customer_quotes;
begin
  if not public.customer_quotes_readable(p_workspace_id) then
    raise exception 'reading quotes needs the right to issue or read finances' using errcode = 'DKN01';
  end if;
  select * into v_q from public.customer_quotes q where q.id = p_quote_id and q.workspace_id = p_workspace_id;
  if v_q.id is null then raise exception 'unknown quote' using errcode = 'DKQ01'; end if;
  return public.customer_quote_json(v_q);
end
$fn$;
revoke execute on function public.customer_quote_v1(uuid, uuid) from public, anon;
grant execute on function public.customer_quote_v1(uuid, uuid) to authenticated;

-- ── 9. the workspace records export carries the quotes ───────────────────
-- (`export_workspace_records` restated whole, 0825's list plus the four quote tables;
-- read under `exportData`, as every table of that export is.)
create or replace function public.export_workspace_records(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_tables text[] := array[
    -- configuration, readable (the XML stays the re-importable copy)
    'sites', 'fee_bands', 'packages', 'credit_products', 'vat_rates',
    'accessories', 'seat_accessories', 'closure_days', 'validation_policies',
    'workspace_roles', 'workspace_role_members', 'workspace_field_definitions',
    'workspace_field_values', 'number_sequences', 'charging_stations',
    'plan_images', 'setting_values',
    -- member accounts
    'member_credits', 'member_credit_uses', 'price_negotiations',
    'quota_extensions', 'usage_records', 'invoice_matches', 'invoice_reminders',
    'invoice_dunning_holds', 'tax_exemption_certificates',
    -- purchases, premises, assets, books
    'suppliers', 'purchase_documents', 'purchase_lines', 'purchase_obligations',
    'outgoing_payments', 'expense_schedules', 'expense_occurrences',
    'expense_repartitions', 'premises_leases', 'lease_terms',
    'lease_settlements', 'room_rentals', 'room_rental_fees', 'workspace_assets',
    'asset_valuation_batches', 'asset_valuation_rows', 'book_profiles',
    'book_accounts', 'book_mappings', 'book_periods', 'vat_declarations',
    'einvoice_inbox',
    -- people the space is accountable to
    'guest_participations', 'rights_requests',
    -- #3307 the orders to the suppliers
    'purchase_orders', 'purchase_order_lines', 'purchase_order_sends',
    'purchase_order_receipts', 'purchase_order_receipt_lines',
    -- #3308 the passes the space sells and the passes it sold
    'guest_pass_offers', 'guest_passes',
    -- #3824 the goods ledger
    'item_units', 'item_codes', 'stock_locations', 'stock_lots', 'stock_movements',
    'stock_balances',
    -- #4164 the billing identity of each customer the business invoices
    'billing_parties',
    -- #4166 the customer quotes, their revisions, the decisions the issuer recorded and
    -- the conversions into invoices
    'customer_quotes', 'customer_quote_revisions', 'customer_quote_decisions',
    'customer_quote_conversions'];
  v_left_out text[] := public.system_column_names() || array['workspace_id', 'source_xml'];
  v_table text;
  v_columns text[];
  v_rows jsonb;
  v_out jsonb := '[]'::jsonb;
begin
  if auth.uid() is null or not public.has_permission(p_workspace_id, 'exportData') then
    raise exception 'only someone who may export this workspace''s data reads its records'
      using errcode = 'DKN01';
  end if;
  foreach v_table in array v_tables loop
    select array_agg(c.column_name::text order by c.ordinal_position) into v_columns
      from information_schema.columns c
     where c.table_schema = 'public' and c.table_name = v_table
       and c.column_name <> all (v_left_out);
    execute format(
      'select coalesce(jsonb_agg(jsonb_build_array(%s) order by created_datetime), ''[]''::jsonb)
         from public.%I where workspace_id = $1',
      (select string_agg(format('%I', c), ', ') from unnest(v_columns) c), v_table)
      into v_rows using p_workspace_id;
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'table', v_table, 'columns', to_jsonb(v_columns), 'rows', v_rows));
  end loop;
  return v_out;
end;
$fn$;
revoke execute on function public.export_workspace_records(uuid) from public, anon;
grant execute on function public.export_workspace_records(uuid) to authenticated;

select public.set_deskilo_schema_version(828);
