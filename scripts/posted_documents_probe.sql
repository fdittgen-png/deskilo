-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #4492 row 4 -- the forbidden writes, attempted. scripts/posted_documents_check.sh
-- runs this INSIDE the still-open transaction of a pgTAP file, after that file's
-- last assertion: the rows the file posted (issued invoices, finalized receipts,
-- closed tills and days, stock movements, postings) are all there, and everything
-- rolls back with the file.
--
-- For every posted-document table that holds a posted row, and as each of three
-- callers -- the owner of the business under row-level security, the same owner
-- through a delegated (assistant) token, and the server's own role, which no
-- policy restrains -- it tries: an UPDATE of every column, one column at a time; a
-- DELETE; a TRUNCATE, plain and cascading; and, for the two signed-in callers, the
-- INSERT of a copy under a new id. Each attempt runs in a subtransaction that is
-- rolled back, and is answered by what it did to the posted rows:
--
--   changed   the posted rows are no longer what they were (a digest of every
--             column except the creation and modification stamps)
--   same      the statement reached rows and left them as they were
--   norows    the statement ran and reached nothing (row-level security)
--   <state>   it raised: 42501 no privilege or a policy, P0001 and DK... a guard,
--             23... a constraint AFTER every guard had let it pass
--
-- One line per table, caller and answer: ZZPOSTED <tab> table <tab> posted rows
-- <tab> caller <tab> answer <tab> the attempts that got it.
reset role;
select set_config('request.jwt.claims', '', true);

create function pg_temp.zz_digest(p_table text, p_pred text) returns text language plpgsql as $f$
declare v text;
begin
  execute format(
    'select count(*)::text || '':'' || md5(coalesce(string_agg(s.x, '''' order by s.x), ''''))
       from (select md5((to_jsonb(t) - array[''created_datetime'', ''modified_datetime'',
                                             ''created_by_user'', ''modified_by_user'', ''company_id''])::text) as x
               from public.%I t where %s) s', p_table, p_pred) into v;
  return v;
end
$f$;

create function pg_temp.zz_attempt(p_role text, p_claims text, p_sql text, p_table text, p_pred text, p_before text)
returns text language plpgsql as $f$
declare
  v_n bigint;
  v_out text;
begin
  begin
    perform set_config('request.jwt.claims', coalesce(p_claims, ''), true);
    execute format('set local role %I', p_role);
    execute p_sql;
    get diagnostics v_n = row_count;
    reset role;
    perform set_config('request.jwt.claims', '', true);
    v_out := case when pg_temp.zz_digest(p_table, p_pred) is distinct from p_before then 'changed'
                  when v_n > 0 then 'same' else 'norows' end;
    raise exception 'zz-rollback' using errcode = 'ZZ000';
  exception
    when sqlstate 'ZZ000' then null;
    when others then v_out := sqlstate;
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v_out;
end
$f$;

create function pg_temp.zz_posted_probe() returns setof text language plpgsql as $f$
declare
  -- the posted documents, and which of their rows are posted
  c_tables constant jsonb := '{
    "invoices": "true",
    "invoice_originals": "true",
    "invoice_line_tracks": "true",
    "invoice_match_history": "true",
    "ledger_entries": "true",
    "counter_receipts": "t.state = ''finalized''",
    "counter_receipt_lines": "t.receipt_id in (select r.id from public.counter_receipts r where r.state = ''finalized'')",
    "counter_tenders": "t.receipt_id in (select r.id from public.counter_receipts r where r.state = ''finalized'')",
    "counter_refunds": "true",
    "counter_receipt_copies": "true",
    "counter_cash_entries": "true",
    "counter_till_sessions": "t.state = ''closed''",
    "counter_day_closes": "true",
    "counter_offline_sales": "true",
    "stock_movements": "true",
    "stock_movement_units": "true",
    "stock_movement_handling_units": "true",
    "stock_returns": "true",
    "stock_reversals": "true",
    "verifactu_records": "true",
    "vat_return_entries": "true"
  }';
  r record;
  a record;
  v_rows bigint;
  v_before text;
  v_owner uuid;
  v_claims text;
  v_expr text;
  v_cols text;
  v_vals text;
  v_role text;
  v_pg_role text;
  v_out text;
  v_answers jsonb;
  v_key text;
