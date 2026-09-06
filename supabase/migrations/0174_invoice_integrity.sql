-- SPDX-License-Identifier: 0BSD
-- 0174 — #956: verify an invoice's fingerprint on demand.
--
-- create_invoice has signed every document since 0060 (SHA-256 over the
-- frozen columns) and the invoices_no_mutation trigger refuses any edit
-- of a signed row; nothing ever CHECKED the fingerprint. Now every new
-- document is stamped with the formula that signed it (signature_algo
-- 7, the concatenation of 0142 onwards) and verify_invoice_signature
-- recomputes it from the stored columns:
--
--   verified      the fingerprint matches;
--   altered       a stamped row that no longer matches — the only case
--                 that means what an auditor fears;
--   unverifiable  a row signed before the stamp whose fingerprint no
--                 longer matches. Migrations up to 0152 rewrote signed
--                 columns of existing rows (every pilot invoice issued
--                 before 2026-09-04 is in that case); the verifier must
--                 not call that an alteration nobody made.
alter table public.invoices add column if not exists signature_algo int;

do $patch$
declare v_def text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_invoice' and p.prokind='f';
  v_old := E'     kind)\n  values\n    (v_id,';
  if position(v_old in v_def) = 0 then raise exception '0174: anchor A missing'; end if;
  v_def := replace(v_def, v_old, E'     kind, signature_algo)\n  values\n    (v_id,');
  v_old := E'     p_kind);\n  return v_id;';
  if position(v_old in v_def) = 0 then raise exception '0174: anchor B missing'; end if;
  v_def := replace(v_def, v_old, E'     p_kind, 7);\n  return v_id;');
  execute v_def;
end
$patch$;

create or replace function public.verify_invoice_signature(p_invoice_id uuid) returns text
language plpgsql stable security definer set search_path = public as $$
declare v public.invoices; v_sig text;
begin
  select * into v from public.invoices where id = p_invoice_id;
  if v.id is null then raise exception 'unknown invoice'; end if;
  if not public.is_member_of(v.workspace_id) then raise exception 'not a member'; end if;
  v_sig := encode(extensions.digest(convert_to(concat_ws('|',
      v.id::text, v.number, v.workspace_id::text, v.member_id::text,
      v.member_name, v.member_address, v.workspace_name,
      coalesce(v.workspace_address, ''), v.issuer_name,
      v.period, v.lines::text, v.total_cents::text, v.currency,
      v.issued_at::date::text, coalesce(v.replaces_invoice_id::text, ''),
      coalesce(v.replaces_number, ''), coalesce(v.details::text, ''),
      v.parties::text, v.vat_totals::text, v.kind),
      'UTF8'), 'sha256'), 'hex');
  if v_sig = v.signature then return 'verified'; end if;
  if v.signature_algo is null then return 'unverifiable'; end if;
  return 'altered';
end;
$$;
grant execute on function public.verify_invoice_signature(uuid) to authenticated;
