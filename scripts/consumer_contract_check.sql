-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3731 (K4) — the body of the consumer-contract check. scripts/consumer_contract_check.sh prepends
--   with c as (select $cc$<the contract JSON>$cc$::jsonb as j),
-- and runs the whole as one read-only query. Each row is one thing a released app needs that the schema no
-- longer gives it: a function that is gone, a function whose definitions no longer accept the parameters the app
-- sends (a parameter removed, or a new one without a default), a table or view that is gone, a column that is gone.
fns as (
  select f.key as fn, f.value as sent from c, jsonb_each(c.j -> 'functions') f
),
procs as (
  select p.oid, p.proname,
         (select coalesce(array_agg(a.n order by a.i), '{}')
            from unnest(coalesce(p.proargnames, '{}'), coalesce(p.proargmodes, array_fill('i'::"char", array[cardinality(coalesce(p.proargnames, '{}'))])))
                 with ordinality as a(n, m, i)
           where a.m in ('i', 'b', 'v')) as inputs,
         p.pronargs, p.pronargdefaults
    from pg_proc p join pg_namespace s on s.oid = p.pronamespace
   where s.nspname = 'public'
),
fn_gone as (
  select 'function ' || fn || ': gone' as msg, fn as obj from fns
   where not exists (select 1 from procs where proname = fns.fn)
     -- the app reads an installation without it as an answer
     and fns.fn not in (select jsonb_array_elements_text(coalesce(j -> 'optional', '[]')) from c)
),
fn_params as (
  -- one row per call site's parameter set: each must be accepted by some definition on its own
  select 'function ' || fns.fn || ': no definition accepts the parameters one call sends ('
           || coalesce((select string_agg(x, ', ' order by x) from jsonb_array_elements_text(s.set) x), 'none') || ')' as msg,
         fns.fn as obj
    from fns, jsonb_array_elements(case when jsonb_typeof(fns.sent) = 'array' then fns.sent else '[]' end) s(set)
   where exists (select 1 from procs where proname = fns.fn)
     and not exists (
       select 1 from procs pr
        where pr.proname = fns.fn
          -- every parameter this call sends is a named input of this definition
          and not exists (
            select 1 from jsonb_array_elements_text(s.set) x
             where not coalesce(x = any(array_remove(pr.inputs, null)), false))
          -- every input without a default is sent by this call
          and not exists (
            select 1 from generate_series(1, pr.pronargs - pr.pronargdefaults) i
             where not coalesce(pr.inputs[i] in (select jsonb_array_elements_text(s.set)), false))
     )
),
rels as (
  select t.key as rel, t.value as cols from c, jsonb_each(c.j -> 'tables') t
),
rel_gone as (
  select 'table ' || rel || ': gone' as msg, rel as obj from rels
   where not exists (
     select 1 from pg_class k join pg_namespace s on s.oid = k.relnamespace
      where s.nspname = 'public' and k.relname = rels.rel and k.relkind in ('r', 'v', 'm', 'p', 'f'))
),
col_gone as (
  select 'column ' || rel || '.' || col || ': gone' as msg, rel as obj
    from rels, jsonb_array_elements_text(case when jsonb_typeof(rels.cols) = 'array' then rels.cols else '[]' end) col
   where exists (
     select 1 from pg_class k join pg_namespace s on s.oid = k.relnamespace
      where s.nspname = 'public' and k.relname = rels.rel)
     and not exists (
       select 1 from pg_attribute a join pg_class k on k.oid = a.attrelid join pg_namespace s on s.oid = k.relnamespace
        where s.nspname = 'public' and k.relname = rels.rel and a.attname = col and a.attnum > 0 and not a.attisdropped)
)
select msg, obj from fn_gone
union all select msg, obj from fn_params
union all select msg, obj from rel_gone
union all select msg, obj from col_gone
order by 1;
