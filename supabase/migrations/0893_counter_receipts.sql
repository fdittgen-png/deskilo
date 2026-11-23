-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (three tables, one registry table with its rows, three settings, functions; the export function is restated whole)
--
-- #4184 (CS1, third file) -- the counter's contract: an immutable receipt of a sale at the counter, and the
-- evidenced readiness of every country operation it needs.
--
--   * `counter_receipts` (draft, then finalized) with its `counter_receipt_lines` and `counter_tenders`. A finalized
--     receipt is a frozen document: its number is drawn once from the `receipt` journal, its lines keep the
--     `commercial` v1 facts of the standalone invoice's lines, its currency, price basis, tax and total, the source
--     it was made from, the capability it was issued under; a correction is a NEW receipt that cites the original
--     (`corrects_receipt_id`). It is not an invoice kind, and no invoice is counted again for it. The same source
--     cannot generate a second initial finalized receipt under another request id (a unique index on the source).
--     A direct write is refused: the tables have no write grant, only the commands of 0894 and after write them.
--   * `counter_country_operations`: for each of FR, DE, IT and ES and each operation (issue a receipt, correct it,
--     reconcile a tender, sign and export a fiscal record), under each declared case (`counter.fiscal_obligation`:
--     none = the owner declares that no fiscal cash-register obligation applies, register_required = one does):
--     the authoritative specification, its version, its effective date, the adapter that implements it, the
--     evidence that proves it, supported or unavailable, and whether a tax professional confirmed the row (none
--     is confirmed). Nothing is inferred from the business kind, the country alone, a flag or a QR code.
--   * `counter_readiness_v1` answers, for the business, what is supported and what is not and why; a supported row
--     counts only while its adapter is implemented (`counter_adapters()`), so a registry row alone never opens an
--     operation. `counter_require_operation` is the gate every command calls BEFORE it draws a number or hands a
--     tender over: an unsupported operation is refused (DKT01) with nothing consumed.
--   * `counter_receipt_decode` is the versioned reader of a frozen receipt: version 1 is read, any other version is
--     refused (DKT09) rather than guessed, and a version-1 document read by a later reader keeps its keys.
--   * Three settings: the owner's fiscal declaration, how the document leaves the counter, and whether a sale may
--     name no customer. A sale with no customer never creates an account, a member or a subscription.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('counter.fiscal_obligation', 'enum', '"register_required"'::jsonb, null, null, '', 'business', array['workspace'], 'workspaceSettings', null, true, '["none","register_required"]'::jsonb, 'counter receipts (#4184)', 'What the owner declares about the fiscal rules for a sale at the counter: none = no fiscal cash-register obligation applies to this business (the owner''s own declaration, which the receipt records), register_required = one applies. The counter issues a receipt only where the country''s operation is supported under the declared case; the default is the cautious one.'),
('counter.document_channel', 'enum', '"share"'::jsonb, null, null, '', 'business', array['workspace'], 'workspaceSettings', null, true, '["share","print","both"]'::jsonb, 'counter receipts (#4184)', 'How the receipt document leaves the counter: shared (a message or a mail), printed, or both. The receipt itself is the same immutable document in every case.'),
('counter.customerless_sales', 'enum', '"allowed"'::jsonb, null, null, '', 'business', array['workspace'], 'workspaceSettings', null, true, '["allowed","refused"]'::jsonb, 'counter receipts (#4184)', 'Whether a sale may be made without naming a customer (allowed) or always names one (refused). A sale without a customer never creates an account, a member or a subscription.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- ── the registry of country operations (reference data, not a business's own) ──
create table public.counter_country_operations (
  id uuid primary key default gen_random_uuid(),
  country_code text not null check (country_code ~ '^[A-Z]{2}$'),
  operation text not null check (operation in ('issue_receipt', 'correct_receipt', 'reconcile_tender', 'sign_fiscal', 'export_fiscal')),
  regime text not null check (regime in ('none', 'register_required')),
  specification text not null check (btrim(specification) <> ''),
  specification_version text not null check (btrim(specification_version) <> ''),
  effective_from date not null,
  adapter text,
  evidence text not null check (btrim(evidence) <> ''),
  outcome text not null check (outcome in ('supported', 'unavailable')),
  reason text not null default '',
  confirmed boolean not null default false,
  check (outcome = 'unavailable' or adapter is not null),
  check (outcome = 'supported' or reason <> ''),
  unique (country_code, operation, regime)
);
select public.ensure_system_columns('counter_country_operations');
alter table public.counter_country_operations enable row level security;
revoke all on public.counter_country_operations from public, anon, authenticated;
grant select on public.counter_country_operations to authenticated;
create policy counter_country_operations_select on public.counter_country_operations for select to authenticated using (true);
create policy mcp_delegated_deny on public.counter_country_operations as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
comment on table public.counter_country_operations is
  'Reference data, written by migrations: what a counter receipt may do in each country, under which declared case, on which specification, with which adapter and evidence (#4184). A row says supported only for an operation an adapter implements and a test proves.';

