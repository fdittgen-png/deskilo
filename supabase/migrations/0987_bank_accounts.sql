-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
-- (a new table; two columns and a digest added to the bank statements and their movements, filled in; the import
--  restated to scope its duplicate check by the bank account)
--
-- #4496 -- a bank account is one record of the business: its name, its IBAN or other identifiers, the names it is also
-- known by (aliases), its currency and the ledger account it books to. A statement is imported INTO an account, and
-- two files of one account never import the same movement twice, whatever name the account had in each file.
--
--   bank_accounts            the accounts of a business (master data, Settings › Master data). Read by whoever reads
--                            the bank statements; written by whoever imports them (save_bank_account_v1,
--                            archive_bank_account_v1).
--   bank_statements,         gain bank_account_id; a movement gains movement_hash, the digest of its financial fields
--   bank_statement_lines     WITHOUT the account's name (the old line_hash folded the name in, so one account under two
--                            names hashed every movement twice).
--   import_bank_statement_v2 imports into the account picked: the bank's own id and the movement digest are looked up
--                            in that account, whichever name its earlier files came under. A statement with no account
--                            picked, an archived one, another business's, one in another currency, or a file that names
--                            an account this one is not known by, is refused, saying which.
--   import_bank_statement_v1 (an app from before this) imports into the one account its statement's name names (the
--                            name, the IBAN, an identifier or an alias); a name no account carries is refused.
--   bank_import_names_unattached_v1  the names earlier statements were imported under that no account carries yet:
--                            the owner adds each to an account (an alias) and its statements are attached.
--
-- On upgrade: a business whose payment details name an IBAN gets its first account from them (the bank's name, else
-- the IBAN; the account number as an identifier; the business's currency), and every statement imported under a name
-- of an account is attached to it. Nothing is dropped: a statement under a name no account carries keeps its name and
-- is listed until it is attached.

-- ── the accounts ────────────────────────────────────────────────────────────────────────────────────────────────
create table public.bank_accounts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 64),
  iban text not null default '' check (iban ~ '^([A-Z]{2}[0-9]{2}[A-Z0-9]{11,30})?$'),
  identifiers text[] not null default '{}' check (cardinality(identifiers) <= 10),
  aliases text[] not null default '{}' check (cardinality(aliases) <= 20),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  book_account_id uuid references public.book_accounts (id) on delete set null,
  archived boolean not null default false,
  created_by_member_id uuid references public.members (id) on delete set null,
  unique (workspace_id, id)
);
select public.ensure_system_columns('bank_accounts');
create unique index bank_accounts_name on public.bank_accounts (workspace_id, lower(btrim(name)));

comment on table public.bank_accounts is
  '#4496 -- the bank accounts of a business: the account a statement is imported into, and the names it is known by.';

alter table public.bank_accounts enable row level security;
revoke all on public.bank_accounts from public, anon, authenticated;
grant select on public.bank_accounts to authenticated;
create policy bank_accounts_select on public.bank_accounts for select to authenticated
  using (public.bank_statement_reader(workspace_id));
create policy mcp_delegated_deny on public.bank_accounts as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- A name as an account is matched by it: upper case, without its spaces (an IBAN in groups of four is the IBAN).
create or replace function public.bank_account_key(p_name text)
returns text language sql immutable set search_path = public as $fn$
  select upper(regexp_replace(coalesce(p_name, ''), '\s+', '', 'g'));
$fn$;
revoke execute on function public.bank_account_key(text) from public, anon, authenticated;

-- Every name an account is known by, as keys: its name, its IBAN, its identifiers and its aliases.
create or replace function public.bank_account_keys(p_account public.bank_accounts)
returns text[] language sql immutable set search_path = public as $fn$
  select array(select distinct k from unnest(
    array[public.bank_account_key(p_account.name), public.bank_account_key(p_account.iban)]
    || array(select public.bank_account_key(x) from unnest(p_account.identifiers) x)
    || array(select public.bank_account_key(x) from unnest(p_account.aliases) x)) k where k <> '');
