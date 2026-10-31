-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one private storage bucket; three helpers; two storage policies, read and
-- insert; no update and no delete, so a stored original stays;
-- bank_statements_v1 restated whole from 0603 with source_sha256)
--
-- 0621 (#2380, owner amendment of 2026-10-14) -- the imported bank statement
-- file is kept, byte for byte, beside the statement it produced. #3054 kept
-- its sha256, its name and every parsed movement but not the bytes.
--
--   bucket bank-statements, private, at most bank.import_max_bytes' default
--   (5 MiB); an object is `<workspace_id>/<sha256 of the bytes>`, so the
--   statement's own source_sha256 names its file and no column is needed.
--
-- Who: a reader of the statements (bank_statement_reader) reads them; the
-- one who may import (issueInvoices) stores them, and only the file of a
-- statement they imported themselves; never an assistant's token, never
-- with the feature off. A name no statement carries is refused, so nobody
-- fills the bucket with files nobody can delete, and nobody supplies the
-- original of a statement imported before 0621: that one has none. Nobody updates or deletes an original:
-- the file is part of the books (retention class 'books', #2571), and it
-- leaves only with the space's own retained data. The workspace export
-- does not copy it: it is the bank's document, kept here as received.

insert into storage.buckets (id, name, public, file_size_limit)
values ('bank-statements', 'bank-statements', false, 5242880)
on conflict (id) do nothing;

-- The workspace an object path names, or null for any other shape.
create or replace function public.bank_original_workspace(p_name text)
returns uuid language sql immutable set search_path = public as $fn$
  select case when p_name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{64}$'
              then split_part(p_name, '/', 1)::uuid end;
$fn$;
revoke execute on function public.bank_original_workspace(text) from public, anon;
grant execute on function public.bank_original_workspace(text) to authenticated;

-- Whether the caller may read ([p_write] false) or store ([p_write] true)
-- the originals of [p_workspace_id]: the same people as the statements.
create or replace function public.bank_original_access(p_workspace_id uuid, p_write boolean)
returns boolean language sql stable security definer set search_path = public as $fn$
  select p_workspace_id is not null
     and auth.uid() is not null
     and not public.mcp_is_delegated()
     and exists (select 1 from public.members m
                  where m.workspace_id = p_workspace_id and m.user_id = auth.uid()
                    and m.status = 'active')
     and public.feature_effective(p_workspace_id, 'bankImport')
     and case when p_write then public.has_permission(p_workspace_id, 'issueInvoices')
              else public.bank_statement_reader(p_workspace_id) end;
$fn$;
revoke execute on function public.bank_original_access(uuid, boolean) from public, anon;
grant execute on function public.bank_original_access(uuid, boolean) to authenticated;

-- Whether [p_name] is the original of a statement the caller imported.
create or replace function public.bank_original_imported(p_name text)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1 from public.bank_statements s
      join public.members m on m.id = s.imported_by_member_id
     where s.workspace_id = public.bank_original_workspace(p_name)
       and s.source_sha256 = split_part(p_name, '/', 2)
       and m.user_id = auth.uid());
$fn$;
revoke execute on function public.bank_original_imported(text) from public, anon;
grant execute on function public.bank_original_imported(text) to authenticated;

drop policy if exists bank_originals_select on storage.objects;
create policy bank_originals_select on storage.objects for select to authenticated
  using (bucket_id = 'bank-statements'
         and public.bank_original_access(public.bank_original_workspace(name), false));

drop policy if exists bank_originals_insert on storage.objects;
create policy bank_originals_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'bank-statements'
              and public.bank_original_access(public.bank_original_workspace(name), true)
              and public.bank_original_imported(name));

-- The statement names its original: the client reads it at
-- <workspace_id>/<source_sha256>.
create or replace function public.bank_statements_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.bank_import_actor(p_workspace_id, 'read');
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', s.id, 'format', s.format, 'account', s.account, 'currency', s.currency,
      'statement_ref', s.statement_ref, 'file_name', s.file_name,
      'source_sha256', s.source_sha256,
      'period_from', s.period_from, 'period_to', s.period_to,
      'opening_cents', s.opening_cents, 'closing_cents', s.closing_cents,
      'imported_at', s.imported_at,
      'lines', (select count(*) from public.bank_statement_lines l where l.statement_id = s.id),
      'open', (select count(*) from public.bank_statement_lines l
                where l.statement_id = s.id
                  and public.bank_line_status(l) in ('open', 'review', 'recorded')))
      order by s.period_to desc, s.imported_at desc)
      from public.bank_statements s where s.workspace_id = p_workspace_id), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.bank_statements_v1(uuid) from public, anon;
grant execute on function public.bank_statements_v1(uuid) to authenticated;

select public.set_deskilo_schema_version(621);
