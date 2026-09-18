#!/usr/bin/env bash
# SPDX-License-Identifier: 0BSD
#
# #1337 — install, resume and upgrade a real schema, and let the doctor
# read it, with the code the wizard and `tool/instance.dart` run.
#
# The lifecycle was only ever proven against a fake Management API. This
# gives it real databases that start as an EMPTY Supabase project, and
# `tool/instance_lifecycle_check.dart` runs the real InstanceBuilder,
# InstanceReadinessCheck and InstanceDoctor on them through psql.
#
# What "an empty Supabase project" is, here: the stack's own database with
# everything the migrations added taken away. It is dumped schema-only as
# the superuser — owners, grants and default privileges kept, because the
# doctor's security findings are about exactly those — and restored into a
# new database without:
#
#   * anything in `public`, except its default privileges (a new project's
#     tables get Supabase's grants, and 0211 is about that);
#   * `supabase_migrations` — the CLI's bookkeeping, which a new project
#     does not have and the installer creates;
#   * every row policy (a new project has none outside `public`; the
#     storage policies are 0038's and 0215's);
#   * triggers on platform tables that call a `public` function (0001's
#     sign-up trigger on auth.users);
#   * extensions a new hosted project does not carry (btree_gist, pg_net,
#     pg_cron: the migrations create them), and their schemas.
#
# Then three copies: one installs from empty, one is interrupted and
# resumed, one gets a foreign table. Roles are cluster-wide and already
# there. All of it through `docker exec`, as the restore drill does, so the
# client always matches the server. Every database is dropped on exit.
set -uo pipefail

PREFIX="deskilo_lifecycle"
EMPTY="${PREFIX}_empty"
INSTALL="${PREFIX}_install"
RESUME="${PREFIX}_resume"
FOREIGN="${PREFIX}_foreign"
IN_CONTAINER_DUMP="/tmp/${PREFIX}.dump"
IN_CONTAINER_LIST="/tmp/${PREFIX}.list"

# What a new hosted project already has installed. Everything else in the
# stack's database was created by a migration.
HOSTED_EXTENSIONS="plpgsql pgcrypto uuid-ossp pg_stat_statements pg_graphql supabase_vault pgsodium"

fail() { echo "::error::instance lifecycle: $*"; exit 1; }

C="$(docker ps --format '{{.Names}}' | grep -E '^supabase_db' | head -1)"
[ -n "$C" ] || fail "the local stack's database container is not running"

# The superuser, for the dump and the restore: owners and grants must
# survive, and only a superuser may hand objects to the platform roles.
# The local stack's password for every role is `postgres`.
admin() { docker exec -i -e PGPASSWORD=postgres "$C" "$@"; }
# Over TCP inside the container when that is allowed, else the socket.
HOST=(-h 127.0.0.1)
asql() { admin psql -X "${HOST[@]}" -U supabase_admin "$@"; }

# KEEP_EMPTY=1 leaves the empty project behind for the populated upgrade
# check (#1338), which copies it the way the three databases below are.
cleanup() {
  for db in "$INSTALL" "$RESUME" "$FOREIGN" "$EMPTY"; do
    [ "$db" = "$EMPTY" ] && [ "${KEEP_EMPTY:-}" = 1 ] && [ "${1:-}" = end ] && continue
    asql -d postgres -q -c "drop database if exists $db with (force)" >/dev/null 2>&1
  done
  admin rm -f "$IN_CONTAINER_DUMP" "$IN_CONTAINER_LIST" >/dev/null 2>&1
  rm -f "${LIST:-}" "${PROPS:-}" "${ERRORS:-}"
}
trap 'cleanup end' EXIT

if ! asql -d postgres -At -c 'select current_user' >/dev/null; then
  HOST=()
  asql -d postgres -At -c 'select current_user' >/dev/null \
    || fail "cannot connect as supabase_admin inside $C"
fi

echo "--- the empty project"
started=$SECONDS
cleanup

admin pg_dump "${HOST[@]}" -U supabase_admin -d postgres --schema-only \
  --create -Fc -f "$IN_CONTAINER_DUMP" || fail "the schema dump failed"

LIST="$(mktemp -t deskilo-lifecycle-list-XXXXXX)"
admin pg_restore -l "$IN_CONTAINER_DUMP" > "$LIST" || fail "could not list the dump"

