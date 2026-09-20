#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1329 — two owners, one decision.
#
# `set_feature_flags` (0245) takes the read-set a preview rested on and
# refuses to merge if any of it moved. That is only protection if the
# comparison and the write are ONE operation: an unlocked SELECT followed
# by an UPDATE leaves a window in which another owner changes the row and
# the first still writes a preview nobody approved. A pgTAP file runs in
# one transaction and cannot see that window. Two real sessions can:
#
#   A: begin; write kioskMode=true expecting kioskMode=false; sleep; commit
#   B: same expectation, another delta        -- must BLOCK on A's row lock
#   A commits
#   B again                                   -- must be refused: DK409
#   B with no read-set                         -- merges, keeps A's key
#
# The lock timeout is the assertion: if B had been answered while A was
# uncommitted, the check would have run against a row A was about to
# change, and the two would not be serialized.
set -uo pipefail

DB_URL=${1:?usage: feature_flags_race.sh <db url>}
WS=00000000-0000-4000-8000-00000000d001
OWNER=00000000-0000-4000-8000-00000000d002

say() { printf '  %s\n' "$*"; }
fail() { cleanup 2>/dev/null || true; echo "::error::$*"; exit 1; }

cleanup() {
  psql "$DB_URL" -qtAX >/dev/null 2>&1 <<SQL
alter table public.members disable trigger user;
delete from public.members where workspace_id = '$WS';
alter table public.members enable trigger user;
delete from public.workspaces where id = '$WS';
delete from auth.users where id = '$OWNER';
SQL
}

echo "two owners, one decision"

fixture=$(psql "$DB_URL" -qX -v ON_ERROR_STOP=1 2>&1 <<SQL
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values ('$OWNER', '00000000-0000-0000-0000-000000000000', 'authenticated',
        'authenticated', 'flags-race@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone,
                               created_by, feature_flags)
values ('$WS', 'Flags race', 'FR', 'EUR', 'Europe/Paris', '$OWNER',
        '{"kioskMode": false}'::jsonb);
insert into public.members (workspace_id, user_id, is_owner, is_admin)
values ('$WS', '$OWNER', true, true);
SQL
) || fail "the fixture would not build. psql said: $fixture"

# The owner, as PostgREST would present them: claims, then the role.
AS_OWNER="select set_config('request.jwt.claims',
  '{\"sub\": \"$OWNER\", \"role\": \"authenticated\"}', false);
  set role authenticated;"

write() {
  printf "select public.set_feature_flags('%s', '%s'::jsonb, %s)" "$WS" "$1" "$2"
}

# A: decides on kioskMode=false, writes, and holds the row for three seconds.
psql "$DB_URL" -qX -v ON_ERROR_STOP=1 -c "$AS_OWNER begin;
  $(write '{"kioskMode": true}' "'{\"kioskMode\": false}'::jsonb");
  select pg_sleep(3); commit;" >/dev/null 2>&1 &
holder=$!
sleep 1

# B: the same decision, while A is undecided.
blocked=$(psql "$DB_URL" -qX -c "$AS_OWNER set lock_timeout = '800ms';
  $(write '{"badgeSignIn": true}' "'{\"kioskMode\": false}'::jsonb");" 2>&1 || true)
case "$blocked" in
  *"canceling statement due to lock timeout"*|*55P03*)
    say "while the first write is uncommitted the second BLOCKS and times out" ;;
  *)
    wait "$holder" || true
    fail "the second writer was not blocked by the first's row lock. It said: $blocked
       The comparison ran against a row the first session was about to
       change: check and write are not one operation." ;;
esac

wait "$holder" || fail "the holding session did not commit"

after=$(psql "$DB_URL" -qX -c "$AS_OWNER
  $(write '{"badgeSignIn": true}' "'{\"kioskMode\": false}'::jsonb");" 2>&1 || true)
case "$after" in
  *DK409*|*"the features changed since they were read: kioskMode"*)
    say "and once the first is committed the second is refused: its read-set moved" ;;
  *)
    fail "the second write went through on a read-set the first had changed.
       It said: ${after:-(nothing — it SUCCEEDED)}" ;;
esac

merged=$(psql "$DB_URL" -qtAX -c "$AS_OWNER
  $(write '{"badgeSignIn": true}' null);" 2>&1 || true)
case "$merged" in
  *'"kioskMode": true'*'"badgeSignIn": true'*|*'"badgeSignIn": true'*'"kioskMode": true'*)
    say "a write without a read-set still merges and keeps the first writer's key" ;;
  *)
    fail "the unconditional merge lost a key. The row says: $merged" ;;
esac

cleanup
echo "feature flags: check and write are one operation"
