-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- #2941 — authorization reads only the confirmed account e-mail; an
-- invoice's signature state answers only who may read the invoice.
--
-- 0199 matched `workspace_template_grants.grantee_email` against either
-- `auth.email()` or `profiles.email`. The profile column is the caller's
-- own to edit (`profiles_update` is `id = auth.uid()`), so anyone signed
-- in could type a grantee's address into their profile and read — and
-- apply — that grantee's privately shared configuration: prices, plans,
-- floor plan and wording. Reproduced on dev, rolled back, before this
-- file was written.
--
-- `auth.email()` goes too: it is a JWT claim, and a claim can carry an
-- address nobody has confirmed. What remains is the one e-mail the
-- account has proved it receives: `auth.users.email` with
-- `email_confirmed_at` set, read inside the definer. That is the rule
-- every other e-mail match in the authorization paths already follows
-- (`instance_responsibles`, `join_workspace`).
--
-- Same signature, language, volatility, definer and search_path, so
-- `workspace_template_readable` and every RPC that asks it keep calling
-- the one predicate.
create or replace function public.holds_template_grant(p_template_id uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1
      from public.workspace_template_grants g
     where g.template_id = p_template_id
       and g.grantee_email <> ''
       and g.grantee_email = (
             select lower(u.email)
               from auth.users u
              where u.id = auth.uid()
                and u.email_confirmed_at is not null
           )
  );
$fn$;
revoke execute on function public.holds_template_grant(uuid) from public, anon;

-- The grant rows themselves (0199's `workspace_template_grants_read`)
-- were matched the same way, so an edited profile e-mail also showed the
-- grant naming that address. A policy cannot read `auth.users`; this
-- definer hands it the caller's confirmed address and nothing else, and
-- NULL when there is none (NULL equals no grantee).
create or replace function public.confirmed_account_email()
returns text language sql stable security definer set search_path = public as $fn$
  select lower(u.email)
    from auth.users u
   where u.id = auth.uid()
     and u.email_confirmed_at is not null
     and coalesce(u.email, '') <> '';
$fn$;
revoke execute on function public.confirmed_account_email() from public, anon;

-- Still visible to the person it names and to the template's owner,
-- never to the other people invited to the same template.
drop policy if exists workspace_template_grants_read
  on public.workspace_template_grants;
create policy workspace_template_grants_read
  on public.workspace_template_grants
  for select to authenticated
  using (
    grantee_email = public.confirmed_account_email()
    or public.owns_workspace_template(template_id)
  );

-- The owner rule (0166): an owner must have an e-mail address. It too
-- accepted `profiles.email`, so typing any address into one's own
-- profile satisfied it. Only the confirmed account e-mail counts now.
-- Still a guard's helper: callable by neither clients nor `anon`.
create or replace function public.user_has_email(p_user_id uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1 from auth.users u
     where u.id = p_user_id
       and coalesce(u.email, '') <> ''
       and u.email_confirmed_at is not null
  );
$fn$;
revoke execute on function public.user_has_email(uuid) from public, anon, authenticated;

-- An invoice's signature state (0174) was answered to any member of the
-- invoice's workspace, so a colleague learned that an invoice id exists
-- and whether it verifies; and 'unknown invoice' against 'not a member'
-- told anyone whether an id exists in another workspace. It now asks
-- the invoice's own read rule (`may_view_invoice`: the recipient, or
-- viewFinances / issueInvoices in that workspace), and an invoice the
-- caller may not read is answered exactly like one that does not exist.
create or replace function public.verify_invoice_signature(p_invoice_id uuid) returns text
language plpgsql stable security definer set search_path = public as $fn$
declare v public.invoices; v_sig text;
begin
  select * into v from public.invoices where id = p_invoice_id;
  if v.id is null or not public.may_view_invoice(p_invoice_id) then
    raise exception 'unknown invoice';
  end if;
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
$fn$;
revoke execute on function public.verify_invoice_signature(uuid) from public, anon;
grant execute on function public.verify_invoice_signature(uuid) to authenticated;

select public.set_deskilo_schema_version(560);
