-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #4492 row 6 -- what an installation IS, one line per fact, read from the
-- catalogues of the database this runs in (scripts/upgrade_equivalence_check.sh
-- runs it in a fresh install and in an upgraded one and compares the two).
--
-- Wider than assets/instance/contract.txt (routines, constraints, triggers):
-- also every column with its type, default and position, every index, every
-- policy with its expressions, every grant on a table, a column, a function,
-- a type and a schema, the default privileges, the views, sequences and types,
-- the extensions, the publications, the storage buckets and the scheduled
-- jobs. A function is its whole definition (header, settings and body), not
-- only its body.
--
-- Lines starting with `data ` are the rows the migrations themselves seed
-- (tables without a workspace_id): a count and a digest per table, without
-- the system columns, identifiers and timestamps. They are compared as
-- advice, never as the gate: an installation's own rows live there too.
--
-- No object id reaches the output, and every name is printed schema-qualified
-- (the empty search_path), so two databases of one cluster print the same
-- text for the same thing.
set search_path = '';
set client_min_messages = warning;

create function pg_temp.acl(p_acl aclitem[], p_kind "char", p_owner oid) returns text
language sql stable as $f$
  select coalesce(string_agg(s.x, ',' order by s.x), '')
    from (select case when a.grantee = 0 then 'PUBLIC' else pg_catalog.pg_get_userbyid(a.grantee) end
                 || ':' || a.privilege_type || case when a.is_grantable then '*' else '' end as x
            from pg_catalog.aclexplode(coalesce(p_acl, pg_catalog.acldefault(p_kind, p_owner))) a) s
$f$;
-- one fact, one line
create function pg_temp.l(p text) returns text language sql immutable as $f$
  select pg_catalog.regexp_replace(p, '\s+', ' ', 'g')
$f$;
-- what an extension owns is the extension's, not the installation's
create function pg_temp.mine(p_class regclass, p_oid oid) returns boolean language sql stable as $f$
  select not exists (select 1 from pg_catalog.pg_depend d
                      where d.classid = p_class and d.objid = p_oid and d.deptype = 'e')
$f$;

select pg_temp.l('relation ' || c.relname || ' kind=' || c.relkind::text || ' owner=' || pg_get_userbyid(c.relowner)
       || ' rls=' || c.relrowsecurity::text || ' force=' || c.relforcerowsecurity::text
       || ' persistence=' || c.relpersistence::text
       || ' options=' || coalesce(array_to_string(c.reloptions, ','), '')
       || ' acl=' || pg_temp.acl(c.relacl, (case when c.relkind = 'S' then 's' else 'r' end)::"char", c.relowner))
  from pg_class c
 where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p', 'v', 'm', 'S', 'f')
   and pg_temp.mine('pg_class', c.oid);

select pg_temp.l('column ' || c.relname || '.' || a.attname
       || ' pos=' || (select count(*) from pg_attribute b
                       where b.attrelid = a.attrelid and b.attnum > 0 and not b.attisdropped
                         and b.attnum <= a.attnum)::text
       || ' type=' || format_type(a.atttypid, a.atttypmod)
       || ' notnull=' || a.attnotnull::text
       || ' default=' || coalesce(pg_get_expr(d.adbin, d.adrelid), '')
       || ' identity=' || a.attidentity::text || ' generated=' || a.attgenerated::text
       || ' collation=' || coalesce((select l.collname from pg_collation l join pg_type t on t.oid = a.atttypid
                                      where l.oid = a.attcollation and a.attcollation <> t.typcollation), '')
       || ' acl=' || pg_temp.acl(a.attacl, 'c', c.relowner))
  from pg_attribute a
  join pg_class c on c.oid = a.attrelid
  left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
 where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p', 'v', 'm', 'f')
   and a.attnum > 0 and not a.attisdropped and pg_temp.mine('pg_class', c.oid);

select pg_temp.l('constraint ' || coalesce(c.relname, t.typname, '') || ' ' || o.conname
       || ' type=' || o.contype::text || ' validated=' || o.convalidated::text
       || ' deferrable=' || o.condeferrable::text || '/' || o.condeferred::text
       || ' def=' || pg_get_constraintdef(o.oid))
  from pg_constraint o
  left join pg_class c on c.oid = o.conrelid
  left join pg_type t on t.oid = o.contypid
 where o.connamespace = 'public'::regnamespace;

