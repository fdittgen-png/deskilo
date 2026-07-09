-- DesKilo #154 — payment method on recorded payments (spec §7: a payment
-- event = amount + date + METHOD + note; the method was missing from the
-- 0008 RPC). A defaulted extra parameter would CREATE AN OVERLOAD next to
-- the 4-arg function, so the old signature is dropped first; old clients
-- that still call with 4 args keep working through the new default.

drop function if exists public.record_payment(uuid, uuid, int, text);

create or replace function public.record_payment(
  p_workspace_id uuid,
  p_member_id uuid,
  p_amount_cents int,
  p_note text default '',
  p_method text default ''
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_event_id uuid;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_actor.id is null then raise exception 'not an active member'; end if;
  if p_amount_cents <= 0 then raise exception 'amount must be positive'; end if;
  if v_actor.id <> p_member_id and not (v_actor.is_admin or v_actor.is_owner) then
    raise exception 'only admins record payments for others';
  end if;
  -- Free-form-but-bounded method tag; the app sends one of the
  -- PaymentMethod enum wire names ('' = not specified, old clients).
  if length(p_method) > 32 then raise exception 'method too long'; end if;
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (
    p_workspace_id, 'payment', 'submitted', v_actor.id, p_member_id,
    jsonb_build_object(
      'amount_cents', p_amount_cents,
      'note', p_note,
      'method', p_method
    ),
    'pending'
  ) returning id into v_event_id;
  return v_event_id;
end;
$$;

-- Same hardening as 0004/0008: only signed-in members may call it.
revoke execute on function public.record_payment(uuid, uuid, int, text, text)
  from public, anon;
