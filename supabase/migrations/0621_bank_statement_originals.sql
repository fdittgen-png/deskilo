-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one private storage bucket; two helpers; two storage policies, read and
-- insert; no update and no delete, so a stored original stays)
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
-- one who may import (issueInvoices) stores them; never an assistant's
-- token, never with the feature off. Nobody updates or deletes an original:
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

drop policy if exists bank_originals_select on storage.objects;
create policy bank_originals_select on storage.objects for select to authenticated
  using (bucket_id = 'bank-statements'
         and public.bank_original_access(public.bank_original_workspace(name), false));

drop policy if exists bank_originals_insert on storage.objects;
create policy bank_originals_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'bank-statements'
              and public.bank_original_access(public.bank_original_workspace(name), true));

select public.set_deskilo_schema_version(621);
