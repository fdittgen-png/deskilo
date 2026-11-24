-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (void_invoice restated whole; nothing else)
--
-- #4433 -- 0942 answered an unknown invoice with its own refusal (DKN01, reason invoice), so a caller could tell an
-- invoice that does not exist from one of another business (P0001 "not a member" from issuing_member). Both now meet the
-- same actor check, so the answer is the same. Everything else is 0942's void_invoice unchanged.

-- restates 0942
create or replace function public.void_invoice(p_invoice_id uuid)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_invoice public.invoices;
  v_actor public.members;
  v_actor_name text;
begin
  select * into v_invoice from public.invoices where id = p_invoice_id;
  if v_invoice.id is null then
    -- an unknown invoice is answered by the same actor check a foreign one meets, word for word and code for code:
    -- the answer never tells whether an invoice exists (314)
    v_actor := public.issuing_member(null);
  end if;
  v_actor := public.issuing_member(v_invoice.workspace_id);
  if exists (select 1 from public.invoice_matches
              where invoice_id = p_invoice_id) then
    raise exception 'invoice is matched' using errcode = 'DKI04';
  end if;
  if v_invoice.settled_by_invoice_id is not null then
    raise exception 'invoice is settled' using errcode = 'DKI04', detail = '{"reason": "settled"}';
  end if;
  if v_invoice.voided_at is not null then
    raise exception 'invoice already voided' using errcode = 'DKI03', detail = '{"reason": "voided"}';
  end if;
  select coalesce(display_name, '') into v_actor_name
    from public.profiles where id = v_actor.user_id;
  update public.invoices
     set voided_at = now(), voided_by_name = v_actor_name
   where id = p_invoice_id;
  if v_invoice.kind = 'settlement' then
    update public.invoices set settled_by_invoice_id = null
      where settled_by_invoice_id = p_invoice_id;
  end if;
  -- #4433: the goods it sold come back to the place they left
  perform public.invoice_goods_return(v_invoice.workspace_id, v_actor.id, p_invoice_id);
end;
$fn$;
revoke execute on function public.void_invoice(uuid) from public, anon;
grant execute on function public.void_invoice(uuid) to authenticated;

select public.set_deskilo_schema_version(950);
