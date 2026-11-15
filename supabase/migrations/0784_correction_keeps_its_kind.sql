-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one anchored patch)
--
-- #3994 -- a correction is of the kind of the invoice it replaces. When
-- create_invoice replaces a subscription or a usage invoice, the new invoice
-- (or its credit note) takes that kind: sent without a kind or as 'full',
-- the replaced invoice's kind is taken; sent with another explicit kind, it
-- is refused (DKI08). The month's other invoice of another kind is then not
-- in its way. Replacing a full invoice, or issuing a new one, is as before.

do $migration$
declare
  v_def text := pg_get_functiondef('public.create_invoice(uuid,uuid,text,uuid,boolean,text,boolean,text,text,text)'::regprocedure);
  v_old text := $r$  if p_kind not in ('full', 'subscription', 'usage') then
    raise exception 'unknown invoice kind';
  end if;$r$;
begin
  if position('#3994' in v_def) > 0 then return; end if;
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception 'create_invoice no longer has the shape 0784 extends' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, $r$  -- #3994: a correction is of the kind of the invoice it replaces
  if p_replaces is not null then
    declare
      v_replaced_kind text := (select i.kind from public.invoices i
                                where i.id = p_replaces and i.workspace_id = p_workspace_id);
    begin
      if v_replaced_kind in ('subscription', 'usage') then
        if p_kind is null or p_kind = 'full' then
          p_kind := v_replaced_kind;
        elsif p_kind <> v_replaced_kind then
          raise exception 'a correction is of the kind of the invoice it replaces' using errcode = 'DKI08';
        end if;
      end if;
    end;
  end if;
  if p_kind not in ('full', 'subscription', 'usage') then
    raise exception 'unknown invoice kind';
  end if;$r$);
end
$migration$;

select public.set_deskilo_schema_version(784);
