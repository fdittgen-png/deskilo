-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (four function bodies are patched in place; no row and no table moves)
--
-- 0617 (#3095, SEC-D2 of the #2960 audit) -- the actor is checked BEFORE the
-- state of the thing it acts on.
--
-- `void_invoice`, `record_invoice_reminder` and `settle_credit_invoice` told
-- any signed-in caller whether an invoice of ANOTHER workspace existed and in
-- which state ("invoice is settled", "invoice is voided", "not a credit
-- note") before `issuing_member(...)` was asked. `add_conversation_participant`
-- did the same before `is_conversation_admin`. Now the caller's right comes
-- first, and an unknown id is refused with the very text a non-member gets:
-- one answer whatever the row is and whatever state it is in.
--
-- `set_room_rental_fees_v1` took role, plan and member ids of ANOTHER
-- workspace without a look (an existence oracle; the cascade of those rows
-- could then delete a fee of another tenant). It now holds the same per-entry
-- check `set_room_rental_audience_v1` has.
--
-- Anchored patches: the hosted body and the replayed body wrap lines
-- differently, so every anchor goes through the whitespace-tolerant replace.

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public, anon;

do $migration$
declare
  v_def text;
begin
  -- void_invoice: the actor, then the state.
  select pg_get_functiondef('public.void_invoice(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$  if v_invoice.id is null then raise exception 'unknown invoice'; end if;
  if exists (select 1 from public.invoice_matches$a$,
    $a$  if v_invoice.id is null then raise exception 'not a member'; end if;
  v_actor := public.issuing_member(v_invoice.workspace_id);
  if exists (select 1 from public.invoice_matches$a$);
  v_def := pg_temp.anchor_replace(v_def,
    $a$  v_actor := public.issuing_member(v_invoice.workspace_id);
  if v_invoice.voided_at is not null then$a$,
    $a$  if v_invoice.voided_at is not null then$a$);
  if v_def is null
     or position($a$raise exception 'not a member'$a$ in v_def) = 0
     or position('unknown invoice' in v_def) > 0 then
    raise exception '0617: void_invoice anchor missing';
  end if;
  execute v_def;

  -- record_invoice_reminder
  select pg_get_functiondef('public.record_invoice_reminder(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$  if v_invoice.id is null then raise exception 'unknown invoice'; end if;
  if v_invoice.voided_at is not null then$a$,
    $a$  if v_invoice.id is null then raise exception 'not a member'; end if;
  v_actor := public.issuing_member(v_invoice.workspace_id);
  if v_invoice.voided_at is not null then$a$);
  v_def := pg_temp.anchor_replace(v_def,
    $a$  v_actor := public.issuing_member(v_invoice.workspace_id);
  select coalesce(display_name, '') into v_actor_name$a$,
    $a$  select coalesce(display_name, '') into v_actor_name$a$);
  if v_def is null
     or position($a$raise exception 'not a member'$a$ in v_def) = 0
     or position('unknown invoice' in v_def) > 0 then
    raise exception '0617: record_invoice_reminder anchor missing';
  end if;
  execute v_def;

  -- settle_credit_invoice
  select pg_get_functiondef('public.settle_credit_invoice(uuid,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$  if v_invoice.id is null then raise exception 'unknown invoice'; end if;
  if v_invoice.voided_at is not null then$a$,
    $a$  if v_invoice.id is null then raise exception 'not a member'; end if;
  v_actor := public.issuing_member(v_invoice.workspace_id);
  if v_invoice.voided_at is not null then$a$);
  v_def := pg_temp.anchor_replace(v_def,
    $a$  v_actor := public.issuing_member(v_invoice.workspace_id);

  v_amount := -v_invoice.total_cents;$a$,
    $a$  v_amount := -v_invoice.total_cents;$a$);
  if v_def is null
     or position($a$raise exception 'not a member'$a$ in v_def) = 0
     or position('unknown invoice' in v_def) > 0 then
    raise exception '0617: settle_credit_invoice anchor missing';
  end if;
  execute v_def;

  -- add_conversation_participant: not-an-admin comes first, and an unknown
  -- conversation reads like a conversation the caller does not administer.
  select pg_get_functiondef('public.add_conversation_participant(uuid,uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$  if v_conversation.id is null then raise exception 'no such conversation'; end if;
  if v_conversation.kind <> 'group' then
    raise exception 'a direct thread has exactly two people';
  end if;
  if not public.is_conversation_admin(p_conversation_id) then
    raise exception 'only a group admin can add people';
  end if;$a$,
    $a$  if v_conversation.id is null
     or not public.is_conversation_admin(p_conversation_id) then
    raise exception 'only a group admin can add people';
  end if;
  if v_conversation.kind <> 'group' then
    raise exception 'a direct thread has exactly two people';
  end if;$a$);
  if v_def is null or position('no such conversation' in v_def) > 0 then
    raise exception '0617: add_conversation_participant anchor missing';
  end if;
  execute v_def;

  -- set_room_rental_fees_v1: an entry names only things of this space.
  select pg_get_functiondef('public.set_room_rental_fees_v1(uuid,uuid,jsonb)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$    insert into public.room_rental_fees (workspace_id, rental_id, unit, fee_cents, role_id, plan_id, member_id)$a$,
    $a$    if (e->>'role_id') is not null and not exists (select 1 from public.workspace_roles x where x.id = (e->>'role_id')::uuid and x.workspace_id = p_workspace_id)
       or (e->>'plan_id') is not null and not exists (select 1 from public.plans x where x.id = (e->>'plan_id')::uuid and x.workspace_id = p_workspace_id)
       or (e->>'member_id') is not null and not exists (select 1 from public.members x where x.id = (e->>'member_id')::uuid and x.workspace_id = p_workspace_id) then
      raise exception 'a fee entry is not of this space';
    end if;
    insert into public.room_rental_fees (workspace_id, rental_id, unit, fee_cents, role_id, plan_id, member_id)$a$);
  if v_def is null or position('a fee entry is not of this space' in v_def) = 0 then
    raise exception '0617: set_room_rental_fees_v1 anchor missing';
  end if;
  execute v_def;
end
$migration$;

select public.set_deskilo_schema_version(617);
