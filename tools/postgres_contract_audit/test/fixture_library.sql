-- SPDX-License-Identifier: AGPL-3.0-or-later
-- A neutral schema for the contract audit: a small library. Nothing in it
-- knows a coworking space. Two overloads, an invoker and a definer routine,
-- PUBLIC / role / revoked execute rights, a trigger, a check constraint and a
-- row-level-security policy.
create schema library;

create table library.books (
  id integer primary key,
  title text not null check (char_length(title) > 0),
  copies integer not null default 1 check (copies >= 0)
);
create table library.loans (
  id integer primary key,
  book_id integer not null references library.books (id),
  member text not null
);
alter table library.loans enable row level security;
create policy loans_own on library.loans for select using (member = current_user);

-- @@
create function library.title_of(p_id integer) returns text
language sql stable as $$ select title from library.books where id = p_id $$;

-- @@
create function library.title_of(p_id integer, p_upper boolean) returns text
language sql stable as $$ select case when p_upper then upper(title) else title end from library.books where id = p_id $$;

-- @@
create function library.lend(p_book integer, p_member text) returns integer
language plpgsql security definer set search_path = library as $$
begin
  update library.books set copies = copies - 1 where id = p_book;
  insert into library.loans (id, book_id, member) values (p_book, p_book, p_member);
  return p_book;
end;
$$;

-- @@
create function library.touch_loan() returns trigger
language plpgsql as $$ begin return new; end; $$;
create trigger loans_touch before insert on library.loans
  for each row execute function library.touch_loan();

-- @@@
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'audit_reader') then create role audit_reader; end if;
  if not exists (select 1 from pg_roles where rolname = 'audit_clerk') then create role audit_clerk; end if;
end $$;
revoke execute on function library.lend(integer, text) from public;
grant execute on function library.lend(integer, text) to audit_clerk;
grant execute on function library.title_of(integer) to audit_reader;
