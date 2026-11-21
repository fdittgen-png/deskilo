-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (five anchored patches; no stored invoice, signature or setting moves)
--
-- #4262 + #4261 -- two guarantees of the invoice issuer.
--
-- #4262 -- every issuing command applies the invoice-approval policy. Only
-- `request_invoice_issue` did: `create_invoice` itself is callable by a
-- client, so the wizard's receipted issue, a replacement, the billing sweep, a
-- guest pass and a direct call issued what the policy sends for approval. The
-- guard now sits in `create_invoice`, after the total is known and before a
-- number is taken: an issue the policy requires approval for is refused
-- (`invoice_essentials_missing`, DKI01, detail `approval_required`) and consumes
-- no number. Two callers are exempt, because they are not the command: the
-- approval's own application (`apply_validated_decision_0181`, which sets
-- `deskilo.invoice_approved` around its call) and the two dry runs
-- (`invoice_issue_draft`, `invoice_issue_readiness`, which set
-- `deskilo.invoice_dry_run` inside the block they roll back, so the setting
-- is undone with it). `request_invoice_issue` still routes a policy-gated
-- issue to an approval event; the sweep skips a member it cannot issue.
--
-- #4261 -- an invoice's signature covers the address it stores. The signature
-- was computed over the business's address while the row stores the site's
-- address for an invoice of a site that is not the default one, so
-- `verify_invoice_signature` (which recomputes from the stored columns)
-- answered "altered" for an untouched site invoice. The monthly and the
-- standalone issuer now sign the address they store. Nothing else changes:
-- the verifier is as it was, so an invoice issued before keeps its verdict
-- (an old site invoice was signed over an address that is not stored and
-- cannot be re-derived).

do $patch$
declare
  v_def text;
  v_old text;
  -- the address the row stores, exactly as the insert writes it
  v_addr constant text := $a$case when v_site.id is not null and not v_site.is_default and (v_site.street <> '' or v_site.city <> '')
          then btrim(v_site.street || ', ' || v_site.postal_code || ' ' || v_site.city, ', ')
          else coalesce(v_workspace.address, '') end$a$;
begin
  -- create_invoice: the approval guard, then the signed address
  v_def := pg_get_functiondef('public.create_invoice(uuid,uuid,text,uuid,boolean,text,boolean,text,text,text)'::regprocedure);
  v_old := $a$  -- #1916 -- the essentials of a legal invoice, before a number is taken.$a$;
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception '0825: the essentials comment of create_invoice is not found exactly once' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, v_old, $b$  -- #4262 -- the invoice-approval policy applies to every issuing command: the
  -- approval's own application and the dry runs are the only callers that do not.
  if coalesce(current_setting('deskilo.invoice_approved', true), '') <> '1'
     and coalesce(current_setting('deskilo.invoice_dry_run', true), '') <> '1'
     and public.validation_requires(p_workspace_id, 'invoice_issue', v_total) then
    raise exception 'invoice_essentials_missing'
      using errcode = 'DKI01', detail = 'approval_required';
  end if;
$b$ || v_old);
  v_old := $a$      coalesce(v_workspace.address, ''), v_issuer_name,
      p_period, v_lines::text$a$;
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception '0825: the signed address of create_invoice is not found exactly once' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, '      ' || v_addr || E', v_issuer_name,\n      p_period, v_lines::text');

  -- the standalone issuer signs the address it stores
  v_def := pg_get_functiondef('public.standalone_invoice_issue_core(uuid,public.members,public.standalone_invoice_drafts)'::regprocedure);
  v_old := $a$      coalesce(v_ws.address, ''), v_issuer_name,$a$;
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception '0825: the signed address of the standalone issuer is not found exactly once' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, '      ' || replace(replace(v_addr, 'v_workspace.', 'v_ws.'), 'v_site.', 'v_site.') || ', v_issuer_name,');

  -- the approval's own application
  v_def := pg_get_functiondef('public.apply_validated_decision_0181()'::regprocedure);
  v_old := $a$      v_inv := public.create_invoice(new.workspace_id,$a$;
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception '0825: the create_invoice call of apply_validated_decision_0181 is not found exactly once' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, v_old, E'      perform set_config(''deskilo.invoice_approved'', ''1'', true);\n' || v_old);
  v_old := $a$      update public.events set payload = payload || jsonb_build_object('invoice_id', v_inv) where id = new.id;$a$;
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception '0825: the invoice_id update of apply_validated_decision_0181 is not found exactly once' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, E'      perform set_config(''deskilo.invoice_approved'', '''', true);\n' || v_old);

  -- the dry runs
  v_def := pg_get_functiondef('public.invoice_issue_draft(uuid,uuid,text,text,uuid,text)'::regprocedure);
  v_old := $a$    v_id := public.create_invoice($a$;
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception '0825: the create_invoice call of invoice_issue_draft is not found exactly once' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, E'    perform set_config(''deskilo.invoice_dry_run'', ''1'', true);\n' || v_old);
  v_def := pg_get_functiondef('public.invoice_issue_readiness(uuid,uuid,text,text,uuid,text)'::regprocedure);
  v_old := $a$    perform public.create_invoice($a$;
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception '0825: the create_invoice call of invoice_issue_readiness is not found exactly once' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, E'    perform set_config(''deskilo.invoice_dry_run'', ''1'', true);\n' || v_old);
end
$patch$;

select public.set_deskilo_schema_version(822);
