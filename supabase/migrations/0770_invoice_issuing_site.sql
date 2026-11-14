-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0770 (#3968) -- an invoice posts in the book of its own issuing site only.
--  * The seller block an invoice freezes at issue (create_invoice) names the
--    id of the site it is issued for beside its name.
--  * `invoices.site_id` is that site, set at issue from the seller block: one
--    fact, not a second derivation. A site the issuing path names itself,
--    of the same business, is kept. A credit note takes the site of the
--    invoice it replaces. A block that names no site (the business itself,
--    or an issuing path with no seller site) gives the default site.
--  * Invoices issued before 0770 take the site their seller block names, by
--    its name in the business; where it names none, the default site.
--  * The postings of a site's book (compute_postings) take its own invoices;
--    an invoice without a site belongs to the default site's book and to no
--    other.

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

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

-- ── 1. the seller block names its site ────────────────────────────────
do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'create_invoice';
  v_def := pg_temp.anchor_replace(v_def,
    $a$'site', coalesce(v_site.name, ''),$a$,
    $a$'site', coalesce(v_site.name, ''),
      'site_id', v_site.id,$a$);
  if v_def is null or position($a$'site_id', v_site.id,$a$ in v_def) = 0 then
    raise exception '0770: create_invoice seller site anchor missing' using errcode = 'P0001';
  end if;
  execute v_def;
end
$migration$;

-- ── 2. the invoice carries its issuing site ───────────────────────────
-- The site of an invoice of [p_workspace_id] whose seller block is
-- [p_parties]: the site the block names, by its id, else by its name when
-- the block names a site other than the default, else the default site.
create or replace function public.invoice_issuing_site(p_workspace_id uuid, p_parties jsonb)
returns uuid
language sql stable security definer set search_path = public as $fn$
  select coalesce(
    (select s.id from public.sites s
      where s.workspace_id = p_workspace_id
        and s.id::text = p_parties #>> '{seller,site_id}'),
    (select s.id from public.sites s
      where s.workspace_id = p_workspace_id
        and coalesce((p_parties #>> '{seller,site_default}')::boolean, true) = false
        and s.name = p_parties #>> '{seller,site}'
      order by s.sort_order, s.created_at
      limit 1),
    (public.default_site(p_workspace_id)).id);
$fn$;

revoke execute on function public.invoice_issuing_site(uuid, jsonb) from public, anon, authenticated;

create or replace function public.invoice_issuing_site_stamp()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  -- A site the server names for the invoice, of this business, stays; a
  -- credit note follows the invoice it replaces.
  new.site_id := coalesce(
    (select s.id from public.sites s
      where s.id = new.site_id and s.workspace_id = new.workspace_id),
    (select o.site_id from public.invoices o
      where o.id = new.replaces_invoice_id and o.workspace_id = new.workspace_id),
    public.invoice_issuing_site(new.workspace_id, new.parties));
  return new;
end;
$fn$;

revoke execute on function public.invoice_issuing_site_stamp() from public, anon, authenticated;

drop trigger if exists invoice_issuing_site_stamp on public.invoices;
create trigger invoice_issuing_site_stamp
  before insert on public.invoices
  for each row execute function public.invoice_issuing_site_stamp();

-- The guard of issued invoices lets the server stamp the issuing site once on
-- an invoice that has none, with nothing else changing. A signed-in caller
-- never chooses the book an invoice lands in: for `authenticated` and `anon`
-- the stamp is refused like any other change.
create or replace function public.invoices_immutable()
returns trigger
language plpgsql
as $fn$
declare
  o jsonb := to_jsonb(old) - public.system_column_names();
  n jsonb := to_jsonb(new) - public.system_column_names();
begin
  if tg_op = 'UPDATE'
     and old.voided_at is null
     and new.voided_at is not null
     and (o - 'voided_at' - 'voided_by_name') = (n - 'voided_at' - 'voided_by_name') then
    return new;
  end if;
  if tg_op = 'UPDATE'
     and old.settled_by_invoice_id is null
     and new.settled_by_invoice_id is not null
     and (o - 'settled_by_invoice_id') = (n - 'settled_by_invoice_id') then
    return new;
  end if;
  if tg_op = 'UPDATE'
     and old.settled_by_invoice_id is not null
     and new.settled_by_invoice_id is null
     and (o - 'settled_by_invoice_id') = (n - 'settled_by_invoice_id') then
    return new;
  end if;
  -- #3968: the issuing site, once, by the server's own roles.
  if tg_op = 'UPDATE'
     and current_user not in ('authenticated', 'anon')
     and old.site_id is null
     and new.site_id is not null
     and o = n then
    return new;
  end if;
  raise exception 'invoices are immutable' using errcode = 'P0001';
end;
$fn$;

revoke execute on function public.invoices_immutable() from public, anon;

-- The invoices issued before: the site their seller block names, else the
-- default site; credit notes then follow the invoice they replace. A business
-- with no site at all keeps its invoices without one: it has no book.
update public.invoices i
   set site_id = public.invoice_issuing_site(i.workspace_id, i.parties)
 where i.site_id is null and i.replaces_invoice_id is null
   and public.invoice_issuing_site(i.workspace_id, i.parties) is not null;
update public.invoices i
   set site_id = coalesce(o.site_id, public.invoice_issuing_site(i.workspace_id, i.parties))
  from public.invoices o
 where i.site_id is null and o.id = i.replaces_invoice_id
   and coalesce(o.site_id, public.invoice_issuing_site(i.workspace_id, i.parties)) is not null;

-- ── 3. a book takes its own invoices ──────────────────────────────────
do $migration$
declare
  v_def text;
  v_was text;
begin
  select pg_get_functiondef('public.compute_postings(uuid,uuid,date,date)'::regprocedure) into v_def;
  v_was := v_def;
  v_def := replace(v_def,
    $a$(inv.site_id = p_issuer_site_id or inv.site_id is null)$a$,
    $a$(inv.site_id = p_issuer_site_id or (inv.site_id is null and v_default))$a$);
  if v_def = v_was or position($a$or inv.site_id is null)$a$ in v_def) > 0 then
    raise exception '0770: compute_postings issuing site anchor missing' using errcode = 'P0001';
  end if;
  execute v_def;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(770);
