-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0438 (#2565, Refs #2539) — confirm and withdraw a tax_reference version.
--
-- set_tax_reference (0427) only appends. A planned change of law (a future
-- version, confirmed = false) must become confirmed once the law passes, or
-- be withdrawn when it does not come into force; until now neither was
-- possible. Confirming is the one permitted update (it changes no value); a
-- withdrawal deletes only a version that is still in the future and was never
-- confirmed, and reopens its predecessor. A value that was in force is
-- history: it is only superseded. Both are platform-owner acts (not
-- delegated), serialised with set_tax_reference by the same advisory lock,
-- and both leave a row in database_authority_audit.

create or replace function public.confirm_tax_reference(p_id uuid, p_source text default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_row public.tax_reference;
  v_extra text := btrim(coalesce(p_source, ''));
begin
  if auth.uid() is null or public.mcp_is_delegated() or not public.is_platform_owner() then
    raise exception 'platform owners only';
  end if;
  select * into v_row from public.tax_reference where id = p_id;
  if not found then raise exception 'unknown version'; end if;
  perform pg_advisory_xact_lock(hashtextextended(
    'tax_reference:' || v_row.domain || ':' || v_row.country || ':' || v_row.key, 0));
  select * into v_row from public.tax_reference where id = p_id for update;
  if not found then raise exception 'unknown version'; end if;
  if v_row.confirmed then raise exception 'the version is already confirmed'; end if;

  update public.tax_reference
     set confirmed = true,
         source = case when v_extra = '' then source else source || ' | confirmed: ' || v_extra end
   where id = p_id
  returning * into v_row;

  insert into public.database_authority_audit (installation_id, action, actor, detail)
  values (public.installation_id(), 'tax_reference_confirm', 'platform_owner:' || auth.uid(),
          jsonb_build_object('id', v_row.id, 'domain', v_row.domain, 'country', v_row.country,
                             'key', v_row.key, 'valid_from', v_row.valid_from,
                             'source', v_row.source));

  return jsonb_build_object('id', v_row.id, 'domain', v_row.domain, 'country', v_row.country,
                            'key', v_row.key, 'valid_from', v_row.valid_from, 'valid_to', v_row.valid_to,
                            'value', v_row.value, 'source', v_row.source, 'confirmed', v_row.confirmed);
end;
$fn$;
revoke execute on function public.confirm_tax_reference(uuid, text) from public, anon;
grant execute on function public.confirm_tax_reference(uuid, text) to authenticated;

create or replace function public.withdraw_tax_reference(p_id uuid, p_reason text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_row public.tax_reference;
  v_prev public.tax_reference;
  v_next date;
begin
  if auth.uid() is null or public.mcp_is_delegated() or not public.is_platform_owner() then
    raise exception 'platform owners only';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'a reason is required';
  end if;
  select * into v_row from public.tax_reference where id = p_id;
  if not found then raise exception 'unknown version'; end if;
  perform pg_advisory_xact_lock(hashtextextended(
    'tax_reference:' || v_row.domain || ':' || v_row.country || ':' || v_row.key, 0));
  select * into v_row from public.tax_reference where id = p_id for update;
  if not found then raise exception 'unknown version'; end if;
  if v_row.confirmed then
    raise exception 'a confirmed version is history and is only superseded';
  end if;
  if v_row.valid_from <= current_date then
    raise exception 'a version already in force is history and is only superseded';
  end if;

  delete from public.tax_reference where id = p_id;

  -- The predecessor was closed on this version's first day: it runs on
  -- until the next later version, or stays open.
  select * into v_prev from public.tax_reference t
   where t.domain = v_row.domain and t.country = v_row.country and t.key = v_row.key
     and t.valid_from < v_row.valid_from
   order by t.valid_from desc limit 1;
  if found and v_prev.valid_to = v_row.valid_from then
    select min(t.valid_from) into v_next from public.tax_reference t
     where t.domain = v_row.domain and t.country = v_row.country and t.key = v_row.key
       and t.valid_from > v_row.valid_from;
    update public.tax_reference set valid_to = v_next where id = v_prev.id;
  end if;

  insert into public.database_authority_audit (installation_id, action, actor, detail)
  values (public.installation_id(), 'tax_reference_withdraw', 'platform_owner:' || auth.uid(),
          jsonb_build_object('reason', btrim(p_reason), 'version', to_jsonb(v_row)));

  return jsonb_build_object('id', v_row.id, 'domain', v_row.domain, 'country', v_row.country,
                            'key', v_row.key, 'valid_from', v_row.valid_from);
end;
$fn$;
revoke execute on function public.withdraw_tax_reference(uuid, text) from public, anon;
grant execute on function public.withdraw_tax_reference(uuid, text) to authenticated;

select public.set_deskilo_schema_version(438);
