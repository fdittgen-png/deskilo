-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4501 (audit FIN-09) -- an e-invoicing address is stored under a scheme of the list and with an identifier of that
-- scheme's form, whether it is the business's own (workspaces.invoice_legal, BT-34) or a customer's
-- (set_member_einvoice_address, BT-49). The list is the invoice model's (packages/deskilo_invoice_model eas_schemes.dart;
-- test/lint/eas_schemes_parity_test.dart keeps the two equal). An address stored before is kept as it is, even under a
-- scheme the list no longer offers, until it is changed; a new or changed one is refused with DKL02 and the reason
-- (`scheme` or `identifier`) as its detail. The customer's address takes the DK codes of 0919 for its other refusals.

-- The pattern a whole identifier of [p_scheme] matches, or null for a scheme not offered.
create or replace function public.einvoice_scheme_pattern(p_scheme text)
returns text
language sql immutable set search_path = public as $fn$
  select s.pattern from (values
    ('0002', '[0-9]{9}'),
    ('0007', '[0-9]{10}'),
    ('0009', '[0-9]{14}'),
    ('0060', '[0-9]{9}'),
    ('0088', '[0-9]{13}'),
    ('0106', '[0-9]{8}'),
    ('0151', '[0-9]{11}'),
    ('0183', 'CHE[0-9]{9}'),
    ('0190', '[0-9]{20}'),
    ('0192', '[0-9]{9}'),
    ('0201', '[A-Z0-9]{6}'),
    ('0204', '[0-9]{2,12}(-[A-Z0-9]{1,30})?-[0-9]{2}'),
    ('0208', '[01][0-9]{9}'),
    ('0210', '[A-Z0-9]{11}|[A-Z0-9]{16}'),
    ('0211', '[0-9]{11}'),
    ('0225', '[0-9]{9}(_[A-Za-z0-9_.+-]{1,100})?'),
    ('9915', 'ATU[0-9]{8}'),
    ('9920', 'ES[A-Z0-9][0-9]{7}[A-Z0-9]'),
    ('9925', 'BE[01][0-9]{9}'),
    ('9930', 'DE[0-9]{9}'),
    ('9944', 'NL[0-9]{9}B[0-9]{2}'),
    ('9957', 'FR[A-Z0-9]{2}[0-9]{9}'),
    ('EM', '[^@\s]+@[^@\s]+\.[^@\s]+')
  ) as s(code, pattern)
   where s.code = upper(btrim(coalesce(p_scheme, '')))
$fn$;

revoke execute on function public.einvoice_scheme_pattern(text) from public, anon, authenticated;

-- Why the address [p_scheme]:[p_id] cannot be stored where [p_stored_scheme]:[p_stored_id] is, or null when it can.
create or replace function public.einvoice_address_refusal(
  p_scheme text, p_id text, p_stored_scheme text, p_stored_id text
) returns text
language plpgsql immutable set search_path = public as $fn$
declare
  v_scheme text := upper(btrim(coalesce(p_scheme, '')));
  v_id text := btrim(coalesce(p_id, ''));
  v_pattern text;
begin
  if v_id = '' then return null; end if;
  if v_scheme = upper(btrim(coalesce(p_stored_scheme, ''))) and v_id = btrim(coalesce(p_stored_id, '')) then
    return null;
  end if;
  v_pattern := public.einvoice_scheme_pattern(v_scheme);
  if v_pattern is null then return 'scheme'; end if;
  if v_id !~ ('^(?:' || v_pattern || ')$') then return 'identifier'; end if;
  return null;
end
$fn$;

revoke execute on function public.einvoice_address_refusal(text, text, text, text) from public, anon, authenticated;

-- restates 0414: the customer's address is checked against the list
create or replace function public.set_member_einvoice_address(
  p_member_id uuid, p_endpoint_id text, p_endpoint_scheme text, p_subdivision text
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_target public.members;
  v_id text := btrim(coalesce(p_endpoint_id, ''));
  v_scheme text := upper(btrim(coalesce(p_endpoint_scheme, '')));
  v_county text := upper(btrim(coalesce(p_subdivision, '')));
  v_refusal text;
begin
  select * into v_target from public.members where id = p_member_id;
  if v_target.id is null then
    perform public.refuse('DKL02', '{"reason": "member"}'::jsonb, 'unknown member');
  end if;
  if auth.uid() is null
     or not public.has_permission(v_target.workspace_id, 'issueInvoices') then
    perform public.refuse('DKN01', null, 'not allowed to set the e-invoicing address');
  end if;
  if length(v_id) > 120 or length(v_scheme) > 10 or length(v_county) > 10 then
    perform public.refuse('DKL02', '{"reason": "length"}'::jsonb, 'e-invoicing address too long');
  end if;
  -- #4501 -- an address names a scheme of the list (none is one no network can resolve) and an identifier of its
  -- form; the stored address is kept as it is.
  v_refusal := public.einvoice_address_refusal(v_scheme, v_id,
    v_target.einvoice_endpoint_scheme, v_target.einvoice_endpoint_id);
  if v_refusal is not null then
    perform public.refuse('DKL02', jsonb_build_object('reason', v_refusal),
      'the e-invoicing address is not of a scheme of the list');
  end if;
  update public.members
     set einvoice_endpoint_id = v_id,
         einvoice_endpoint_scheme = case when v_id = '' then '' else v_scheme end,
         billing_subdivision = v_county
   where id = p_member_id;
end;
$$;

revoke execute on function public.set_member_einvoice_address(uuid, text, text, text) from public, anon;
grant execute on function public.set_member_einvoice_address(uuid, text, text, text) to authenticated;

-- The business's own address, in its legal identity.
create or replace function public.workspaces_einvoice_address()
returns trigger
language plpgsql security definer set search_path = public as $fn$
declare
  v_refusal text;
begin
  v_refusal := public.einvoice_address_refusal(
    new.invoice_legal ->> 'einvoice_endpoint_scheme', new.invoice_legal ->> 'einvoice_endpoint_id',
    case when tg_op = 'UPDATE' then old.invoice_legal ->> 'einvoice_endpoint_scheme' end,
    case when tg_op = 'UPDATE' then old.invoice_legal ->> 'einvoice_endpoint_id' end);
  if v_refusal is not null then
    perform public.refuse('DKL02', jsonb_build_object('reason', v_refusal),
      'the e-invoicing address is not of a scheme of the list');
  end if;
  return new;
end
$fn$;

revoke execute on function public.workspaces_einvoice_address() from public, anon, authenticated;

drop trigger if exists workspaces_einvoice_address on public.workspaces;
create trigger workspaces_einvoice_address
  before insert or update of invoice_legal on public.workspaces
  for each row execute function public.workspaces_einvoice_address();

select public.set_deskilo_schema_version(990);
