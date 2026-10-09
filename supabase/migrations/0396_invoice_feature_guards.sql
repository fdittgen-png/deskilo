-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- #1917: disabling an invoice feature stops its issuing commands too.
-- Existing documents, previews, statements and payment commands are unchanged.
create or replace function public.invoice_issuing_enabled(p_workspace_id uuid, p_kind text)
returns boolean language sql stable set search_path = public as $fn$
  select public.feature_operation_allowed(p_workspace_id, 'invoicing', 'accept_new')
     and (p_kind <> 'subscription' or public.feature_operation_allowed(
            p_workspace_id, 'subscriptionInvoices', 'accept_new'))
     and (p_kind <> 'usage' or public.feature_operation_allowed(
            p_workspace_id, 'usageInvoices', 'accept_new'));
$fn$;
revoke execute on function public.invoice_issuing_enabled(uuid, text)
  from public, anon, authenticated;

do $patch$
declare v_def text; v_anchor text; v_guard text;
begin
  v_guard := $guard$
  if not public.invoice_issuing_enabled(p_workspace_id, p_kind) then
    raise exception 'invoice_essentials_missing'
      using errcode = 'DKI01', detail = 'invoice_feature_disabled';
  end if;
$guard$;
  -- Readiness dry-runs this same command and returns its DKI01 detail.
  select pg_get_functiondef('public.create_invoice(uuid,uuid,text,uuid,boolean,text,boolean,text,text)'::regprocedure)
    into v_def;
  v_anchor := $a$  select * into v_workspace from public.workspaces where id = p_workspace_id;$a$;
  if (length(v_def) - length(replace(v_def, v_anchor, ''))) / length(v_anchor) <> 1 then
    raise exception '0396: create_invoice anchor';
  end if;
  execute replace(v_def, v_anchor, v_guard || v_anchor);

  -- Refuse before creating an approval request, not after an approver acts.
  select pg_get_functiondef('public.request_invoice_issue(uuid,uuid,text,text,boolean,boolean,text,text)'::regprocedure)
    into v_def;
  v_anchor := $a$  if not public.has_permission(p_workspace_id, 'issueInvoices') then raise exception 'not allowed to issue invoices'; end if;$a$;
  if (length(v_def) - length(replace(v_def, v_anchor, ''))) / length(v_anchor) <> 1 then
    raise exception '0396: request_invoice_issue anchor';
  end if;
  execute replace(v_def, v_anchor, v_anchor || v_guard);
end;
$patch$;

select public.set_deskilo_schema_version(396);