insert into public.counter_country_operations
  (country_code, operation, regime, specification, specification_version, effective_from, adapter, evidence, outcome, reason, confirmed)
values
  ('FR', 'issue_receipt', 'none', 'Code général des impôts, annexe II, art. 242 nonies A (mentions des factures)', '2026-11', date '2013-01-01', 'counter_receipt_v1', 'pgTAP 520 (finalize, number once, frozen original) and 521 (totals in 0, 2 and 3 decimals)', 'supported', '', false),
  ('FR', 'correct_receipt', 'none', 'Code général des impôts, annexe II, art. 242 nonies A (mentions des factures)', '2026-11', date '2013-01-01', 'counter_receipt_v1', 'pgTAP 522 (a correction is a new receipt citing the original)', 'supported', '', false),
  ('FR', 'reconcile_tender', 'none', 'Code général des impôts, annexe II, art. 242 nonies A (mentions des factures)', '2026-11', date '2013-01-01', 'counter_receipt_v1', 'pgTAP 523 (tender states and reconciliation)', 'supported', '', false),
  ('FR', 'issue_receipt', 'register_required', 'Code général des impôts, art. 286 I 3° bis (logiciels et systèmes de caisse sécurisés, attestation NF 525)', 'loi de finances 2016, art. 88', date '2018-01-01', null, 'none: no adapter signs, certifies or exports a fiscal record', 'unavailable', 'A fiscal register obligation applies in this case and no fiscal adapter exists: nothing is numbered and no tender is taken.', false),
  ('FR', 'correct_receipt', 'register_required', 'Code général des impôts, art. 286 I 3° bis (logiciels et systèmes de caisse sécurisés, attestation NF 525)', 'loi de finances 2016, art. 88', date '2018-01-01', null, 'none: no adapter signs, certifies or exports a fiscal record', 'unavailable', 'A fiscal register obligation applies in this case and no fiscal adapter exists: nothing is numbered and no tender is taken.', false),
  ('FR', 'reconcile_tender', 'register_required', 'Code général des impôts, art. 286 I 3° bis (logiciels et systèmes de caisse sécurisés, attestation NF 525)', 'loi de finances 2016, art. 88', date '2018-01-01', null, 'none: no adapter signs, certifies or exports a fiscal record', 'unavailable', 'A fiscal register obligation applies in this case and no fiscal adapter exists: nothing is numbered and no tender is taken.', false),
  ('FR', 'sign_fiscal', 'register_required', 'Code général des impôts, art. 286 I 3° bis (logiciels et systèmes de caisse sécurisés, attestation NF 525)', 'loi de finances 2016, art. 88', date '2018-01-01', null, 'none: no adapter signs, certifies or exports a fiscal record', 'unavailable', 'A fiscal register obligation applies in this case and no fiscal adapter exists: nothing is numbered and no tender is taken.', false),
  ('FR', 'export_fiscal', 'register_required', 'Code général des impôts, art. 286 I 3° bis (logiciels et systèmes de caisse sécurisés, attestation NF 525)', 'loi de finances 2016, art. 88', date '2018-01-01', null, 'none: no adapter signs, certifies or exports a fiscal record', 'unavailable', 'A fiscal register obligation applies in this case and no fiscal adapter exists: nothing is numbered and no tender is taken.', false),
  ('DE', 'issue_receipt', 'none', 'Umsatzsteuer-Durchführungsverordnung, § 33 (Rechnungen über Kleinbeträge)', '2026-11', date '2017-01-01', 'counter_receipt_v1', 'pgTAP 520 (finalize, number once, frozen original) and 521 (totals in 0, 2 and 3 decimals)', 'supported', '', false),
  ('DE', 'correct_receipt', 'none', 'Umsatzsteuer-Durchführungsverordnung, § 33 (Rechnungen über Kleinbeträge)', '2026-11', date '2017-01-01', 'counter_receipt_v1', 'pgTAP 522 (a correction is a new receipt citing the original)', 'supported', '', false),
  ('DE', 'reconcile_tender', 'none', 'Umsatzsteuer-Durchführungsverordnung, § 33 (Rechnungen über Kleinbeträge)', '2026-11', date '2017-01-01', 'counter_receipt_v1', 'pgTAP 523 (tender states and reconciliation)', 'supported', '', false),
  ('DE', 'issue_receipt', 'register_required', 'Abgabenordnung, § 146a und Kassensicherungsverordnung (zertifizierte technische Sicherheitseinrichtung)', 'KassenSichV 2020', date '2020-01-01', null, 'none: no adapter signs, certifies or exports a fiscal record', 'unavailable', 'A fiscal register obligation applies in this case and no fiscal adapter exists: nothing is numbered and no tender is taken.', false),
  ('DE', 'correct_receipt', 'register_required', 'Abgabenordnung, § 146a und Kassensicherungsverordnung (zertifizierte technische Sicherheitseinrichtung)', 'KassenSichV 2020', date '2020-01-01', null, 'none: no adapter signs, certifies or exports a fiscal record', 'unavailable', 'A fiscal register obligation applies in this case and no fiscal adapter exists: nothing is numbered and no tender is taken.', false),
  ('DE', 'reconcile_tender', 'register_required', 'Abgabenordnung, § 146a und Kassensicherungsverordnung (zertifizierte technische Sicherheitseinrichtung)', 'KassenSichV 2020', date '2020-01-01', null, 'none: no adapter signs, certifies or exports a fiscal record', 'unavailable', 'A fiscal register obligation applies in this case and no fiscal adapter exists: nothing is numbered and no tender is taken.', false),
  ('DE', 'sign_fiscal', 'register_required', 'Abgabenordnung, § 146a und Kassensicherungsverordnung (zertifizierte technische Sicherheitseinrichtung)', 'KassenSichV 2020', date '2020-01-01', null, 'none: no adapter signs, certifies or exports a fiscal record', 'unavailable', 'A fiscal register obligation applies in this case and no fiscal adapter exists: nothing is numbered and no tender is taken.', false),
  ('DE', 'export_fiscal', 'register_required', 'Abgabenordnung, § 146a und Kassensicherungsverordnung (zertifizierte technische Sicherheitseinrichtung)', 'KassenSichV 2020', date '2020-01-01', null, 'none: no adapter signs, certifies or exports a fiscal record', 'unavailable', 'A fiscal register obligation applies in this case and no fiscal adapter exists: nothing is numbered and no tender is taken.', false),
  ('ES', 'issue_receipt', 'none', 'Real Decreto 1619/2012, art. 4 y 7 (factura simplificada)', '2026-11', date '2013-01-01', 'counter_receipt_v1', 'pgTAP 520 (finalize, number once, frozen original) and 521 (totals in 0, 2 and 3 decimals)', 'supported', '', false),
  ('ES', 'correct_receipt', 'none', 'Real Decreto 1619/2012, art. 4 y 7 (factura simplificada)', '2026-11', date '2013-01-01', 'counter_receipt_v1', 'pgTAP 522 (a correction is a new receipt citing the original)', 'supported', '', false),
  ('ES', 'reconcile_tender', 'none', 'Real Decreto 1619/2012, art. 4 y 7 (factura simplificada)', '2026-11', date '2013-01-01', 'counter_receipt_v1', 'pgTAP 523 (tender states and reconciliation)', 'supported', '', false),
  ('ES', 'issue_receipt', 'register_required', 'Real Decreto 1007/2023 (sistemas informáticos de facturación)', 'RD 1007/2023', date '2023-12-07', null, 'none: no adapter signs, certifies or exports a fiscal record', 'unavailable', 'A fiscal register obligation applies in this case and no fiscal adapter exists: nothing is numbered and no tender is taken.', false),
  ('ES', 'correct_receipt', 'register_required', 'Real Decreto 1007/2023 (sistemas informáticos de facturación)', 'RD 1007/2023', date '2023-12-07', null, 'none: no adapter signs, certifies or exports a fiscal record', 'unavailable', 'A fiscal register obligation applies in this case and no fiscal adapter exists: nothing is numbered and no tender is taken.', false),
  ('ES', 'reconcile_tender', 'register_required', 'Real Decreto 1007/2023 (sistemas informáticos de facturación)', 'RD 1007/2023', date '2023-12-07', null, 'none: no adapter signs, certifies or exports a fiscal record', 'unavailable', 'A fiscal register obligation applies in this case and no fiscal adapter exists: nothing is numbered and no tender is taken.', false),
  ('ES', 'sign_fiscal', 'register_required', 'Real Decreto 1007/2023 (sistemas informáticos de facturación)', 'RD 1007/2023', date '2023-12-07', null, 'none: no adapter signs, certifies or exports a fiscal record', 'unavailable', 'A fiscal register obligation applies in this case and no fiscal adapter exists: nothing is numbered and no tender is taken.', false),
  ('ES', 'export_fiscal', 'register_required', 'Real Decreto 1007/2023 (sistemas informáticos de facturación)', 'RD 1007/2023', date '2023-12-07', null, 'none: no adapter signs, certifies or exports a fiscal record', 'unavailable', 'A fiscal register obligation applies in this case and no fiscal adapter exists: nothing is numbered and no tender is taken.', false),
  ('IT', 'issue_receipt', 'none', 'Decreto legislativo 127/2015, art. 2 (memorizzazione e trasmissione telematica dei corrispettivi)', 'D.Lgs. 127/2015', date '2020-01-01', null, 'tests: pgTAP 519 (the registry says unavailable)', 'unavailable', 'The retail sale in Italy is recorded through the telematic transmission of the day''s takings; a receipt of this kind is not that, and no adapter transmits it.', false),
  ('IT', 'correct_receipt', 'none', 'Decreto legislativo 127/2015, art. 2 (memorizzazione e trasmissione telematica dei corrispettivi)', 'D.Lgs. 127/2015', date '2020-01-01', null, 'tests: pgTAP 519 (the registry says unavailable)', 'unavailable', 'The retail sale in Italy is recorded through the telematic transmission of the day''s takings; a receipt of this kind is not that, and no adapter transmits it.', false),
  ('IT', 'reconcile_tender', 'none', 'Decreto legislativo 127/2015, art. 2 (memorizzazione e trasmissione telematica dei corrispettivi)', 'D.Lgs. 127/2015', date '2020-01-01', null, 'tests: pgTAP 519 (the registry says unavailable)', 'unavailable', 'The retail sale in Italy is recorded through the telematic transmission of the day''s takings; a receipt of this kind is not that, and no adapter transmits it.', false),
  ('IT', 'issue_receipt', 'register_required', 'Decreto legislativo 127/2015, art. 2 (registratore telematico e documento commerciale)', 'D.Lgs. 127/2015', date '2020-01-01', null, 'none: no adapter signs, certifies or exports a fiscal record', 'unavailable', 'A fiscal register obligation applies in this case and no fiscal adapter exists: nothing is numbered and no tender is taken.', false),
  ('IT', 'correct_receipt', 'register_required', 'Decreto legislativo 127/2015, art. 2 (registratore telematico e documento commerciale)', 'D.Lgs. 127/2015', date '2020-01-01', null, 'none: no adapter signs, certifies or exports a fiscal record', 'unavailable', 'A fiscal register obligation applies in this case and no fiscal adapter exists: nothing is numbered and no tender is taken.', false),
  ('IT', 'reconcile_tender', 'register_required', 'Decreto legislativo 127/2015, art. 2 (registratore telematico e documento commerciale)', 'D.Lgs. 127/2015', date '2020-01-01', null, 'none: no adapter signs, certifies or exports a fiscal record', 'unavailable', 'A fiscal register obligation applies in this case and no fiscal adapter exists: nothing is numbered and no tender is taken.', false),
  ('IT', 'sign_fiscal', 'register_required', 'Decreto legislativo 127/2015, art. 2 (registratore telematico e documento commerciale)', 'D.Lgs. 127/2015', date '2020-01-01', null, 'none: no adapter signs, certifies or exports a fiscal record', 'unavailable', 'A fiscal register obligation applies in this case and no fiscal adapter exists: nothing is numbered and no tender is taken.', false),
  ('IT', 'export_fiscal', 'register_required', 'Decreto legislativo 127/2015, art. 2 (registratore telematico e documento commerciale)', 'D.Lgs. 127/2015', date '2020-01-01', null, 'none: no adapter signs, certifies or exports a fiscal record', 'unavailable', 'A fiscal register obligation applies in this case and no fiscal adapter exists: nothing is numbered and no tender is taken.', false);