select pg_temp.l('index ' || t.relname || ' ' || i.relname || ' valid=' || x.indisvalid::text
       || ' ready=' || x.indisready::text || ' def=' || pg_get_indexdef(x.indexrelid))
  from pg_index x
  join pg_class i on i.oid = x.indexrelid
  join pg_class t on t.oid = x.indrelid
 where t.relnamespace = 'public'::regnamespace and pg_temp.mine('pg_class', t.oid);

select pg_temp.l('policy ' || n.nspname || '.' || c.relname || ' ' || p.polname
       || ' cmd=' || p.polcmd::text || ' permissive=' || p.polpermissive::text
       || ' roles=' || (select coalesce(string_agg(s.x, ',' order by s.x), '')
                          from (select case when r = 0 then 'PUBLIC' else pg_get_userbyid(r) end as x
                                  from unnest(p.polroles) r) s)
       || ' using=' || coalesce(pg_get_expr(p.polqual, p.polrelid), '')
       || ' check=' || coalesce(pg_get_expr(p.polwithcheck, p.polrelid), ''))
  from pg_policy p
  join pg_class c on c.oid = p.polrelid
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname in ('public', 'storage');

select pg_temp.l('trigger ' || n.nspname || '.' || c.relname || ' ' || t.tgname
       || ' enabled=' || t.tgenabled::text || ' def=' || pg_get_triggerdef(t.oid))
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  join pg_namespace n on n.oid = c.relnamespace
  join pg_proc p on p.oid = t.tgfoid
 where not t.tgisinternal and (n.nspname = 'public' or p.pronamespace = 'public'::regnamespace);

select pg_temp.l('function ' || p.oid::regprocedure::text || ' kind=' || p.prokind::text
       || ' owner=' || pg_get_userbyid(p.proowner) || ' acl=' || pg_temp.acl(p.proacl, 'f', p.proowner)
       || ' def=' || case when p.prokind = 'a'
                          then 'aggregate:' || md5(concat_ws('|', a.aggtransfn::text, a.aggfinalfn::text,
                                                             a.aggtranstype::regtype::text, a.agginitval))
                          else md5(pg_get_functiondef(p.oid)) end)
  from pg_proc p
  left join pg_aggregate a on a.aggfnoid = p.oid
 where p.pronamespace = 'public'::regnamespace and pg_temp.mine('pg_proc', p.oid);

select pg_temp.l('view ' || c.relname || ' def=' || md5(pg_get_viewdef(c.oid)))
  from pg_class c
 where c.relnamespace = 'public'::regnamespace and c.relkind in ('v', 'm') and pg_temp.mine('pg_class', c.oid);

select pg_temp.l('rule ' || c.relname || ' ' || r.rulename || ' def=' || md5(pg_get_ruledef(r.oid)))
  from pg_rewrite r
  join pg_class c on c.oid = r.ev_class
 where c.relnamespace = 'public'::regnamespace and r.rulename <> '_RETURN';

select pg_temp.l('sequence ' || c.relname || ' type=' || format_type(s.seqtypid, null)
       || ' start=' || s.seqstart::text || ' increment=' || s.seqincrement::text
       || ' min=' || s.seqmin::text || ' max=' || s.seqmax::text || ' cycle=' || s.seqcycle::text
       || ' owned_by=' || coalesce((select t.relname || '.' || a.attname
                                      from pg_depend d
                                      join pg_class t on t.oid = d.refobjid
                                      join pg_attribute a on a.attrelid = d.refobjid and a.attnum = d.refobjsubid
                                     where d.classid = 'pg_class'::regclass and d.objid = c.oid
                                       and d.refclassid = 'pg_class'::regclass and d.deptype in ('a', 'i')
                                     limit 1), ''))
  from pg_sequence s
  join pg_class c on c.oid = s.seqrelid
 where c.relnamespace = 'public'::regnamespace;

select pg_temp.l('enum ' || t.typname || ' owner=' || pg_get_userbyid(t.typowner)
       || ' acl=' || pg_temp.acl(t.typacl, 'T', t.typowner)
       || ' labels=' || (select string_agg(e.enumlabel, ',' order by e.enumsortorder)
                           from pg_enum e where e.enumtypid = t.oid))
  from pg_type t
 where t.typnamespace = 'public'::regnamespace and t.typtype = 'e' and pg_temp.mine('pg_type', t.oid);

select pg_temp.l('domain ' || t.typname || ' base=' || format_type(t.typbasetype, t.typtypmod)
       || ' notnull=' || t.typnotnull::text || ' default=' || coalesce(t.typdefault, '')
       || ' acl=' || pg_temp.acl(t.typacl, 'T', t.typowner))
  from pg_type t
 where t.typnamespace = 'public'::regnamespace and t.typtype = 'd' and pg_temp.mine('pg_type', t.oid);

