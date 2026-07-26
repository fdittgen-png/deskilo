-- SPDX-License-Identifier: 0BSD
-- Invoice correction (field request): a wrong invoice can be tagged
-- ERRONEOUS (voided) and re-issued as a REPLACEMENT that references the
-- invoice it replaces. Content stays immutable: the trigger now permits
-- exactly ONE narrow change — stamping voided_at/voided_by_name once,
-- with every other column untouched — and still refuses everything
-- else, including un-voiding and DELETE. The replacement carries the
-- replaced invoice's id (technical reference) and number (snapshot for
-- the PDF), covered by its own signature.

-- 1. Void stamp + replacement reference.
alter table public.invoices
  add column voided_at timestamptz,
  add column voided_by_name text not null default '',
  add column replaces_invoice_id uuid references public.invoices(id)
    on delete restrict,
  add column replaces_number text not null default '';

-- One direct replacement per invoice: a wrong REPLACEMENT is voided and
-- replaced itself, forming a chain — never a fork.
create unique index invoices_replaces_unique
  on public.invoices (replaces_invoice_id)
  where replaces_invoice_id is not null;

-- 2. Immutability, amended: the one-way void stamp is the sole
-- permitted UPDATE.
create or replace function public.invoices_immutable()
returns trigger language plpgsql as $$
begin
  if tg_op = 'UPDATE'
     and old.voided_at is null
     and new.voided_at is not null
     and (to_jsonb(old) - 'voided_at' - 'voided_by_name')
       = (to_jsonb(new) - 'voided_at' - 'voided_by_name') then
    return new;
  end if;
  raise exception 'invoices are immutable';
end;
$$;

-- 3. Tag an invoice erroneous. Same authorization as issuing: owner
-- (incl. active co-owners) always, admins via the adminInvoicing flag.
create or replace function public.void_invoice(p_invoice_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_invoice public.invoices;
  v_actor public.members;
  v_actor_name text;
begin
  select * into v_invoice from public.invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'unknown invoice'; end if;
  select * into v_actor from public.members
    where workspace_id = v_invoice.workspace_id and user_id = auth.uid()
      and status = 'active' and (is_admin or is_owner);
  if v_actor.id is null then raise exception 'not an admin of this workspace'; end if;
  if not public.is_owner_of(v_invoice.workspace_id) and not coalesce(
    (select w.feature_flags -> 'adminInvoicing' = to_jsonb(true)
       from public.workspaces w where w.id = v_invoice.workspace_id), false) then
    raise exception 'admins may not issue invoices here';
  end if;
  if v_invoice.voided_at is not null then
    raise exception 'invoice already voided';
  end if;
  select coalesce(display_name, '') into v_actor_name
    from public.profiles where id = v_actor.user_id;
  update public.invoices
     set voided_at = now(), voided_by_name = v_actor_name
   where id = p_invoice_id;
end;
$$;
revoke execute on function public.void_invoice(uuid) from public, anon;

-- 4. create_invoice gains p_replaces: the replacement references the
-- erroneous invoice and, in the same transaction, voids it if the
-- caller had not tagged it yet — the reference always points at a
-- voided document. Postgres cannot change an argument list in place:
-- drop the 0060 signature first.
drop function public.create_invoice(uuid, uuid, text, jsonb, text);
create function public.create_invoice(
  p_workspace_id uuid,
  p_member_id uuid,
  p_title text,
  p_lines jsonb,
  p_period text default null,
  p_replaces uuid default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_subject public.members;
  v_workspace public.workspaces;
  v_replaced public.invoices;
  v_replaces_number text := '';
  v_line jsonb;
  v_total int := 0;
  v_count int;
  v_number text;
  v_member_name text;
  v_member_address text;
  v_issuer_name text;
  v_id uuid;
  v_signature text;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid()
      and status = 'active' and (is_admin or is_owner);
  if v_actor.id is null then raise exception 'not an admin of this workspace'; end if;
  if not public.is_owner_of(p_workspace_id) and not coalesce(
    (select w.feature_flags -> 'adminInvoicing' = to_jsonb(true)
       from public.workspaces w where w.id = p_workspace_id), false) then
    raise exception 'admins may not issue invoices here';
  end if;

  select * into v_subject from public.members
    where id = p_member_id and workspace_id = p_workspace_id
      and status = 'active' and not is_kiosk;
  if v_subject.id is null then raise exception 'unknown subject member'; end if;

  if p_title is null or btrim(p_title) = '' then
    raise exception 'title required';
  end if;
  if jsonb_typeof(p_lines) <> 'array'
     or jsonb_array_length(p_lines) = 0 then
    raise exception 'at least one line required';
  end if;
  for v_line in select * from jsonb_array_elements(p_lines) loop
    if jsonb_typeof(v_line -> 'label') <> 'string'
       or jsonb_typeof(v_line -> 'amount_cents') <> 'number' then
      raise exception 'invalid invoice line';
    end if;
    v_total := v_total + (v_line ->> 'amount_cents')::int;
  end loop;

  select * into v_workspace from public.workspaces where id = p_workspace_id;
  select coalesce(display_name, ''), coalesce(address, '')
    into v_member_name, v_member_address
    from public.profiles where id = v_subject.user_id;
  select coalesce(display_name, '') into v_issuer_name
    from public.profiles where id = v_actor.user_id;

  if p_replaces is not null then
    select * into v_replaced from public.invoices
      where id = p_replaces and workspace_id = p_workspace_id;
    if v_replaced.id is null then raise exception 'unknown invoice'; end if;
    if exists (select 1 from public.invoices
                where replaces_invoice_id = p_replaces) then
      raise exception 'invoice already replaced';
    end if;
    if v_replaced.voided_at is null then
      update public.invoices
         set voided_at = now(), voided_by_name = v_issuer_name
       where id = p_replaces;
    end if;
    v_replaces_number := v_replaced.number;
  end if;

  -- Per-workspace/year sequence under an advisory lock.
  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));
  select count(*) into v_count from public.invoices
    where workspace_id = p_workspace_id
      and date_part('year', issued_at) = date_part('year', now());
  v_number := 'INV-' || date_part('year', now())::int || '-'
      || lpad((v_count + 1)::text, 4, '0');

  v_id := gen_random_uuid();
  -- The digital signature: a SHA-256 fingerprint over the canonical
  -- content — the replacement reference is content and signs too.
  v_signature := encode(extensions.digest(convert_to(concat_ws('|',
      v_id::text, v_number, p_workspace_id::text, v_subject.id::text,
      v_member_name, v_member_address, v_workspace.name,
      coalesce(v_workspace.address, ''), v_issuer_name,
      p_title, p_lines::text, v_total::text, v_workspace.currency_code,
      now()::date::text, coalesce(p_replaces::text, ''),
      v_replaces_number), 'UTF8'), 'sha256'), 'hex');

  insert into public.invoices
    (id, workspace_id, member_id, issuer_member_id, number, period, title,
     lines, total_cents, currency, member_name, member_address,
     workspace_name, workspace_address, issuer_name, signature,
     replaces_invoice_id, replaces_number)
  values
    (v_id, p_workspace_id, v_subject.id, v_actor.id, v_number, p_period,
     btrim(p_title), p_lines, v_total, v_workspace.currency_code,
     v_member_name, v_member_address, v_workspace.name,
     coalesce(v_workspace.address, ''), v_issuer_name, v_signature,
     p_replaces, v_replaces_number);
  return v_id;
end;
$$;
revoke execute on function
  public.create_invoice(uuid, uuid, text, jsonb, text, uuid)
  from public, anon;
