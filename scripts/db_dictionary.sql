-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1911 — the authoritative data dictionary, read from the CATALOGUES.
--
-- One read-only SELECT over pg_class, pg_attribute, pg_constraint,
-- pg_index, pg_inherits and pg_type for the application schema (`public`).
-- It reads no table row, no function body and no view definition; it is
-- never derived from Dart models or from CREATE TABLE statements, so a
-- column added by the ninth ALTER of a table is in it exactly once.
--
-- Not in the output: pg_catalog, information_schema, pg_toast, objects an
-- extension owns, and the managed schemas (auth, storage, realtime, ...)
-- whose shape belongs to the platform version, not to a migration. A
-- foreign key INTO a managed table stays in the dictionary as a reference.
-- Defaults of columns whose name says secret, token, password, API or
-- private key, credential, vault, e-mail, phone, IBAN, first or last name are redacted to
-- '<redacted>' — a default may be a personal or secret literal.
--
-- Run by scripts/db_dictionary.sh (operator export and CI). Output: one
-- jsonb_pretty document, byte-stable for one schema; a null field is absent.
with
rel as (
  select c.oid, c.relname as name, c.relkind, c.relispartition,
         obj_description(c.oid, 'pg_class') as comment
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relkind in ('r', 'p', 'v', 'm', 'f')
     and not exists (
       select 1 from pg_depend d
        where d.classid = 'pg_class'::regclass and d.objid = c.oid
          and d.deptype = 'e')
),
col as (
  select a.attrelid as oid,
         jsonb_agg(jsonb_build_object(
           'position', a.pos,
           'name', a.attname,
           'type', format_type(a.atttypid, a.atttypmod),
           'notNull', a.attnotnull,
           'identity', nullif(a.attidentity::text, ''),
           'generated', nullif(a.attgenerated::text, ''),
           'default', case
             when ad.adbin is null then null
             when a.attname ~* '(secret|token|passw|credential|api_?key|private_?key|vault|e_?mail|phone|iban|first_?name|last_?name)'
               then '<redacted>'
             else pg_get_expr(ad.adbin, ad.adrelid) end,
           'comment', col_description(a.attrelid, a.attnum)
         ) order by a.pos) as columns
    from (
      select a.*, row_number() over (partition by a.attrelid order by a.attnum) as pos
        from pg_attribute a
       where a.attnum > 0 and not a.attisdropped
         and a.attrelid in (select oid from rel)
    ) a
    left join pg_attrdef ad on ad.adrelid = a.attrelid and ad.adnum = a.attnum
   group by a.attrelid
),
con as (
  select k.conrelid as oid,
         jsonb_agg(
           jsonb_build_object(
             'name', k.conname,
             'type', case k.contype when 'p' then 'primary key' when 'u' then 'unique'
                     when 'f' then 'foreign key' when 'c' then 'check' when 'x' then 'exclusion' end,
             'columns', (select coalesce(jsonb_agg(att.attname order by u.ord), '[]'::jsonb)
                           from unnest(k.conkey) with ordinality u(attnum, ord)
                           join pg_attribute att on att.attrelid = k.conrelid and att.attnum = u.attnum),
             'definition', pg_get_constraintdef(k.oid),
             'validated', k.convalidated,
             'deferrable', k.condeferrable,
             'inherited', k.conparentid <> 0
           ) || case when k.contype = 'f' then jsonb_build_object(
             'references', jsonb_build_object(
               'schema', rn.nspname,
               'table', rc.relname,
               'columns', (select coalesce(jsonb_agg(att.attname order by u.ord), '[]'::jsonb)
                             from unnest(k.confkey) with ordinality u(attnum, ord)
                             join pg_attribute att on att.attrelid = k.confrelid and att.attnum = u.attnum)),
             'onDelete', case k.confdeltype when 'a' then 'NO ACTION' when 'r' then 'RESTRICT'
                         when 'c' then 'CASCADE' when 'n' then 'SET NULL' when 'd' then 'SET DEFAULT' end,
             'onDeleteColumns', (select coalesce(jsonb_agg(att.attname order by u.ord), '[]'::jsonb)
                                   from unnest(coalesce(k.confdelsetcols, '{}'::int2[])) with ordinality u(attnum, ord)
                                   join pg_attribute att on att.attrelid = k.conrelid and att.attnum = u.attnum),
             'onUpdate', case k.confupdtype when 'a' then 'NO ACTION' when 'r' then 'RESTRICT'
                         when 'c' then 'CASCADE' when 'n' then 'SET NULL' when 'd' then 'SET DEFAULT' end,
             'match', case k.confmatchtype when 'f' then 'FULL' when 'p' then 'PARTIAL' else 'SIMPLE' end
           ) else '{}'::jsonb end
           order by k.conname) as constraints
    from pg_constraint k
    left join pg_class rc on rc.oid = k.confrelid
    left join pg_namespace rn on rn.oid = rc.relnamespace
   where k.conrelid in (select oid from rel)
     and k.contype in ('p', 'u', 'f', 'c', 'x')
   group by k.conrelid
),
idx as (
  select i.indrelid as oid,
         jsonb_agg(jsonb_build_object(
           'name', ic.relname,
           'unique', i.indisunique,
           'primary', i.indisprimary,
           'valid', i.indisvalid,
           'definition', pg_get_indexdef(i.indexrelid)
         ) order by ic.relname) as indexes
    from pg_index i
    join pg_class ic on ic.oid = i.indexrelid
   where i.indrelid in (select oid from rel)
   group by i.indrelid
),
objects as (
  select jsonb_strip_nulls(coalesce(jsonb_agg(
           jsonb_build_object(
             'schema', 'public',
             'name', r.name,
             'kind', case r.relkind when 'r' then case when r.relispartition then 'partition' else 'table' end
                     when 'p' then 'partitioned table' when 'v' then 'view'
                     when 'm' then 'materialized view' when 'f' then 'foreign table' end,
             'comment', r.comment,
             'columns', coalesce(col.columns, '[]'::jsonb),
             'constraints', coalesce(con.constraints, '[]'::jsonb),
             'indexes', coalesce(idx.indexes, '[]'::jsonb)
           )
           || case when r.relkind = 'p' then jsonb_build_object('partitionKey', pg_get_partkeydef(r.oid)) else '{}'::jsonb end
           || case when r.relispartition then jsonb_build_object(
                'partitionOf', (select pc.relname from pg_inherits h join pg_class pc on pc.oid = h.inhparent where h.inhrelid = r.oid),
                'partitionBound', (select pg_get_expr(c2.relpartbound, c2.oid) from pg_class c2 where c2.oid = r.oid)
              ) else '{}'::jsonb end
           order by r.name), '[]'::jsonb)) as j
    from rel r
    left join col on col.oid = r.oid
    left join con on con.oid = r.oid
    left join idx on idx.oid = r.oid
),
types as (
  select coalesce(jsonb_agg(
           case t.typtype
             when 'e' then jsonb_build_object('schema', 'public', 'name', t.typname, 'kind', 'enum',
                'labels', (select jsonb_agg(e.enumlabel order by e.enumsortorder) from pg_enum e where e.enumtypid = t.oid))
             else jsonb_build_object('schema', 'public', 'name', t.typname, 'kind', 'domain',
                'baseType', format_type(t.typbasetype, t.typtypmod),
                'notNull', t.typnotnull,
                'checks', (select coalesce(jsonb_agg(pg_get_constraintdef(k.oid) order by k.conname), '[]'::jsonb)
                             from pg_constraint k where k.contypid = t.oid))
           end order by t.typname), '[]'::jsonb) as j
    from pg_type t
   where t.typnamespace = 'public'::regnamespace
     and t.typtype in ('e', 'd')
     and not exists (
       select 1 from pg_depend d
        where d.classid = 'pg_type'::regclass and d.objid = t.oid and d.deptype = 'e')
)
select jsonb_pretty(jsonb_build_object(
  'format', 1,
  'meta', jsonb_build_object(
    'source', 'PostgreSQL catalogues (pg_class, pg_attribute, pg_constraint, pg_index, pg_inherits, pg_type) of the migration replay',
    'applicationSchema', 'public',
    'schemaMarker', (select public.deskilo_schema_version()),
    'postgresMajor', current_setting('server_version_num')::int / 10000,
    'excluded', jsonb_build_array(
      'pg_catalog', 'information_schema', 'pg_toast',
      'objects owned by an extension',
      'managed platform schemas (auth, storage, realtime, ...): version-qualified, not application migrations',
      'row values, function bodies, view definitions'),
    'counts', jsonb_build_object(
      'tables', (select count(*) from jsonb_array_elements(objects.j) o where o->>'kind' in ('table', 'partitioned table')),
      'partitions', (select count(*) from jsonb_array_elements(objects.j) o where o->>'kind' = 'partition'),
      'views', (select count(*) from jsonb_array_elements(objects.j) o where o->>'kind' in ('view', 'materialized view')),
      'columns', (select coalesce(sum(jsonb_array_length(o->'columns')), 0) from jsonb_array_elements(objects.j) o),
      'foreignKeys', (select count(*) from jsonb_array_elements(objects.j) o, jsonb_array_elements(o->'constraints') k where k->>'type' = 'foreign key'),
      'enums', (select count(*) from jsonb_array_elements(types.j) t where t->>'kind' = 'enum'),
      'domains', (select count(*) from jsonb_array_elements(types.j) t where t->>'kind' = 'domain')),
    'checksum', encode(sha256(convert_to(objects.j::text || types.j::text, 'UTF8')), 'hex')),
  'objects', objects.j,
  'types', types.j)) as dictionary
from objects, types;
