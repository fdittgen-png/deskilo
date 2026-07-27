-- SPDX-License-Identifier: 0BSD
-- Invoice payment reminders (field request). The invoice document
-- stays IMMUTABLE — reminders are collection metadata beside it, one
-- row per reminder sent, so the archive can show "reminded ×N · date".
-- Recording is gated exactly like issuing (owner always, admins via
-- the adminInvoicing flag); members see the reminders on their own
-- invoices like the invoices themselves.

create table public.invoice_reminders (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  sent_at timestamptz not null default now(),
  by_name text not null default ''
);
create index invoice_reminders_invoice_idx
  on public.invoice_reminders (invoice_id);
create index invoice_reminders_workspace_idx
  on public.invoice_reminders (workspace_id);

alter table public.invoice_reminders enable row level security;
create policy invoice_reminders_select on public.invoice_reminders
  for select using (
    public.is_admin_of(workspace_id)
    or exists (select 1
                 from public.invoices i
                 join public.members m on m.id = i.member_id
                where i.id = invoice_reminders.invoice_id
                  and m.user_id = auth.uid())
  );
-- No write policies: writes only through the RPC below.

create or replace function public.record_invoice_reminder(
  p_invoice_id uuid
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_invoice public.invoices;
  v_actor public.members;
  v_actor_name text;
begin
  select * into v_invoice from public.invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'unknown invoice'; end if;
  if v_invoice.voided_at is not null then
    raise exception 'invoice is voided';
  end if;
  select * into v_actor from public.members
    where workspace_id = v_invoice.workspace_id and user_id = auth.uid()
      and status = 'active' and (is_admin or is_owner);
  if v_actor.id is null then raise exception 'not an admin of this workspace'; end if;
  if not public.is_owner_of(v_invoice.workspace_id) and not coalesce(
    (select w.feature_flags -> 'adminInvoicing' = to_jsonb(true)
       from public.workspaces w where w.id = v_invoice.workspace_id), false) then
    raise exception 'admins may not issue invoices here';
  end if;
  select coalesce(display_name, '') into v_actor_name
    from public.profiles where id = v_actor.user_id;
  insert into public.invoice_reminders (workspace_id, invoice_id, by_name)
  values (v_invoice.workspace_id, p_invoice_id, v_actor_name);
end;
$$;
revoke execute on function public.record_invoice_reminder(uuid)
  from public, anon;
