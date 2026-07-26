-- SPDX-License-Identifier: 0BSD
-- Invoices. NOT YET applied to the hosted reference project — the
-- orchestrator applies it after review.
--
-- Field request: the owner (or an admin the owner appointed via the
-- adminInvoicing delegation flag) creates INVOICES for members. An
-- invoice is an IMMUTABLE document in an archive readable by its
-- member and the workspace admins. Everything the PDF needs is
-- SNAPSHOTTED at issue time (names, addresses, issuer), so later
-- profile edits can never rewrite an issued document; a SHA-256
-- fingerprint over the canonical content is stored and printed as the
-- digital signature. Addresses are new: members carry one on their
-- profile, the workspace carries its own.

-- 1. Addresses.
alter table public.profiles
  add column if not exists address text not null default ''
    check (char_length(address) <= 400);
alter table public.workspaces
  add column if not exists address text not null default ''
    check (char_length(address) <= 400);

-- 2. The archive. RLS: SELECT for the member and admins; NO insert/
-- update/delete policies — writes only through the RPC below, and a
-- belt-and-braces trigger refuses mutation even for definer paths.
create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete restrict,
  issuer_member_id uuid not null references public.members(id) on delete restrict,
  number text not null,
  issued_at timestamptz not null default now(),
  period text,
  title text not null check (char_length(title) between 1 and 200),
  -- [{"label": text, "amount_cents": int}, ...]
  lines jsonb not null,
  total_cents int not null,
  currency text not null,
  member_name text not null,
  member_address text not null default '',
  workspace_name text not null,
  workspace_address text not null default '',
  issuer_name text not null,
  signature text not null,
  unique (workspace_id, number)
);
create index invoices_member_idx on public.invoices (member_id);
create index invoices_workspace_idx on public.invoices (workspace_id);

alter table public.invoices enable row level security;
create policy invoices_select on public.invoices for select using (
  public.is_admin_of(workspace_id)
  or exists (select 1 from public.members m
              where m.id = invoices.member_id and m.user_id = auth.uid())
);

create or replace function public.invoices_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'invoices are immutable';
end;
$$;
create trigger invoices_no_mutation
before update or delete on public.invoices
for each row execute function public.invoices_immutable();

-- 3. Issue an invoice. Caller: owner (incl. active co-owners via
-- is_owner_of) always; admins only while the adminInvoicing delegation
-- flag is on. Numbering is per workspace and year under an advisory
-- lock, so concurrent issues never collide.
create or replace function public.create_invoice(
  p_workspace_id uuid,
  p_member_id uuid,
  p_title text,
  p_lines jsonb,
  p_period text default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_subject public.members;
  v_workspace public.workspaces;
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

  -- Per-workspace/year sequence under an advisory lock.
  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));
  select count(*) into v_count from public.invoices
    where workspace_id = p_workspace_id
      and date_part('year', issued_at) = date_part('year', now());
  v_number := 'INV-' || date_part('year', now())::int || '-'
      || lpad((v_count + 1)::text, 4, '0');

  v_id := gen_random_uuid();
  -- The digital signature: a SHA-256 fingerprint over the canonical
  -- content — any later tampering breaks it, and the trigger above
  -- refuses tampering in the first place.
  v_signature := encode(extensions.digest(convert_to(concat_ws('|',
      v_id::text, v_number, p_workspace_id::text, v_subject.id::text,
      v_member_name, v_member_address, v_workspace.name,
      coalesce(v_workspace.address, ''), v_issuer_name,
      p_title, p_lines::text, v_total::text, v_workspace.currency_code,
      now()::date::text), 'UTF8'), 'sha256'), 'hex');

  insert into public.invoices
    (id, workspace_id, member_id, issuer_member_id, number, period, title,
     lines, total_cents, currency, member_name, member_address,
     workspace_name, workspace_address, issuer_name, signature)
  values
    (v_id, p_workspace_id, v_subject.id, v_actor.id, v_number, p_period,
     btrim(p_title), p_lines, v_total, v_workspace.currency_code,
     v_member_name, v_member_address, v_workspace.name,
     coalesce(v_workspace.address, ''), v_issuer_name, v_signature);
  return v_id;
end;
$$;
revoke execute on function public.create_invoice(uuid, uuid, text, jsonb, text)
  from public, anon;