select pg_temp.l('composite ' || t.typname || ' acl=' || pg_temp.acl(t.typacl, 'T', t.typowner)
       || ' attributes=' || (select coalesce(string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod),
                                                        ',' order by a.attnum), '')
                               from pg_attribute a
                              where a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped))
  from pg_type t
  join pg_class c on c.oid = t.typrelid and c.relkind = 'c'
 where t.typnamespace = 'public'::regnamespace and pg_temp.mine('pg_type', t.oid);

select pg_temp.l('extension ' || e.extname || ' schema=' || n.nspname || ' version=' || e.extversion)
  from pg_extension e
  join pg_namespace n on n.oid = e.extnamespace;

select pg_temp.l('schema ' || n.nspname || ' owner=' || pg_get_userbyid(n.nspowner)
       || ' acl=' || pg_temp.acl(n.nspacl, 'n', n.nspowner))
  from pg_namespace n
 where n.nspname !~ '^pg_' and n.nspname <> 'information_schema';

select pg_temp.l('default_acl role=' || pg_get_userbyid(d.defaclrole) || ' schema=' || coalesce(n.nspname, '*')
       || ' type=' || d.defaclobjtype::text
       || ' acl=' || (select coalesce(string_agg(s.x, ',' order by s.x), '')
                        from (select case when a.grantee = 0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end
                                     || ':' || a.privilege_type || case when a.is_grantable then '*' else '' end as x
                                from aclexplode(d.defaclacl) a) s))
  from pg_default_acl d
  left join pg_namespace n on n.oid = d.defaclnamespace;

select pg_temp.l('publication ' || p.pubname || ' all=' || p.puballtables::text || ' insert=' || p.pubinsert::text
       || ' update=' || p.pubupdate::text || ' delete=' || p.pubdelete::text || ' truncate=' || p.pubtruncate::text)
  from pg_publication p;

select pg_temp.l('publication_table ' || t.pubname || ' ' || t.schemaname || '.' || t.tablename)
  from pg_publication_tables t;

select pg_temp.l('event_trigger ' || e.evtname || ' on=' || e.evtevent || ' function=' || e.evtfoid::regproc::text
       || ' enabled=' || e.evtenabled::text)
  from pg_event_trigger e;

select to_regclass('storage.buckets') is not null as has_buckets,
       to_regclass('cron.job') is not null as has_cron,
       to_regprocedure('public.system_column_names()') is not null as has_system_columns \gset
\if :has_buckets
select pg_temp.l('bucket ' || b.id || ' public=' || b.public::text
       || ' limit=' || coalesce(b.file_size_limit::text, '')
       || ' mime=' || coalesce(array_to_string(b.allowed_mime_types, ','), ''))
  from storage.buckets b;
\endif
\if :has_cron
select pg_temp.l('cron ' || coalesce(j.jobname, '') || ' schedule=' || j.schedule || ' active=' || j.active::text
       || ' command=' || md5(j.command))
  from cron.job j;
\endif

-- The rows the migrations seed: advice, never the gate.
\if :has_system_columns
create function pg_temp.reference_rows() returns setof text language plpgsql as $f$
declare
  r record;
  v_skip text[];
  v_n bigint;
  v_md5 text;
begin
  for r in select c.oid, c.relname
             from pg_catalog.pg_class c
            where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
              and not exists (select 1 from pg_catalog.pg_attribute a
                               where a.attrelid = c.oid and a.attname = 'workspace_id' and not a.attisdropped)
            order by c.relname loop
    select coalesce(array_agg(a.attname::text), '{}') || public.system_column_names() into v_skip
      from pg_catalog.pg_attribute a
     where a.attrelid = r.oid and a.attnum > 0 and not a.attisdropped
       and a.atttypid in ('uuid'::regtype, 'timestamptz'::regtype, 'timestamp'::regtype);
    execute format(
      'select count(*), md5(coalesce(string_agg(s.x, '''' order by s.x), ''''))
         from (select md5((to_jsonb(t) - %L::text[])::text) as x from public.%I t) s', v_skip, r.relname)
      into v_n, v_md5;
    if v_n > 0 then
      return next 'data ' || r.relname || ' rows=' || v_n || ' md5=' || v_md5;
    end if;
  end loop;
end
$f$;
select pg_temp.reference_rows();
\endif
