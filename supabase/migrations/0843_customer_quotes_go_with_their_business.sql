-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- #4166 -- a sent quote, its revisions and its recorded decision are immutable
-- while their business exists, and they go with it (the pattern of the HMRC
-- filings 0648, the national-channel verdicts 0701/0719, the stock ledger 0747,
-- the match history 0750): `customer_quotes.workspace_id` cascades, but the
-- guards refused every delete and the revisions, decisions and conversions
-- referenced their quote with ON DELETE RESTRICT, so a business that ever sent a
-- quote could never be deleted, nor its data erased. Now:
--   * the guards let a row go when its business no longer exists, and refuse
--     every other delete and every change exactly as before;
--   * the rows that belong to a quote or to one of its revisions go with it
--     (their guards still refuse a direct delete);
--   * an invoice draft that came from a quote goes with the quote.
-- A conversion keeps its invoice: an issued invoice is immutable and retained,
-- so a business that converted a quote still cannot be deleted (the invoice
-- refuses it, as it always did).

create or replace function public.customer_quote_frozen() returns trigger
language plpgsql set search_path = public as $fn$
begin
  if tg_op = 'DELETE' and not exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
    return old;
  end if;
  if tg_table_name = 'customer_quote_revisions' then
    if tg_op = 'DELETE' then
      if old.status = 'sent' then
        raise exception 'a sent revision is never deleted' using errcode = 'DKQ05';
      end if;
      return old;
    end if;
    if old.status = 'sent' and (
         (to_jsonb(new) - 'superseded_at' - public.system_column_names())
         is distinct from (to_jsonb(old) - 'superseded_at' - public.system_column_names())) then
      raise exception 'a sent revision cannot be edited: amend the quote' using errcode = 'DKQ05';
    end if;
    return new;
  elsif tg_table_name = 'customer_quotes' then
    if tg_op = 'DELETE' and (old.status <> 'draft' or exists (
         select 1 from public.customer_quote_revisions r
          where r.quote_id = old.id and r.status = 'sent')) then
      raise exception 'a quote that was sent is never deleted' using errcode = 'DKQ05';
    end if;
    return case tg_op when 'DELETE' then old else new end;
  end if;
  raise exception 'a decision or a conversion is never changed' using errcode = 'DKQ05';
end
$fn$;
revoke execute on function public.customer_quote_frozen() from public, anon, authenticated;

create or replace function public.quote_draft_guard() returns trigger
language plpgsql set search_path = public as $fn$
begin
  if tg_op = 'DELETE' and not exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
    return old;
  end if;
  if old.origin_quote_id is not null
     and coalesce(current_setting('deskilo.quote_conversion', true), '') is distinct from old.id::text then
    raise exception 'an invoice draft that came from a quote changes only through the quote'
      using errcode = 'DKQ09';
  end if;
  if tg_op = 'UPDATE' and new.origin_quote_id is distinct from old.origin_quote_id then
    raise exception 'the quote of an invoice draft never changes' using errcode = 'DKQ09';
  end if;
  return case tg_op when 'DELETE' then old else new end;
end
$fn$;
revoke execute on function public.quote_draft_guard() from public, anon, authenticated;

alter table public.customer_quote_revisions
  drop constraint customer_quote_revisions_workspace_id_quote_id_fkey,
  add constraint customer_quote_revisions_workspace_id_quote_id_fkey
    foreign key (workspace_id, quote_id) references public.customer_quotes (workspace_id, id) on delete cascade;
alter table public.customer_quote_decisions
  drop constraint customer_quote_decisions_workspace_id_quote_id_fkey,
  add constraint customer_quote_decisions_workspace_id_quote_id_fkey
    foreign key (workspace_id, quote_id) references public.customer_quotes (workspace_id, id) on delete cascade,
  drop constraint customer_quote_decisions_workspace_id_revision_id_fkey,
  add constraint customer_quote_decisions_workspace_id_revision_id_fkey
    foreign key (workspace_id, revision_id) references public.customer_quote_revisions (workspace_id, id) on delete cascade;
alter table public.customer_quote_conversions
  drop constraint customer_quote_conversions_workspace_id_quote_id_fkey,
  add constraint customer_quote_conversions_workspace_id_quote_id_fkey
    foreign key (workspace_id, quote_id) references public.customer_quotes (workspace_id, id) on delete cascade,
  drop constraint customer_quote_conversions_workspace_id_revision_id_fkey,
  add constraint customer_quote_conversions_workspace_id_revision_id_fkey
    foreign key (workspace_id, revision_id) references public.customer_quote_revisions (workspace_id, id) on delete cascade;
alter table public.standalone_invoice_drafts
  drop constraint standalone_invoice_drafts_origin_quote_id_fkey,
  add constraint standalone_invoice_drafts_origin_quote_id_fkey
    foreign key (origin_quote_id) references public.customer_quotes (id) on delete cascade;

select public.set_deskilo_schema_version(843);
