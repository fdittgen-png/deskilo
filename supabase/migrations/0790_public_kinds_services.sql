-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (the public document and the card are restated; every published card is
--  rebuilt; no stored value moves)
--
-- #3553 (1a) -- what a business tells the world says what it is and what it
-- offers. The public document gains three optional fields, none
-- must_understand (an older installation ignores them):
--
--   kinds            the business's kind codes, the primary one first
--                    (business.kind, then business.more_kinds).
--   services         at most twelve services, each published only when it is
--                    active AND marked public: name, category, duration in
--                    minutes, price in minor units, its currency, and its tax
--                    treatment. No description, no internal id.
--   takes_inquiries  whether the business takes inquiries (spaceInquiries).
--
-- The tax treatment says what the listed price means, from the business's own
-- tax regime: `excluded` where a tax is added at the sale (a seller whose
-- country's issuing gate says `sales_tax`, with the salesTax feature on: the
-- price quoted is net, 0434), `included` where it contains the tax (a VAT-
-- registered business: every amount is gross, 0142), `none` where no tax
-- applies. Nothing is converted: each price carries its own currency.
--
-- The card and its search text come from ONE projection: the search text is
-- built from the card actually published, so a private business without a
-- published page keeps its minimal card (name, address, host type) and none
-- of its service names reaches the search. A service, a kind setting, the
-- VAT regime or the country changing refreshes the card in the same
-- transaction.

-- ── 1. what the listed price means ───────────────────────────────────────
create or replace function public.public_workspace_tax_treatment(p_workspace uuid)
returns text language sql stable security definer set search_path = public as $fn$
  select case
    when coalesce(public.issuing_gate_of(public.eu_country_code(w.country_code)) ->> 'tax_system',
                  'vat') = 'sales_tax'
         and public.feature_effective(w.id, 'salesTax') then 'excluded'
    when w.vat_regime = 'vat_registered' then 'included'
    else 'none'
  end
  from public.workspaces w
  where w.id = p_workspace;
$fn$;
revoke execute on function public.public_workspace_tax_treatment(uuid) from public, anon, authenticated;

-- ── 2. what the business is and offers ───────────────────────────────────
-- A setting's effective text (the workspace's, else the platform's, else the
-- definition's default), read for the card: a card is refreshed by whoever
-- changed something, member or not, so setting_value's membership gate does
-- not apply here.
create or replace function public.public_workspace_setting_text(p_workspace uuid, p_key text)
returns text language sql stable security definer set search_path = public as $fn$
  select coalesce(
    (select s.value from public.setting_values s
      where s.scope = 'workspace' and s.workspace_id = p_workspace and s.key = p_key and s.valid_to is null),
    (select s.value from public.setting_values s
      where s.scope = 'platform' and s.key = p_key and s.valid_to is null),
    (select d.default_value from public.setting_definitions d where d.key = p_key)) #>> '{}';
$fn$;
revoke execute on function public.public_workspace_setting_text(uuid, text) from public, anon, authenticated;

create or replace function public.public_workspace_offer(p_workspace uuid)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
    'kinds', coalesce((
      select jsonb_agg(k.code order by k.at)
        from (select code, min(at) as at
                from (select nullif(btrim(public.public_workspace_setting_text(p_workspace, 'business.kind')), '') as code,
                             0::bigint as at
                      union all
                      select nullif(btrim(t.c), ''), t.n
                        from unnest(string_to_array(
                               coalesce(public.public_workspace_setting_text(p_workspace, 'business.more_kinds'), ''),
                               ',')) with ordinality as t(c, n)) codes
               where code is not null
               group by code) k), '[]'::jsonb),
    'services', coalesce((
      select jsonb_agg(s.item order by s.sort_order, s.id)
        from (select sv.sort_order, sv.id,
                     jsonb_strip_nulls(jsonb_build_object(
                       'name', sv.name,
                       'category', nullif(btrim(sv.category), ''),
                       'duration_minutes', sv.duration_minutes,
                       'price_minor', sv.price_cents,
                       'currency', w.currency_code,
                       'tax_treatment', public.public_workspace_tax_treatment(w.id))) as item
                from public.services sv
                join public.workspaces w on w.id = sv.workspace_id
               where sv.workspace_id = p_workspace and sv.active and sv.is_public
               order by sv.sort_order, sv.id
               limit 12) s), '[]'::jsonb),
    'takes_inquiries', public.feature_effective(p_workspace, 'spaceInquiries'));