-- the adapters that exist (a registry row alone never opens an operation); 0894 restates this with the producer
create or replace function public.counter_adapters()
returns text[] language sql immutable set search_path = public as $fn$
  select array[]::text[]
$fn$;
revoke execute on function public.counter_adapters() from public, anon, authenticated;

-- ── the receipts ─────────────────────────────────────────────────────
create table public.counter_receipts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  state text not null default 'draft' check (state in ('draft', 'finalized')),
  kind text not null default 'sale' check (kind in ('sale', 'correction')),
  revision int not null default 1 check (revision >= 1),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  price_basis text not null default 'gross' check (price_basis in ('gross', 'net')),
  financial_subject_id uuid,
  source_kind text not null default 'counter' check (source_kind ~ '^[a-z_]{1,32}$'),
  source_ref text not null default '' check (char_length(source_ref) <= 200),
  corrects_receipt_id uuid,
  number text,
  schema_version int not null default 1 check (schema_version >= 1),
  frozen jsonb,
  total_minor bigint check (total_minor is null or total_minor >= 0),
  tax_minor bigint check (tax_minor is null or tax_minor >= 0),
  operation_id uuid references public.counter_country_operations (id),
  fiscal_assumption text check (fiscal_assumption is null or fiscal_assumption in ('none', 'register_required')),
  created_by_member_id uuid,
  finalized_by_member_id uuid,
  finalized_at timestamptz,
  check ((state = 'finalized') = (number is not null and frozen is not null and finalized_at is not null and operation_id is not null)),
  check ((kind = 'correction') = (corrects_receipt_id is not null)),
  unique (workspace_id, id),
  foreign key (workspace_id, financial_subject_id) references public.members (workspace_id, id),
  foreign key (workspace_id, corrects_receipt_id) references public.counter_receipts (workspace_id, id),
  foreign key (workspace_id, created_by_member_id) references public.members (workspace_id, id),
  foreign key (workspace_id, finalized_by_member_id) references public.members (workspace_id, id)
);
select public.ensure_system_columns('counter_receipts');
create unique index counter_receipts_number on public.counter_receipts (workspace_id, number) where number is not null;
create unique index counter_receipts_source_once on public.counter_receipts (workspace_id, source_kind, source_ref)
  where state = 'finalized' and kind = 'sale' and source_ref <> '';
