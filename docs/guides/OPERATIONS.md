<!-- SPDX-License-Identifier: 0BSD -->
# Running a DesKilo instance: backup, restore, rollback

#1245. `RELEASING.md` covers shipping the app. This covers the thing an
operator actually loses sleep over: the workspace's data, and what to do
on the day something is wrong with it.

DesKilo runs on Supabase. That is the whole infrastructure — Postgres,
auth, storage and a handful of edge functions — so everything here is
about one project, and there is no application server to restore.

## Before anything else: `deskilo doctor`

```
dart run tool/instance.dart doctor --ref <project ref>
```

It reads the live project and exits 1 when something needs a human, so a
schedule can act on it. It writes nothing, so it is safe to run at any
time, including in the middle of an incident.

It answers, in one pass:

| | |
|---|---|
| Schema | how many migrations applied, how many tables |
| Row-level security | on for every table, or which ones it is off for |
| Closed tables | a table with no policy that still grants to `anon` |
| Definer functions | any callable without signing in |
| Storage buckets | `avatars` and `floor-plans` present |
| Site URL | the link every confirmation mail carries |
| Redirect allow-list | every callback the app uses |
| Confirmation e-mail | whether anybody has to click anything |
| Sign-ups | created and confirmed in seven days, and who is stuck |

The first five are the questions CI asks of a database it builds itself
(#1226); an operator on their own Supabase has neither the lints nor the
pgTAP suite, so the doctor asks them of the live project instead.

## Backup

**What Supabase does for you.** Every paid project takes a daily
physical backup with point-in-time recovery on the higher plans. Check
which you have — on the free plan there is **no** automatic backup, and
the rest of this section is not optional.

**What to take yourself.** A logical dump is the one that survives the
project being deleted, the plan lapsing, or a decision to move host:

```bash
# The whole thing: schema, data, roles.
supabase db dump --db-url "$DB_URL" --file deskilo-$(date +%F).sql

# Data only, if you already keep the schema in git (you do — supabase/migrations).
supabase db dump --db-url "$DB_URL" --data-only --file deskilo-data-$(date +%F).sql
```

Storage objects are **not** in a database dump. Avatars and floor-plan
backgrounds live in the two buckets; copy them separately:

```bash
supabase storage cp -r ss://avatars ./backup/avatars
supabase storage cp -r ss://floor-plans ./backup/floor-plans
```

**Keep the dump somewhere the project cannot take with it.** A backup in
the same account as the thing it backs up is a copy, not a backup.

**How often.** The invoices are accounting records with a statutory
retention (see `PRIVACY.md`), so treat a lost month as a legal problem
and not merely an inconvenience. Daily is the floor.

## Restore

Into a **new** project, always. Restoring over a live one turns a
recoverable problem into two.

```bash
dart run tool/instance.dart create --token "$SUPABASE_ACCESS_TOKEN" \
  --org <org> --name deskilo-restore
psql "$NEW_DB_URL" -v ON_ERROR_STOP=1 -f deskilo-<date>.sql
supabase storage cp -r ./backup/avatars ss://avatars
supabase storage cp -r ./backup/floor-plans ss://floor-plans
dart run tool/instance.dart auth --token "$SUPABASE_ACCESS_TOKEN" --ref <new ref>
dart run tool/instance.dart doctor --token "$SUPABASE_ACCESS_TOKEN" --ref <new ref>
```

The `auth` step is not optional and is the one people forget: a project
created from a dump carries Supabase's default Site URL,
`http://localhost:3000`, and every confirmation mail it sends then points
at a server nobody runs. That is #1050, and it cost three people their
sign-up before #1075 built the doctor that catches it.

Then point the app at the new project and check somebody can sign in
before you tell anybody it is fixed.

**This procedure is executed on every pull request.** It used to be a
procedure nobody had ever run — written down, plausible, and unproven,
which is the state every backup is in until the first restore. The
`quality · database` job now runs `scripts/restore_check.sh`: it seeds
`supabase/restore/seed.sql` — two workspaces, a floor plan in each,
bookings across two months, and an invoice with the ledger row and the
match that settle it — dumps the database, restores it into a fresh one,
and then makes the copy prove itself: equal row counts per table,
`reconcile_workspace()` clean for both workspaces, and no member holding
another tenant's booking. Then it damages the copy on purpose — deletes a
row, breaks a match — and requires both to be caught, because a drill
that has only ever passed cannot be told apart from one that does not
look. What CI cannot rehearse is the part above that
touches a real project — storage and the `auth` step — so read those
twice on the day (#1310).

## Rollback

**The schema does not roll back, and that is deliberate.** There are no
`down` migrations. A migration that turned out wrong is corrected by a
NEW migration, for the same reason an issued invoice is voided rather
than edited: the state a system passed through is part of its history.

So a rollback is one of three things, in order of preference:

1. **A forward fix.** Write the migration that puts it right, harness it
   against a rolled-back transaction on the dev project first
   (`deskilo-supabase-migration`), apply, verify live.
2. **Point-in-time recovery**, if the plan has it and the damage is
   recent and data-shaped rather than schema-shaped.
3. **Restore into a new project** as above, and repoint the app. Anything
   written since the dump is gone; know how much that is before you
   start.

**The app rolls back independently of the schema.** Every release is a
tag, and the store keeps previous builds. Because migrations only ever
add, an older binary against a newer schema usually works — it simply
does not know about the new columns. The reverse is not true: a newer
binary expects its migrations to be applied, which is exactly what the
doctor's "Schema is behind" alarm is for.

## Version compatibility

| | |
|---|---|
| App ← schema | an older app on a newer schema: **supported**, it ignores what it does not know |
| App → schema | a newer app on an older schema: **not supported** — run `instance.dart install` |
| Bundle | `assets/instance/bundle.json` is generated from `supabase/migrations/` and pinned by `test/lint/instance_bundle_test.dart`, so it can never lag |
| Postgres | the hosted projects run 17.x; `supabase/config.toml` pins the local stack to the same major so CI tests what production runs |

## Disaster runbook

**"Nobody can sign in."** Run the doctor. If it says the Site URL is
`localhost`, that is the whole answer: `instance.dart auth --ref <ref>`.
If it says accounts are stuck, they are people who tried and will not try
again unprompted — fix the cause, then tell them.

**"A workspace's data looks wrong."** Do not start by writing SQL. Run
the reconciliation first — it compares invoices, the ledger and the
payments and names what disagrees:

```sql
select * from public.reconcile_workspace('<workspace id>');
```

No rows means the money agrees with itself and the problem is elsewhere.

**"We deleted something we should not have."** The ledger and the
invoices cannot be deleted at all (0212, `invoices_no_mutation`), so the
accounting record survives most mistakes by construction. Reservations
and plan objects can go; those come back from a restore.

**"The project is gone."** Restore, above. This is the scenario your
off-account dump exists for, and the only one you cannot improvise.

## What is deliberately not here

**No Docker Compose.** DesKilo is a Supabase application, not a
self-contained stack: `create`, `install` and `auth` are the three
commands, and they are already one each. A Compose file would have to
reimplement auth, storage and the edge runtime to be honest, and a
Compose file that only runs Postgres would suggest the rest is optional.
If self-hosting Supabase itself is wanted, that is their
`docker-compose.yml` and it is out of this repository's scope.