begin
  for r in select e.key as tbl, e.value as pred from jsonb_each_text(c_tables) e order by e.key loop
    if to_regclass('public.' || r.tbl) is null then continue; end if;
    begin
      execute format('select count(*) from public.%I t where %s', r.tbl, r.pred) into v_rows;
    exception when others then
      return next concat_ws(E'\t', 'ZZPOSTED', r.tbl, '0', 'probe', sqlstate, 'count');
      continue;
    end;
    if v_rows = 0 then continue; end if;
    v_before := pg_temp.zz_digest(r.tbl, r.pred);
    v_owner := null;
    if exists (select 1 from pg_attribute where attrelid = to_regclass('public.' || r.tbl)
                  and attname = 'workspace_id' and not attisdropped) then
      execute format(
        'select m.user_id from public.members m
          where m.is_owner and m.user_id is not null
            and m.workspace_id in (select t.workspace_id from public.%I t where %s)
          order by m.user_id limit 1', r.tbl, r.pred) into v_owner;
    end if;
    foreach v_role in array array['server', 'owner', 'delegated'] loop
      if v_role <> 'server' and v_owner is null then
        return next concat_ws(E'\t', 'ZZPOSTED', r.tbl, v_rows::text, v_role, 'no_owner', 'all');
        continue;
      end if;
      v_pg_role := case when v_role = 'server' then 'service_role' else 'authenticated' end;
      v_claims := case v_role
        when 'owner' then jsonb_build_object('sub', v_owner, 'role', 'authenticated', 'aal', 'aal2')::text
        when 'delegated' then jsonb_build_object('sub', v_owner, 'role', 'authenticated', 'aal', 'aal2',
                                                 'client_id', 'assistant')::text
        else null end;
      v_answers := '{}'::jsonb;
      v_cols := null;
      v_vals := null;
      for a in select att.attname, att.attidentity, format_type(att.atttypid, att.atttypmod) as typ,
                      ty.typcategory, ty.typname, bt.typname as base_name
                 from pg_attribute att
                 join pg_type ty on ty.oid = att.atttypid
                 left join pg_type bt on bt.oid = ty.typbasetype
                where att.attrelid = to_regclass('public.' || r.tbl) and att.attnum > 0
                  and not att.attisdropped and att.attgenerated = ''
                order by att.attnum loop
        if a.attidentity <> 'a' then
          v_cols := concat_ws(', ', v_cols, format('%I', a.attname));
          v_vals := concat_ws(', ', v_vals,
            case when a.attname = 'id' and a.typname = 'uuid' then 'gen_random_uuid()'
                 else format('t.%I', a.attname) end);
        end if;
        v_expr := case
          when coalesce(a.base_name, a.typname) = 'uuid' then 'gen_random_uuid()'
          when coalesce(a.base_name, a.typname) = 'jsonb'
            then format('coalesce(t.%I, ''{}''::jsonb) || ''{"zz": 1}''::jsonb', a.attname)
          when coalesce(a.base_name, a.typname) = 'bytea'
            then format('coalesce(t.%I, ''''::bytea) || ''\x00''::bytea', a.attname)
          when a.typcategory = 'S' then format('(coalesce(t.%I::text, '''') || ''~'')::%s', a.attname, a.typ)
          when a.typcategory = 'N' then format('coalesce(t.%I, 0) + 1', a.attname)
          when a.typcategory = 'B' then format('not coalesce(t.%I, false)', a.attname)
          when a.typcategory = 'D'
            then format('(coalesce(t.%I, now()::%s) + interval ''1 day 1 second'')::%s', a.attname, a.typ, a.typ)
          when a.typcategory = 'A' then format('array_append(t.%I, null)', a.attname)
          else format('case when t.%I is null then t.%I else null end', a.attname, a.attname)
        end;
        v_out := pg_temp.zz_attempt(v_pg_role, v_claims,
          format('update public.%I t set %I = %s where %s', r.tbl, a.attname, v_expr, r.pred),
          r.tbl, r.pred, v_before);
        v_answers := jsonb_set(v_answers, array[v_out],
          coalesce(v_answers -> v_out, '[]'::jsonb) || to_jsonb('update:' || a.attname));
      end loop;
      v_out := pg_temp.zz_attempt(v_pg_role, v_claims,
        format('delete from public.%I t where %s', r.tbl, r.pred), r.tbl, r.pred, v_before);
      v_answers := jsonb_set(v_answers, array[v_out], coalesce(v_answers -> v_out, '[]'::jsonb) || '"delete"'::jsonb);
      v_out := pg_temp.zz_attempt(v_pg_role, v_claims,
        format('truncate table public.%I', r.tbl), r.tbl, r.pred, v_before);
      v_answers := jsonb_set(v_answers, array[v_out], coalesce(v_answers -> v_out, '[]'::jsonb) || '"truncate"'::jsonb);
      v_out := pg_temp.zz_attempt(v_pg_role, v_claims,
        format('truncate table public.%I cascade', r.tbl), r.tbl, r.pred, v_before);
      v_answers := jsonb_set(v_answers, array[v_out], coalesce(v_answers -> v_out, '[]'::jsonb) || '"truncate_cascade"'::jsonb);
      if v_role <> 'server' then
        v_out := pg_temp.zz_attempt(v_pg_role, v_claims,
          format('insert into public.%I (%s) select %s from public.%I t where %s limit 1',
                 r.tbl, v_cols, v_vals, r.tbl, r.pred), r.tbl, r.pred, v_before);
        v_answers := jsonb_set(v_answers, array[v_out], coalesce(v_answers -> v_out, '[]'::jsonb) || '"insert"'::jsonb);
      end if;
      for v_key in select k from jsonb_object_keys(v_answers) k order by k loop
        return next concat_ws(E'\t', 'ZZPOSTED', r.tbl, v_rows::text, v_role, v_key,
          (select string_agg(x, ',' order by x) from jsonb_array_elements_text(v_answers -> v_key) x));
      end loop;
    end loop;
  end loop;
end
$f$;

select pg_temp.zz_posted_probe();