create index counter_receipts_corrected on public.counter_receipts (workspace_id, corrects_receipt_id) where corrects_receipt_id is not null;

create table public.counter_receipt_lines (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  receipt_id uuid not null,
  line_no int not null check (line_no >= 1),
  item_id uuid,
  variant_id uuid,
  quantity numeric not null check (quantity > 0),
  frozen jsonb not null,
  net_minor bigint not null check (net_minor >= 0),
  tax_minor bigint not null check (tax_minor >= 0),
  gross_minor bigint not null check (gross_minor >= 0),
  unique (receipt_id, line_no),
  unique (workspace_id, id),
  foreign key (workspace_id, receipt_id) references public.counter_receipts (workspace_id, id) on delete cascade,
  foreign key (workspace_id, item_id) references public.services (workspace_id, id),
  foreign key (workspace_id, variant_id) references public.item_variants (workspace_id, id)
);
select public.ensure_system_columns('counter_receipt_lines');

create table public.counter_tenders (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  receipt_id uuid not null,
  part int not null default 1 check (part >= 1),
  kind text not null check (kind in ('cash', 'card', 'other')),
  amount_minor bigint not null check (amount_minor > 0),
  state text not null default 'recorded' check (state in ('recorded', 'requested', 'unknown', 'accepted', 'refused')),
  provider_key text check (provider_key is null or char_length(provider_key) <= 200),
  request_id uuid,
  reconciliation text check (reconciliation is null or reconciliation in ('needed', 'done')),
  resolved_at timestamptz,
  recorded_by_member_id uuid,
  unique (receipt_id, part),
  unique (workspace_id, id),
  foreign key (workspace_id, receipt_id) references public.counter_receipts (workspace_id, id) on delete cascade,
  foreign key (workspace_id, recorded_by_member_id) references public.members (workspace_id, id)
);
select public.ensure_system_columns('counter_tenders');