# Extensions to leave out, and the schemas they own.
DROP_EXTENSIONS="$(asql -d postgres -At -c "
  select string_agg(extname, '|') from pg_extension
   where extname <> all (string_to_array('$HOSTED_EXTENSIONS', ' '))")"
DROP_SCHEMAS="$(asql -d postgres -At -c "
  select string_agg(n.nspname, '|')
    from pg_namespace n
    join pg_depend d on d.classid = 'pg_namespace'::regclass and d.objid = n.oid
                    and d.deptype = 'e'
    join pg_extension e on e.oid = d.refobjid
   where e.extname <> all (string_to_array('$HOSTED_EXTENSIONS', ' '))")"
# Not `public` itself: the schema, its grants and its comment are the
# platform's. Only what is IN it goes.
OTHER_SCHEMAS="supabase_migrations${DROP_SCHEMAS:+|$DROP_SCHEMAS}"
DROP_SCHEMAS="public|$OTHER_SCHEMAS"
TRIGGERS="$(asql -d postgres -At -c "
  select string_agg(n.nspname || ' ' || c.relname || ' ' || t.tgname, '|')
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_proc p on p.oid = t.tgfoid
    join pg_namespace pn on pn.oid = p.pronamespace
   where not t.tgisinternal and n.nspname <> 'public' and pn.nspname = 'public'")"
echo "leaving out: schemas [$DROP_SCHEMAS] extensions [${DROP_EXTENSIONS}] triggers [${TRIGGERS}]"

# A TOC line is `id; tableoid oid DESC SCHEMA NAME OWNER`, DESC in capitals.
FILTERED="$(mktemp -t deskilo-lifecycle-filtered-XXXXXX)"
grep -vE "^[0-9]+; [0-9]+ [0-9]+ [A-Z][A-Z ]* ($DROP_SCHEMAS) " "$LIST" \
  | grep -vE " SCHEMA (- )?($OTHER_SCHEMAS)( |$)" \
  | grep -vE " POLICY " \
  | grep -vE " DATABASE (PROPERTIES )?- " \
  | { if [ -n "$DROP_EXTENSIONS" ]; then grep -vE " EXTENSION (- )?($DROP_EXTENSIONS)( |$)"; else cat; fi; } \
  | { if [ -n "$TRIGGERS" ]; then grep -vE " TRIGGER ($TRIGGERS) "; else cat; fi; } \
  > "$FILTERED"