$fn$;
revoke execute on function public.bank_account_keys(public.bank_accounts) from public, anon, authenticated;

-- ── the statements and their movements know their account ───────────────────────────────────────────────────────
-- audience: all row readers (the account of a statement and the digest of a movement are as readable as they are)
alter table public.bank_statements add column bank_account_id uuid;
alter table public.bank_statements add constraint bank_statements_bank_account
  foreign key (workspace_id, bank_account_id) references public.bank_accounts (workspace_id, id);
alter table public.bank_statement_lines add column bank_account_id uuid;
alter table public.bank_statement_lines add constraint bank_statement_lines_bank_account
  foreign key (workspace_id, bank_account_id) references public.bank_accounts (workspace_id, id);
alter table public.bank_statement_lines add column movement_hash text check (movement_hash ~ '^[0-9a-f]{64}$');

-- The financial fields of a movement as one digest, without the account's name: what two copies of one movement
-- share whatever name their files gave the account. It flags a resemblance; it never decides one.
create or replace function public.bank_movement_hash(
  p_booking date, p_value date, p_amount bigint, p_currency text,
  p_reference text, p_end_to_end text, p_iban text, p_remittance text)
returns text language sql immutable set search_path = public as $fn$
  select encode(sha256(convert_to(concat_ws('|', p_booking::text, p_value::text, p_amount::text, p_currency,
    p_reference, p_end_to_end, p_iban, p_remittance), 'UTF8')), 'hex');
$fn$;
revoke execute on function public.bank_movement_hash(date, date, bigint, text, text, text, text, text)
  from public, anon, authenticated;

update public.bank_statement_lines
   set movement_hash = public.bank_movement_hash(booking_date, value_date, amount_cents, currency,
                                                 reference, end_to_end_id, counterparty_iban, remittance);
alter table public.bank_statement_lines alter column movement_hash set not null;
-- A movement written by another path than the import (a restore, a test) gets its digest and its statement's account.
create or replace function public.bank_statement_line_fill()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if new.movement_hash is null then
    new.movement_hash := public.bank_movement_hash(new.booking_date, new.value_date, new.amount_cents, new.currency,
      new.reference, new.end_to_end_id, new.counterparty_iban, new.remittance);
  end if;
  if new.bank_account_id is null then
    select s.bank_account_id into new.bank_account_id from public.bank_statements s where s.id = new.statement_id;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.bank_statement_line_fill() from public, anon, authenticated;
create trigger bank_statement_lines_fill before insert on public.bank_statement_lines
  for each row execute function public.bank_statement_line_fill();
create index bank_statement_lines_account_tx on public.bank_statement_lines (bank_account_id, transaction_id)
  where transaction_id <> '';
create index bank_statement_lines_account_movement on public.bank_statement_lines (bank_account_id, movement_hash);
create index bank_statements_unattached on public.bank_statements (workspace_id, account) where bank_account_id is null;

-- ── the upgrade: a first account from the payment details, and the statements attached by their name ─────────────
insert into public.bank_accounts (workspace_id, name, iban, identifiers, currency)
select w.id,
       left(coalesce(nullif(btrim(w.payment_instructions ->> 'bank_name'), ''), public.bank_account_key(w.payment_instructions ->> 'iban')), 64),
       public.bank_account_key(w.payment_instructions ->> 'iban'),
       case when btrim(coalesce(w.payment_instructions ->> 'account_number', '')) = '' then '{}'::text[]
            else array[left(btrim(w.payment_instructions ->> 'account_number'), 64)] end,
       w.currency_code
  from public.workspaces w
 where public.bank_account_key(w.payment_instructions ->> 'iban') ~ '^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$'
   and w.currency_code ~ '^[A-Z]{3}$';

create or replace function public.bank_statements_attach(p_workspace_id uuid)
returns integer language plpgsql security definer set search_path = public as $fn$
declare
  v_n integer;