-- a finalized receipt, its lines, and a tender's amount are never edited
create or replace function public.counter_frozen_guard()
returns trigger language plpgsql set search_path = public as $fn$
declare
  v_sys text[] := public.system_column_names();
  v_old jsonb;
  v_new jsonb;
  v_state text;
begin
  if tg_table_name = 'counter_receipts' then
    if tg_op = 'DELETE' then
      if old.state = 'finalized' then
        raise exception 'a finalized receipt is never deleted' using errcode = 'DKT03';
      end if;
      return old;
    end if;
    if old.state = 'finalized' then
      raise exception 'a finalized receipt is never edited: a correction is a new receipt' using errcode = 'DKT03';
    end if;
    return new;
  elsif tg_table_name = 'counter_receipt_lines' then
    select state into v_state from public.counter_receipts where id = coalesce(new.receipt_id, old.receipt_id);
    if v_state = 'finalized' then
      raise exception 'the lines of a finalized receipt are never edited' using errcode = 'DKT03';
    end if;
    return coalesce(new, old);
  else
    if tg_op = 'DELETE' then
      raise exception 'a tender is never deleted' using errcode = 'DKT03';
    end if;
    v_old := to_jsonb(old) - v_sys - array['state', 'provider_key', 'reconciliation', 'resolved_at'];
    v_new := to_jsonb(new) - v_sys - array['state', 'provider_key', 'reconciliation', 'resolved_at'];
    if v_old is distinct from v_new then
      raise exception 'what a tender is for and how much is never edited' using errcode = 'DKT03';
    end if;
    return new;
  end if;