$fn$;
revoke execute on function public.public_workspace_offer(uuid) from public, anon, authenticated;

-- ── 3. the document (0369, restated whole: the offer joins it last) ──────
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
     (m.is_owner or (m.is_admin and c.visible))), '[]'::jsonb))
  || public.public_workspace_offer(w.id))
 from public.workspaces w
 left join public.workspace_public_pages page on page.workspace_id = w.id
 cross join lateral (select public.workspace_public_defaults(w.id) as d) defaults
 where w.id = p_workspace;
$$;
revoke execute on function public.public_workspace_document(uuid) from public, anon, authenticated;

-- ── 4. the card: its search text from the card itself ─────────────────────
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
          w.name || ' ' || coalesce(card ->> 'address', '')
            || coalesce(' ' || (select string_agg(concat_ws(' ', sv ->> 'name', sv ->> 'category'), ' ')
                                  from jsonb_array_elements(coalesce(card -> 'services', '[]'::jsonb)) sv), ''),
          card
     from public.workspaces w
     cross join lateral (select public.public_workspace_document(w.id) as doc) d
     cross join lateral (
       select case when w.visibility = 'private'
                        and not exists (select 1 from public.workspace_public_pages p
                                         where p.workspace_id = w.id and p.published)
                   then jsonb_build_object('name', d.doc -> 'name', 'address', d.doc -> 'address',
                                           'host_type', d.doc -> 'host_type')
                   else d.doc end as card) c
    where w.id = p_workspace
   on conflict (workspace_id) do update
     set name = excluded.name, search_text = excluded.search_text,
         document = excluded.document, updated_at = now();
 else delete from public.public_workspace_cards where workspace_id = p_workspace; end if;
end;
$$;
revoke execute on function public.refresh_public_workspace_card(uuid) from public, anon, authenticated;

-- ── 5. what refreshes a card (0305, restated whole) ───────────────────────
create or replace function public.refresh_public_profile_cards() returns trigger
language plpgsql security definer set search_path=public as $$
declare v_workspace uuid; v_row jsonb;
begin
 v_row:=case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
 if tg_table_name='workspaces' then
  perform public.refresh_public_workspace_card((v_row->>'id')::uuid);
 elsif tg_table_name in ('workspace_public_pages','members','services','setting_values') then
  -- A platform-wide setting names no workspace.
  if v_row->>'workspace_id' is not null then
   perform public.refresh_public_workspace_card((v_row->>'workspace_id')::uuid);
  end if;
 else
  for v_workspace in select distinct workspace_id from public.members where
   (tg_table_name='member_public_contact' and id=(v_row->>'member_id')::uuid)
   or (tg_table_name='account_contact_settings' and user_id=(v_row->>'user_id')::uuid)
   or (tg_table_name='profiles' and user_id=(v_row->>'id')::uuid) loop
   perform public.refresh_public_workspace_card(v_workspace);
  end loop;
 end if;
 return null;
end;
$$;
revoke execute on function public.refresh_public_profile_cards() from public,anon,authenticated;

drop trigger if exists refresh_public_services on public.services;
create trigger refresh_public_services after insert or update or delete on public.services
 for each row execute function public.refresh_public_profile_cards();

drop trigger if exists refresh_public_kinds on public.setting_values;
create trigger refresh_public_kinds after insert or update on public.setting_values
 for each row when (new.key in ('business.kind', 'business.more_kinds'))
 execute function public.refresh_public_profile_cards();
drop trigger if exists refresh_public_kinds_removed on public.setting_values;
create trigger refresh_public_kinds_removed after delete on public.setting_values
 for each row when (old.key in ('business.kind', 'business.more_kinds'))
 execute function public.refresh_public_profile_cards();

-- The workspace trigger also watches what the tax treatment is read from.
drop trigger if exists refresh_public_workspace on public.workspaces;
create trigger refresh_public_workspace after update of name, feature_flags, booking_rules,
 currency_code, address, street, postal_code, city, invoice_legal, visibility, visibility_set_at,
 vat_regime, country_code
 on public.workspaces for each row execute function public.refresh_public_profile_cards();

-- ── 6. every card rebuilt once ────────────────────────────────────────────
select public.refresh_public_workspace_card(w.id) from public.workspaces w
 where w.visibility_set_at is not null
    or exists (select 1 from public.public_workspace_cards c where c.workspace_id = w.id);

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(790);
