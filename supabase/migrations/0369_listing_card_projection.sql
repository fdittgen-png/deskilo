-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0369 -- a correction to the listing of 0367: where the trimming lives.
--
-- 0367 trimmed the document of a private, unpublished workspace inside
-- public_workspace_document -- the function the owner's own page read also
-- goes through, so the owner could no longer read their own draft. The
-- document keeps its contract: every inherited field resolves as before,
-- except the address, which is ALWAYS the workspace's own (never an
-- override). The CARD is what is trimmed: a private workspace that has not
-- published its page is listed with its name, its address and its host
-- type, nothing else. No key is added to the public contract.

create or replace function public.public_workspace_document(p_workspace uuid) returns jsonb
language sql stable security definer set search_path = public as $$
 select (d || coalesce(page.document, '{}'::jsonb)
  || jsonb_build_object('name', w.name, 'currency', w.currency_code,
   'address', coalesce(d ->> 'address', ''),
   'booking_unit', coalesce(w.booking_rules ->> 'granularity', 'flexible'),
   'contacts', coalesce((select jsonb_agg(jsonb_build_object('user_id', m.user_id,
     'name', coalesce(p.display_name, m.managed_name, ''), 'owner', m.is_owner,
     'available', coalesce(s.available, false)) order by m.is_owner desc, m.id)
    from public.members m left join public.profiles p on p.id = m.user_id
    left join public.account_contact_settings s on s.user_id = m.user_id
    left join public.member_public_contact c on c.member_id = m.id
    where m.workspace_id = w.id and m.status = 'active' and
     (m.is_owner or (m.is_admin and c.visible))), '[]'::jsonb)))
 from public.workspaces w
 left join public.workspace_public_pages page on page.workspace_id = w.id
 cross join lateral (select public.workspace_public_defaults(w.id) as d) defaults
 where w.id = p_workspace;
$$;
revoke execute on function public.public_workspace_document(uuid) from public, anon, authenticated;

create or replace function public.refresh_public_workspace_card(p_workspace uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
 if public.feature_effective(p_workspace, 'publicListings')
    and exists (select 1 from public.workspaces w
                 where w.id = p_workspace
                   and (w.visibility_set_at is not null
                        or exists (select 1 from public.workspace_public_pages p
                                    where p.workspace_id = w.id and p.published))) then
  insert into public.public_workspace_cards(workspace_id, name, search_text, document)
   select w.id, w.name,
          w.name || ' ' || coalesce(doc ->> 'address', ''),
          case when w.visibility = 'private'
                    and not exists (select 1 from public.workspace_public_pages p
                                     where p.workspace_id = w.id and p.published)
               then jsonb_build_object('name', doc -> 'name', 'address', doc -> 'address',
                                       'host_type', doc -> 'host_type')
               else doc end
     from public.workspaces w
     cross join lateral (select public.public_workspace_document(w.id) as doc) d
    where w.id = p_workspace
   on conflict (workspace_id) do update
     set name = excluded.name, search_text = excluded.search_text,
         document = excluded.document, updated_at = now();
 else delete from public.public_workspace_cards where workspace_id = p_workspace; end if;
end;
$$;
revoke execute on function public.refresh_public_workspace_card(uuid) from public, anon, authenticated;

select public.refresh_public_workspace_card(w.id) from public.workspaces w
 where w.visibility_set_at is not null;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(369);