end;
$fn$;
revoke execute on function public.counter_frozen_guard() from public, anon, authenticated;
create trigger counter_receipts_frozen before update or delete on public.counter_receipts
  for each row execute function public.counter_frozen_guard();
create trigger counter_receipt_lines_frozen before update or delete on public.counter_receipt_lines
  for each row execute function public.counter_frozen_guard();
create trigger counter_tenders_frozen before update or delete on public.counter_tenders
  for each row execute function public.counter_frozen_guard();

-- rights: read by those who issue invoices or see the finances, with the feature on; no direct write
alter table public.counter_receipts enable row level security;
alter table public.counter_receipt_lines enable row level security;
alter table public.counter_tenders enable row level security;
revoke all on public.counter_receipts, public.counter_receipt_lines, public.counter_tenders from public, anon, authenticated;
grant select on public.counter_receipts, public.counter_receipt_lines, public.counter_tenders to authenticated;
create policy counter_receipts_select on public.counter_receipts for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['issueInvoices', 'viewFinances']))
         and public.feature_effective(workspace_id, 'counterReceipts'));
create policy counter_receipt_lines_select on public.counter_receipt_lines for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['issueInvoices', 'viewFinances']))
         and public.feature_effective(workspace_id, 'counterReceipts'));
create policy counter_tenders_select on public.counter_tenders for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['issueInvoices', 'viewFinances']))
         and public.feature_effective(workspace_id, 'counterReceipts'));