# Grants and comments on what those extensions own live in shared schemas
# (`extensions`), so the schema filter cannot see them: name them. The
# empty search_path is pg_dump's, so an argument type an extension owns is
# spelled schema-qualified here exactly as it is in the dump's list.
MEMBERS="$(mktemp -t deskilo-lifecycle-members-XXXXXX)"
asql -d postgres -q -At -v ON_ERROR_STOP=1 -c "
  set search_path = '';
  select distinct ' ' || n.nspname || ' ' || kind || ' ' || spelled || '('
         || pg_get_function_identity_arguments(p.oid) || ') '
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    join pg_depend d on d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e'
    join pg_extension e on e.oid = d.refobjid
    cross join unnest(array['FUNCTION', 'PROCEDURE', 'AGGREGATE']) kind
    -- a grant quotes a keyword name (\"is\"), the object's own tag does not
    cross join unnest(array[quote_ident(p.proname), p.proname::text]) spelled
   where e.extname <> all (string_to_array('$HOSTED_EXTENSIONS', ' '))
  union all
  select ' ' || n.nspname || ' ' || kind || ' ' || quote_ident(t.typname) || ' '
    from pg_type t join pg_namespace n on n.oid = t.typnamespace
    join pg_depend d on d.classid = 'pg_type'::regclass and d.objid = t.oid and d.deptype = 'e'
    join pg_extension e on e.oid = d.refobjid
    cross join unnest(array['TYPE', 'DOMAIN']) kind
   where e.extname <> all (string_to_array('$HOSTED_EXTENSIONS', ' '))
  union all
  select ' ' || n.nspname || ' ' || kind || ' ' || quote_ident(c.relname) || ' '
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    join pg_depend d on d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e'
    join pg_extension e on e.oid = d.refobjid
    cross join unnest(array['TABLE', 'VIEW', 'SEQUENCE']) kind
   where e.extname <> all (string_to_array('$HOSTED_EXTENSIONS', ' '))" > "$MEMBERS" \
  || fail "could not list what the left-out extensions own"
if [ -s "$MEMBERS" ]; then
  grep -vF -f "$MEMBERS" "$FILTERED" > "$FILTERED.members" && mv "$FILTERED.members" "$FILTERED"
fi
rm -f "$MEMBERS"
# The public schema's default privileges are the platform's, not ours.
grep -E "^[0-9]+; [0-9]+ [0-9]+ DEFAULT ACL public " "$LIST" >> "$FILTERED"
echo "restoring $(grep -cvE '^;' "$FILTERED") of $(grep -cvE '^;' "$LIST") schema entries"
admin sh -c "cat > $IN_CONTAINER_LIST" < "$FILTERED" || fail "could not hand the list over"
rm -f "$FILTERED"

OWNER="$(asql -d postgres -At -c "select pg_get_userbyid(datdba) from pg_database where datname = 'postgres'")"
asql -d postgres -q -v ON_ERROR_STOP=1 -c "create database $EMPTY owner $OWNER" \
  || fail "could not create $EMPTY"

# Database-level settings (a search_path, say) live with the database, not
# in its schemas: take them from the dump's own ALTER DATABASE lines.
PROPS="$(mktemp -t deskilo-lifecycle-props-XXXXXX)"
ERRORS="$(mktemp -t deskilo-lifecycle-errors-XXXXXX)"
admin pg_restore -C -s -f - "$IN_CONTAINER_DUMP" \
  | grep -E '^(ALTER DATABASE postgres SET|ALTER ROLE .* IN DATABASE postgres SET|GRANT .* ON DATABASE postgres |REVOKE .* ON DATABASE postgres )' \
  | sed "s/DATABASE postgres/DATABASE $EMPTY/" > "$PROPS"
echo "database settings: $(wc -l < "$PROPS" | tr -d ' ')"
asql -d postgres -q -v ON_ERROR_STOP=1 < "$PROPS" || fail "could not copy the database settings"

# Every entry must restore: a platform object that silently failed would
# make "empty project" mean less than it says.
admin pg_restore "${HOST[@]}" -U supabase_admin -d "$EMPTY" -L "$IN_CONTAINER_LIST" \
  "$IN_CONTAINER_DUMP" 2> "$ERRORS"
if grep -q 'error' "$ERRORS"; then
  echo "pg_restore reported $(grep -c 'error: could not' "$ERRORS") errors; the first:"
  awk '/error/ && n < 20 { print; n++ }' "$ERRORS"
  fail "the empty project did not restore cleanly"
fi
echo "restore clean"

# Proof that it is an empty Supabase project, before anything is installed.
SHAPE="$(asql -d "$EMPTY" -At -v ON_ERROR_STOP=1 -c "
  select concat_ws(' ',
    'auth.users=' || (to_regclass('auth.users') is not null),
    'auth.uid=' || (to_regprocedure('auth.uid()') is not null),
    'storage.buckets=' || (to_regclass('storage.buckets') is not null),
    'storage.foldername=' || (to_regprocedure('storage.foldername(text)') is not null),
    'pgcrypto=' || exists (select 1 from pg_extension where extname = 'pgcrypto'),
    'public_objects=' || (select count(*) from pg_class c join pg_namespace n
                            on n.oid = c.relnamespace where n.nspname = 'public'
                           and not exists (select 1 from pg_depend d
                                            where d.classid = 'pg_class'::regclass
                                              and d.objid = c.oid and d.deptype = 'e')),
    'policies=' || (select count(*) from pg_policies),
    'bookkeeping=' || (to_regnamespace('supabase_migrations') is not null))")" \
  || fail "the empty project cannot be read"
echo "empty project: $SHAPE"
[ "$SHAPE" = "auth.users=true auth.uid=true storage.buckets=true storage.foldername=true pgcrypto=true public_objects=0 policies=0 bookkeeping=false" ] \
  || fail "the empty project is not what a new Supabase project is: $SHAPE"

for db in "$INSTALL" "$RESUME" "$FOREIGN"; do
  asql -d postgres -q -v ON_ERROR_STOP=1 -c "create database $db template $EMPTY owner $OWNER" \
    || fail "could not copy the empty project into $db"
done
echo "prepared in $((SECONDS - started))s"

echo "--- the lifecycle"
dart run tool/instance_lifecycle_check.dart \
  --psql "docker exec $C psql -U postgres" \
  --install "$INSTALL" --resume "$RESUME" --foreign "$FOREIGN"
status=$?
echo "instance lifecycle took $((SECONDS - started))s"
exit $status
