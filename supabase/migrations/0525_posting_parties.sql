-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0525 (#2376, #2365) -- the third party of each posted document, so the FEC
-- of a local book carries its auxiliary accounts (CompAuxNum / CompAuxLib)
-- as the French importers expect:
--
--   * an invoice: its member, by member number and the name the invoice
--     was issued to;
--   * a supplier's bill or credit note: the supplier, by supplier number
--     and name;
--   * a member's receipt: the member who paid it.
--
-- posting_parties(workspace, document ids) answers a map document id ->
-- {kind, number, name} for the documents it knows, to whoever may read the
-- books (viewFinances), like compute_postings.

create or replace function public.posting_parties(p_workspace_id uuid, p_document_ids uuid[])
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not public.has_permission(p_workspace_id, 'viewFinances') then
    raise exception 'you may not read the books' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_object_agg(x.id, jsonb_build_object('kind', x.kind, 'number', x.number, 'name', x.name))
      from (
        select i.id, 'member' as kind, m.member_number as number, i.member_name as name
          from public.invoices i
          join public.members m on m.id = i.member_id
         where i.workspace_id = p_workspace_id and i.id = any(p_document_ids)
        union all
        select d.id, 'supplier', s.supplier_number, s.name
          from public.purchase_documents d
          join public.suppliers s on s.workspace_id = d.workspace_id and s.id = d.supplier_id
         where d.workspace_id = p_workspace_id and d.kind in ('bill', 'credit_note')
           and d.id = any(p_document_ids)
        union all
        select d.id, 'member', m.member_number,
               coalesce(nullif(public.profile_full_name(p), ''), p.display_name)
          from public.purchase_documents d
          join public.members m on m.workspace_id = d.workspace_id and m.id = d.payer_member_id
          join public.profiles p on p.id = m.user_id
         where d.workspace_id = p_workspace_id and d.kind = 'member_receipt'
           and d.id = any(p_document_ids)
      ) x), '{}'::jsonb);
end;
$fn$;
revoke execute on function public.posting_parties(uuid, uuid[]) from public, anon;
grant execute on function public.posting_parties(uuid, uuid[]) to authenticated;

select public.set_deskilo_schema_version(525);