create policy mcp_delegated_deny on public.counter_receipts as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.counter_receipt_lines as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.counter_tenders as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── readiness and the gate ─────────────────────────────────────────────
-- the registry row that governs an operation for a business: its country and its declared case
create or replace function public.counter_operation_row(p_workspace_id uuid, p_operation text)
returns public.counter_country_operations language plpgsql stable security definer set search_path = public as $fn$
declare
  v_country text;
  v_regime text;
  v_row public.counter_country_operations;
begin
  select w.country_code into v_country from public.workspaces w where w.id = p_workspace_id;
  v_regime := coalesce(public.setting_value(p_workspace_id, 'counter.fiscal_obligation') #>> '{}', 'register_required');
  select * into v_row from public.counter_country_operations o
   where o.country_code = v_country and o.operation = p_operation and o.regime = v_regime;
  return v_row;
end;
$fn$;
revoke execute on function public.counter_operation_row(uuid, text) from public, anon, authenticated;

create or replace function public.counter_require_operation(p_workspace_id uuid, p_operation text)
returns public.counter_country_operations language plpgsql stable security definer set search_path = public as $fn$
declare
  v_row public.counter_country_operations;
  v_country text;
  v_regime text;
  v_why text;
begin
  v_row := public.counter_operation_row(p_workspace_id, p_operation);
  select w.country_code into v_country from public.workspaces w where w.id = p_workspace_id;
  v_regime := coalesce(public.setting_value(p_workspace_id, 'counter.fiscal_obligation') #>> '{}', 'register_required');
  if v_row.id is null then
    v_why := 'no_row';
  elsif v_row.outcome <> 'supported' then
    v_why := 'unavailable';
  elsif not (v_row.adapter = any (public.counter_adapters())) then
    v_why := 'adapter_missing';
  end if;
  if v_why is not null then
    raise exception 'this operation is not supported here: %', p_operation using errcode = 'DKT01',
      detail = jsonb_build_object('operation', p_operation, 'country', v_country, 'fiscal_obligation', v_regime, 'reason', v_why)::text;
  end if;
  return v_row;
end;
$fn$;
revoke execute on function public.counter_require_operation(uuid, text) from public, anon, authenticated;

-- audience: all row readers
create or replace function public.counter_readiness_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_country text;
  v_regime text;
  v_ops jsonb := '[]'::jsonb;
  v_ready boolean := true;
  o public.counter_country_operations;
  v_eff text;
  v_why text;
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not (public.has_permission(p_workspace_id, 'issueInvoices') or public.has_permission(p_workspace_id, 'viewFinances')) then
    raise exception 'not allowed to read the counter readiness' using errcode = 'DKN01';
  end if;
  if not public.feature_effective(p_workspace_id, 'counterReceipts') then
    raise exception 'counter receipts are off in this business' using errcode = 'DKG01';
  end if;
  select w.country_code into v_country from public.workspaces w where w.id = p_workspace_id;
  v_regime := coalesce(public.setting_value(p_workspace_id, 'counter.fiscal_obligation') #>> '{}', 'register_required');
  for o in select * from public.counter_country_operations x
            where x.country_code = v_country and x.regime = v_regime
            order by array_position(array['issue_receipt', 'correct_receipt', 'reconcile_tender', 'sign_fiscal', 'export_fiscal'], x.operation) loop
    v_eff := case when o.outcome = 'supported' and o.adapter = any (public.counter_adapters()) then 'supported' else 'unavailable' end;
    v_why := case when o.outcome <> 'supported' then 'unavailable' when v_eff = 'unavailable' then 'adapter_missing' else '' end;
    v_ops := v_ops || jsonb_build_array(jsonb_build_object(
      'operation', o.operation, 'outcome', v_eff, 'registry_outcome', o.outcome, 'reason', v_why, 'note', o.reason,
      'specification', o.specification, 'specification_version', o.specification_version, 'effective_from', o.effective_from,
      'adapter', o.adapter, 'confirmed', o.confirmed));
    if o.operation in ('issue_receipt', 'reconcile_tender') and v_eff <> 'supported' then
      v_ready := false;
    end if;
  end loop;
  if jsonb_array_length(v_ops) = 0 then
    v_ready := false;
  end if;
  return jsonb_build_object('country', v_country, 'fiscal_obligation', v_regime, 'ready', v_ready, 'operations', v_ops);
end;
$fn$;
revoke execute on function public.counter_readiness_v1(uuid) from public, anon;
grant execute on function public.counter_readiness_v1(uuid) to authenticated;

-- ── the versioned reader of a frozen receipt ───────────────────────────
create or replace function public.counter_receipt_decode(p_frozen jsonb)
returns jsonb language plpgsql immutable set search_path = public as $fn$
declare
  v_version int;
begin
  if coalesce(jsonb_typeof(p_frozen), '') <> 'object' or coalesce(p_frozen ->> 'version', '') !~ '^[0-9]{1,4}$' then
    raise exception 'not a receipt this reader knows' using errcode = 'DKT09';
  end if;
  v_version := (p_frozen ->> 'version')::int;
  if v_version <> 1 then
    raise exception 'a receipt of version % is not read by this reader', v_version using errcode = 'DKT09';
  end if;
  if coalesce(jsonb_typeof(p_frozen -> 'lines'), '') <> 'array' or coalesce(jsonb_typeof(p_frozen -> 'totals'), '') <> 'object'
     or coalesce(p_frozen ->> 'currency', '') !~ '^[A-Z]{3}$' then
    raise exception 'a receipt of version 1 is incomplete' using errcode = 'DKT09';
  end if;
  -- only the keys version 1 defines are read: a later writer's added keys are ignored, never guessed
  return jsonb_build_object(
    'version', 1,
    'number', p_frozen -> 'number',
    'currency', p_frozen -> 'currency',
    'price_basis', p_frozen -> 'price_basis',
    'lines', p_frozen -> 'lines',
    'totals', p_frozen -> 'totals',
    'tax_breakdown', coalesce(p_frozen -> 'tax_breakdown', '[]'::jsonb),
    'source', p_frozen -> 'source',
    'operation', p_frozen -> 'operation',
    'corrects', p_frozen -> 'corrects');
end;
$fn$;
revoke execute on function public.counter_receipt_decode(jsonb) from public, anon, authenticated;

-- the workspace export carries the receipts, their lines and their tenders (#2860)
-- restates 0886
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
    -- #4362 the tags bound to items, places and pieces, and the named pieces
    'stock_tags', 'stock_tagged_units',
    -- #4184 the counter's receipts, their lines and their tenders
    'counter_receipts', 'counter_receipt_lines', 'counter_tenders',
    -- #4164 the billing identity of each customer the business invoices
    'billing_parties',
    -- #4166 the customer quotes, their revisions, the decisions the issuer recorded and
    -- the conversions into invoices
    'customer_quotes', 'customer_quote_revisions', 'customer_quote_decisions',
    'customer_quote_conversions',
    -- #4169 the variants and the supplier's article
    'item_dimensions', 'item_dimension_values', 'item_variants', 'item_variant_values',
    'supplier_item_mappings',
    -- #4171 what was put away from a delivery
    'stock_receipt_allocations',
    -- #4170 the transfers between sites and what each loaded
    'stock_transfers', 'stock_transfer_lines',
    -- #4294 the reorder points
    'stock_reorder_points', 'item_groups', 'item_group_history',
    -- #4172 the returns, and what each line reversed
    'stock_returns', 'stock_reversals',
    -- #4172 the counts and their decisions
    'stock_counts',
    -- #4295 the plans, the tasks and their lines
    'stock_count_plans', 'stock_count_tasks', 'stock_count_task_lines',
    -- #4178 the engagements of the services ordered, their steps and the invoice
    -- lines that billed a direct commitment
    'service_fulfilments', 'service_fulfilment_transitions', 'service_fulfilment_invoice_links'];
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

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(893);