begin
  update public.bank_statements s set bank_account_id = a.id
    from public.bank_accounts a
   where s.workspace_id = p_workspace_id and a.workspace_id = p_workspace_id and not a.archived
     and s.bank_account_id is null and public.bank_account_key(s.account) = any (public.bank_account_keys(a))
     and s.currency = a.currency;
  get diagnostics v_n = row_count;
  update public.bank_statement_lines l set bank_account_id = s.bank_account_id
    from public.bank_statements s
   where l.statement_id = s.id and s.workspace_id = p_workspace_id
     and s.bank_account_id is not null and l.bank_account_id is distinct from s.bank_account_id;
  return v_n;
end;
$fn$;
revoke execute on function public.bank_statements_attach(uuid) from public, anon, authenticated;

do $attach$
declare
  r record;
  v_total integer := 0;
begin
  for r in select distinct workspace_id from public.bank_statements loop
    v_total := v_total + public.bank_statements_attach(r.workspace_id);
  end loop;
  raise notice '0987: % bank accounts made from payment details, % statements attached, % under a name no account carries',
    (select count(*) from public.bank_accounts), v_total,
    (select count(*) from public.bank_statements where bank_account_id is null);
end
$attach$;

-- ── the accounts, written ───────────────────────────────────────────────────────────────────────────────────────
-- Creates ([p_id] null) or changes an account. Every name it is known by is its own in the business: no other active
-- account carries it. Its currency stays the one its statements are in. Its ledger account is a posting asset
-- account of the business's book. Answers the account and how many statements it took on (names now its own).
create or replace function public.save_bank_account_v1(
  p_workspace_id uuid, p_id uuid, p_name text, p_iban text, p_identifiers text[], p_aliases text[],
  p_currency text, p_book_account_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid := public.bank_import_actor(p_workspace_id, 'issueInvoices');
  v_row public.bank_accounts;
  v_ids text[] := array(select distinct left(btrim(x), 64) from unnest(coalesce(p_identifiers, '{}')) x where btrim(x) <> '');
  v_aliases text[] := array(select distinct left(btrim(x), 64) from unnest(coalesce(p_aliases, '{}')) x where btrim(x) <> '');
  v_taken text;
  v_attached integer;
begin
  if char_length(btrim(coalesce(p_name, ''))) not between 1 and 64 then
    raise exception 'a bank account needs a name of 1 to 64 characters' using errcode = 'DKL02', detail = '{"reason": "name"}';
  end if;
  if public.bank_account_key(p_iban) !~ '^([A-Z]{2}[0-9]{2}[A-Z0-9]{11,30})?$' then
    raise exception 'this is not an IBAN' using errcode = 'DKL02', detail = '{"reason": "iban"}';
  end if;
  if coalesce(p_currency, '') !~ '^[A-Z]{3}$' then
    raise exception 'a bank account needs its currency' using errcode = 'DKL02', detail = '{"reason": "currency"}';
  end if;
  if cardinality(v_ids) > 10 or cardinality(v_aliases) > 20 then
    raise exception 'too many identifiers or aliases' using errcode = 'DKL02', detail = '{"reason": "aliases"}';
  end if;
  if p_book_account_id is not null and not exists (
       select 1 from public.book_accounts b
        where b.id = p_book_account_id and b.workspace_id = p_workspace_id and b.account_type = 'asset' and b.is_posting) then
    raise exception 'the ledger account is not a posting asset account of this business' using errcode = 'DKL02',
      detail = '{"reason": "book_account"}';
  end if;
  if p_id is null then
    insert into public.bank_accounts (workspace_id, name, iban, identifiers, aliases, currency, book_account_id, created_by_member_id)
    values (p_workspace_id, btrim(p_name), public.bank_account_key(p_iban), v_ids, v_aliases, p_currency, p_book_account_id, v_me)
    returning * into v_row;
  else
    select * into v_row from public.bank_accounts where id = p_id and workspace_id = p_workspace_id for update;
    if v_row.id is null then
      raise exception 'no such bank account in this business' using errcode = 'DKL02', detail = '{"reason": "account"}';
    end if;
    if v_row.currency <> p_currency and exists (select 1 from public.bank_statements s where s.bank_account_id = p_id) then
      raise exception 'the account''s statements are in %: its currency stays', v_row.currency using errcode = 'DKL02',
        detail = '{"reason": "currency"}';
    end if;
    update public.bank_accounts
       set name = btrim(p_name), iban = public.bank_account_key(p_iban), identifiers = v_ids, aliases = v_aliases,
           currency = p_currency, book_account_id = p_book_account_id
     where id = p_id
    returning * into v_row;
  end if;
  select k into v_taken from unnest(public.bank_account_keys(v_row)) k
   where exists (select 1 from public.bank_accounts o
                  where o.workspace_id = p_workspace_id and o.id <> v_row.id and not o.archived
                    and k = any (public.bank_account_keys(o)))
   limit 1;
  if v_taken is not null then
    raise exception 'another bank account of this business is known by %', v_taken using errcode = 'DKL02',
      detail = jsonb_build_object('reason', 'taken', 'name', v_taken)::text;
  end if;
  v_attached := public.bank_statements_attach(p_workspace_id);
  return jsonb_build_object('id', v_row.id, 'attached', v_attached);
exception when unique_violation then
  raise exception 'another bank account of this business has this name' using errcode = 'DKL02', detail = '{"reason": "taken"}';
end;
$fn$;
revoke execute on function public.save_bank_account_v1(uuid, uuid, text, text, text[], text[], text, uuid) from public, anon;
grant execute on function public.save_bank_account_v1(uuid, uuid, text, text, text[], text[], text, uuid) to authenticated;

-- An account no longer imported into: its statements keep it; it is offered no more. false when it was archived.
create or replace function public.archive_bank_account_v1(p_workspace_id uuid, p_id uuid)
returns boolean language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid := public.bank_import_actor(p_workspace_id, 'issueInvoices');
begin
  update public.bank_accounts set archived = true where id = p_id and workspace_id = p_workspace_id and not archived;
  return found;
end;
$fn$;
revoke execute on function public.archive_bank_account_v1(uuid, uuid) from public, anon;
grant execute on function public.archive_bank_account_v1(uuid, uuid) to authenticated;

-- The names statements were imported under that no account carries: each with its statements and its period.
create or replace function public.bank_import_names_unattached_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.bank_import_actor(p_workspace_id, 'read');
  return coalesce((
    select jsonb_agg(jsonb_build_object('name', account, 'currency', currency, 'statements', n,
                                        'from', period_from, 'to', period_to) order by account, currency)
      from (select account, currency, count(*) as n, min(period_from) as period_from, max(period_to) as period_to
              from public.bank_statements
             where workspace_id = p_workspace_id and bank_account_id is null
             group by account, currency) x), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.bank_import_names_unattached_v1(uuid) from public, anon;
grant execute on function public.bank_import_names_unattached_v1(uuid) to authenticated;

-- ── import into an account ──────────────────────────────────────────────────────────────────────────────────────
-- [p_bank_account_id] the account picked; [p_statement] and [p_lines] as import_bank_statement_v1 takes them. The
-- statement's own account (what the file names, empty for most CSV files) must be one of the account's names.
create or replace function public.import_bank_statement_v2(
  p_workspace_id uuid, p_bank_account_id uuid, p_statement jsonb, p_lines jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_bank public.bank_accounts;
  v_max int;
  v_n int;
  v_existing uuid;
  v_id uuid;
  v_named text := btrim(coalesce(p_statement ->> 'account', ''));
  v_account text;
  v_currency text := coalesce(p_statement ->> 'currency', '');
  v_sha text := coalesce(p_statement ->> 'source_sha256', '');
  v_line jsonb;
  v_pos int := 0;
  v_booking date;
  v_value date;
  v_amount bigint;
  v_tx text;
  v_hash text;
  v_movement text;
  v_like uuid;
  v_created int := 0;
  v_known int := 0;
  v_review int := 0;
begin
  v_me := public.bank_import_actor(p_workspace_id, 'issueInvoices');
  if p_bank_account_id is null then
    raise exception 'pick the bank account this statement is of' using errcode = 'DKB03', detail = '{"reason": "bank_account"}';
  end if;
  select * into v_bank from public.bank_accounts where id = p_bank_account_id and workspace_id = p_workspace_id;
  if v_bank.id is null or v_bank.archived then
    raise exception 'this is no bank account the business imports into' using errcode = 'DKB03',
      detail = '{"reason": "bank_account"}';
  end if;
  if v_named <> '' and not (public.bank_account_key(v_named) = any (public.bank_account_keys(v_bank))) then
    raise exception 'the file is of the account %, not of %', v_named, v_bank.name using errcode = 'DKB03',
      detail = jsonb_build_object('reason', 'other_account', 'name', v_named)::text;
  end if;
  if jsonb_typeof(p_lines) is distinct from 'array' then
    raise exception 'the statement has no movements' using errcode = 'DKB03';
  end if;
  v_n := jsonb_array_length(p_lines);
  v_max := (public.setting_value(p_workspace_id, 'bank.import_max_lines') #>> '{}')::int;
  if pg_column_size(p_lines) > (public.setting_value(p_workspace_id, 'bank.import_max_bytes') #>> '{}')::bigint then
    raise exception 'the statement is larger than this server imports' using errcode = 'DKB03';
  end if;
  if v_n = 0 then raise exception 'the statement has no movements' using errcode = 'DKB03'; end if;
  if v_n > v_max then
    raise exception 'the statement has % movements, more than the % one import takes', v_n, v_max
      using errcode = 'DKB03';
  end if;
  if v_sha !~ '^[0-9a-f]{64}$' then raise exception 'the file digest is not a sha256' using errcode = 'DKB03'; end if;
  if v_currency <> v_bank.currency then
    raise exception 'the statement is in %, the account in %', v_currency, v_bank.currency using errcode = 'DKB03',
      detail = '{"reason": "currency"}';
  end if;
  -- the name the statement is kept under: the file's own, else the account's
  v_account := left(upper(coalesce(nullif(v_named, ''), v_bank.name)), 64);

  -- One import per account at a time: the bank ids and the resemblances are read and written under the same lock.
  perform pg_advisory_xact_lock(hashtext('bank_account:' || p_bank_account_id::text));

  select s.id into v_existing from public.bank_statements s
   where s.workspace_id = p_workspace_id and s.source_sha256 = v_sha;
  if v_existing is not null then
    return jsonb_build_object('statement_id', v_existing, 'repeated', true,
      'created', 0, 'known', v_n, 'review', 0);
  end if;

  insert into public.bank_statements
    (workspace_id, bank_account_id, format, account, currency, statement_ref, source_sha256, file_name,
     period_from, period_to, opening_cents, closing_cents, imported_by_member_id)
  select p_workspace_id, p_bank_account_id, p_statement ->> 'format', v_account, v_currency,
         coalesce(p_statement ->> 'statement_ref', ''), v_sha,
         left(coalesce(p_statement ->> 'file_name', ''), 255),
         min((l ->> 'booking_date')::date), max((l ->> 'booking_date')::date),
         (p_statement ->> 'opening_cents')::bigint, (p_statement ->> 'closing_cents')::bigint, v_me
    from jsonb_array_elements(p_lines) l
  returning id into v_id;

  for v_line in select value from jsonb_array_elements(p_lines) loop
    v_pos := v_pos + 1;
    if coalesce(v_line ->> 'currency', '') <> v_currency then
      raise exception 'movement % is in another currency than its statement', v_pos using errcode = 'DKB03';
    end if;
    v_booking := (v_line ->> 'booking_date')::date;
    v_value := coalesce((v_line ->> 'value_date')::date, v_booking);
    v_amount := (v_line ->> 'amount_cents')::bigint;
    v_tx := btrim(coalesce(v_line ->> 'transaction_id', ''));
    -- the bank's own id names one movement of the account, whatever name its earlier files gave the account
    if v_tx <> '' and exists (
      select 1 from public.bank_statement_lines b
       where b.bank_account_id = p_bank_account_id and b.transaction_id = v_tx) then
      v_known := v_known + 1;
      continue;
    end if;
    v_hash := public.bank_line_hash(v_account, v_booking, v_value, v_amount, v_currency,
      coalesce(v_line ->> 'reference', ''), coalesce(v_line ->> 'end_to_end_id', ''),
      coalesce(v_line ->> 'counterparty_iban', ''), coalesce(v_line ->> 'remittance', ''));
    v_movement := public.bank_movement_hash(v_booking, v_value, v_amount, v_currency,
      coalesce(v_line ->> 'reference', ''), coalesce(v_line ->> 'end_to_end_id', ''),
      coalesce(v_line ->> 'counterparty_iban', ''), coalesce(v_line ->> 'remittance', ''));
    v_like := null;
    if v_tx = '' then
      select b.id into v_like from public.bank_statement_lines b
       where b.bank_account_id = p_bank_account_id and b.movement_hash = v_movement and b.statement_id <> v_id
       order by b.created_datetime limit 1;
    end if;
    insert into public.bank_statement_lines
      (workspace_id, statement_id, bank_account_id, account, position, booking_date, value_date, amount_cents,
       currency, transaction_id, counterparty_name, counterparty_iban, reference,
       end_to_end_id, remittance, line_hash, movement_hash, state, resembles_line_id)
    values
      (p_workspace_id, v_id, p_bank_account_id, v_account, v_pos, v_booking, v_value, v_amount, v_currency, v_tx,
       coalesce(v_line ->> 'counterparty_name', ''), coalesce(v_line ->> 'counterparty_iban', ''),
       coalesce(v_line ->> 'reference', ''), coalesce(v_line ->> 'end_to_end_id', ''),
       coalesce(v_line ->> 'remittance', ''), v_hash, v_movement,
       case when v_like is null then 'open' else 'review' end, v_like);
    if v_like is null then v_created := v_created + 1; else v_review := v_review + 1; end if;
  end loop;

  return jsonb_build_object('statement_id', v_id, 'repeated', false,
    'created', v_created, 'known', v_known, 'review', v_review);
end;
$fn$;
revoke execute on function public.import_bank_statement_v2(uuid, uuid, jsonb, jsonb) from public, anon;
grant execute on function public.import_bank_statement_v2(uuid, uuid, jsonb, jsonb) to authenticated;

-- restates 0603: the import of a statement now goes to import_bank_statement_v2, into the account its name names.
-- An app from before #4496 names the account by the text it was given: the one active account known by that name
-- takes the statement; a name no account carries is refused, so no movement is imported outside an account.
create or replace function public.import_bank_statement_v1(
  p_workspace_id uuid, p_statement jsonb, p_lines jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_key text := public.bank_account_key(p_statement ->> 'account');
  v_account uuid;
begin
  perform public.bank_import_actor(p_workspace_id, 'issueInvoices');
  select a.id into v_account from public.bank_accounts a
   where a.workspace_id = p_workspace_id and not a.archived and v_key = any (public.bank_account_keys(a));
  if v_account is null then
    raise exception 'no bank account of this business is known by %: add it under Master data, Bank accounts',
      coalesce(nullif(btrim(p_statement ->> 'account'), ''), '(no name)') using errcode = 'DKB03',
      detail = '{"reason": "bank_account"}';
  end if;
  return public.import_bank_statement_v2(p_workspace_id, v_account, p_statement, p_lines);
end;
$fn$;
revoke execute on function public.import_bank_statement_v1(uuid, jsonb, jsonb) from public, anon;
grant execute on function public.import_bank_statement_v1(uuid, jsonb, jsonb) to authenticated;

select public.set_deskilo_schema_version(987);
