-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0259 (#1589) — payment terms answer only to the workspace that agreed
-- them.
--
-- `effective_payment_terms` is SECURITY DEFINER and asked nothing about
-- its caller. Any signed-in member could call it through PostgREST with
-- any member id and read that person's negotiated terms — the early
-- payment discount, the late penalty, the recovery indemnity — across
-- workspaces. Commercial terms of a space the caller has nothing to do
-- with.
--
-- Reproduced before writing this: a member of one workspace called it
-- with a member id from another and got a row back rather than a
-- refusal.
--
-- Half of the report was wrong and it is worth writing down which half.
-- It said `anon` could call it too, because no migration names this
-- function in a `revoke`. The live ACL is `authenticated` and
-- `service_role` only — a later blanket sweep took `anon` away without
-- naming the function, so grepping for the name found nothing while the
-- grant was already gone. The revoke below is restated anyway: the
-- reviewer of this file cannot see that sweep either, which is the same
-- reason 0191 gives.
--
-- The guard is `is_member_of`, not a permission. Cross-tenant is the
-- hole; whether every member of a workspace should read another
-- member's terms is a narrower question, and narrowing it here would
-- change what the invoice surfaces can render. It deserves its own
-- issue rather than a silent tightening inside a security fix.
--
-- `request_payment_terms_change` (0154) calls this internally and is
-- unaffected: it already requires an active member of that workspace
-- holding `paymentTermsEdit` before it reaches this line.

create or replace function public.effective_payment_terms(p_member_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_ws uuid;
  v_out jsonb;
begin
  select m.workspace_id into v_ws from public.members m where m.id = p_member_id;
  -- One sentence for "no such member" and for "not your workspace": a
  -- different answer for each would let a caller learn which ids exist.
  if v_ws is null or auth.uid() is null or not public.is_member_of(v_ws) then
    raise exception 'payment conditions belong to the workspace that agreed them';
  end if;
  select public.payment_terms_clean(w.invoice_legal)
         || coalesce(m.payment_terms, '{}'::jsonb)
         || jsonb_build_object('source',
              case when m.payment_terms is not null then 'member' else 'workspace' end)
    into v_out
    from public.members m join public.workspaces w on w.id = m.workspace_id
   where m.id = p_member_id;
  return v_out;
end $fn$;

revoke execute on function public.effective_payment_terms(uuid) from public, anon;
grant execute on function public.effective_payment_terms(uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(259);
