-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (one new function and a composite key on services.vat_rate_id; no row changes: none crosses businesses, read-only check on dev)
--
-- #4376 -- creating a service is safe to retry. The Services page and the "Create a new item" sheet of the Stock
-- page inserted the row with no request id: a lost answer followed by a retry made a second service. The create
-- now goes through one command that carries a request id, on the idempotency record of the purchases
-- (`purchase_request_begin` / `purchase_request_end`, 0461): the same id with the same content answers the first
-- service and creates nothing; the same id with other content is refused in words ("this request id was already
-- used for a different request"); the record is per business, so another business neither replays nor reads it.
-- The permission is the one the table's policy already asked for, `manageServices`; an assistant is refused.
-- A service's VAT rate belongs to its business: the command refuses another business's rate with a typed refusal
-- (DKG11, field vat_rate_id, reason vat_rate_unknown), and a composite key makes the table say the same for every
-- other way in (the rows of a business and the rates it names are one business's).

-- audience: all row readers
create or replace function public.create_service_v1(p_workspace_id uuid, p_request_id uuid, p_service jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_allowed constant text[] := array['name', 'price_cents', 'vat_rate_id', 'supply_class', 'description',
                                     'duration_minutes', 'category', 'is_public'];
  v_key text;
  v_name text;
  v_digest text;
  v_done jsonb;
  v_row public.services;
  v_result jsonb;
begin
  if auth.uid() is null or public.mcp_is_delegated() or not public.has_permission(p_workspace_id, 'manageServices') then
    raise exception 'not allowed to create a service' using errcode = 'DKN01';
  end if;
  if p_request_id is null or coalesce(jsonb_typeof(p_service), '') <> 'object' then
    raise exception 'a service is created with a request id and its fields' using errcode = '22023';
  end if;
  for v_key in select jsonb_object_keys(p_service) loop
    if not (v_key = any (v_allowed)) then
      raise exception 'a service has no field called %', v_key using errcode = '22023';
    end if;
  end loop;
  v_name := btrim(coalesce(p_service ->> 'name', ''));
  if v_name = '' then
    raise exception 'a service needs a name' using errcode = '22023';
  end if;
  -- a service's VAT rate belongs to its business: an active rate of p_workspace_id
  if nullif(p_service ->> 'vat_rate_id', '') is not null
     and not exists (select 1 from public.vat_rates r
                      where r.id = nullif(p_service ->> 'vat_rate_id', '')::uuid and r.workspace_id = p_workspace_id and r.active) then
    perform public.stock_config_refuse('vat_rate_id', 'vat_rate_unknown');
  end if;
  v_digest := md5(p_service::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'service_create', v_digest);
  if v_done is not null then
    return v_done;
  end if;
  insert into public.services (workspace_id, name, price_cents, vat_rate_id, supply_class, description,
                               duration_minutes, category, is_public)
  values (p_workspace_id, v_name, coalesce((p_service ->> 'price_cents')::int, 0),
          nullif(p_service ->> 'vat_rate_id', '')::uuid,
          coalesce(nullif(p_service ->> 'supply_class', ''), 'property'),
          nullif(p_service ->> 'description', ''), (p_service ->> 'duration_minutes')::int,
          nullif(p_service ->> 'category', ''), coalesce((p_service ->> 'is_public')::boolean, false))
  returning * into v_row;
  select jsonb_object_agg(e.key, e.value) into v_result
    from jsonb_each(to_jsonb(v_row)) e
   where e.key = any (array['id', 'workspace_id', 'name', 'price_cents', 'active', 'vat_rate_id', 'stock', 'supply_class',
                            'description', 'duration_minutes', 'category', 'is_public', 'sort_order'] || public.system_column_names());
  return public.purchase_request_end(p_workspace_id, p_request_id, 'service_create', v_digest, v_result);
end;
$fn$;
revoke execute on function public.create_service_v1(uuid, uuid, jsonb) from public, anon;
grant execute on function public.create_service_v1(uuid, uuid, jsonb) to authenticated;

-- ── the key says it too ───────────────────────────────────────────────
alter table public.vat_rates add constraint vat_rates_workspace_id_id_key unique (workspace_id, id);
do $fk$
declare
  v_name text;
begin
  select c.conname into v_name from pg_constraint c
   where c.conrelid = 'public.services'::regclass and c.contype = 'f'
     and pg_get_constraintdef(c.oid) like 'FOREIGN KEY (vat_rate_id) REFERENCES vat_rates(id)%';
  if v_name is not null then
    execute format('alter table public.services drop constraint %I', v_name);
  end if;
end
$fk$;
alter table public.services add constraint services_vat_rate_of_workspace_fkey
  foreign key (workspace_id, vat_rate_id) references public.vat_rates (workspace_id, id) on delete set null (vat_rate_id);

select public.set_deskilo_schema_version(888);
