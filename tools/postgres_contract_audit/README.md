# postgres_contract_audit

The effective contract of a PostgreSQL database, read from the catalogues of
**one explicit target**: what routines exist (every overload), whether each is
`SECURITY DEFINER` or invoker, its volatility, who may execute it, a digest of
its effective body, the constraints, the triggers and (on request) the
row-level-security policies — plus the readable effective definitions and a
manifest that names the target the evidence describes.

It is a reproducible statement of **shape and privileges**. It is not a
security certification, and a clean diff is not proof that a guard is correct.

```
AUDIT_SCHEMAS=public AUDIT_ROLES=anon,authenticated \
  bash pg_contract_audit.sh postgresql://user:password@host:5432/dbname
```

## Input

Every value is validated before anything is read or written.

| Variable | Meaning | Default |
|---|---|---|
| `<db url>` (argument) | the target; the only database read | required |
| `AUDIT_SCHEMAS` | comma list of schemas to inspect | `public` |
| `AUDIT_ROLES` | roles whose `EXECUTE` right is shown on every routine, in that order | none |
| `AUDIT_POLICIES` | `1` adds a line per RLS policy | `0` |
| `AUDIT_OUT_DIR` | relative output directory, no `..` | `audit-out` |
| `AUDIT_TARGET_LABEL` | safe label; outputs go to `<out>/<label>/` | none |
| `AUDIT_HEADER_FILE` | text placed at the top of `contract.txt` | a neutral header |
| `AUDIT_MIN_LINES` | refuse a contract with fewer lines | `1` |
| `AUDIT_SOURCE_LABEL` | what the run describes (commit, build) | `GITHUB_SHA`, then `git rev-parse HEAD`, then `unknown` |
| `AUDIT_DB_CONTAINER` | container of the target, used when the host `pg_dump` is older than the server | none |
| `AUDIT_CONTAINER_PREFIX` | prefix of the containers to search when none is named | none |
| `AUDIT_CONTAINER_USER`, `AUDIT_CONTAINER_DB` | how `psql`/`pg_dump` reach the database inside a container | `postgres`, `postgres` |

## Output (`<out>/[<label>/]`)

- `contract-lines.txt` — one sorted line per object; no OIDs, timestamps or owners.
- `contract.txt` — the same lines under a header.
- `effective-schema.sql` — `pg_dump --schema-only` of the inspected schemas.
- `manifest.json` — written **last**: target label, database name, server
  version, a digest of the target identity, schemas, roles, source label, run
  id and the digests of the outputs.

## What it will not do

- It is read-only: `SELECT` on the catalogues and `pg_dump --schema-only`. No
  DDL, no DML.
- A target that cannot be read, that changes while it is read, or that is not
  the database a dump container holds is a **failure** — no manifest and no
  accepted schema, never an empty "compatible" answer.
- No connection string or password reaches stdout, stderr or a file.
- A schema name, role name, output path or label that is not plain is refused
  before it reaches SQL or the file system.
- It does not normalise away a grant or a security change to hide a diff.

## Requirements

`bash`, `psql`, `pg_dump` (the host `pg_dump` must not be older than the
server, or a container that is verified to be the target is used), `sha256sum`
or `shasum`. PostgreSQL 12 or newer on the target. No Dart, Flutter or
application dependency.

## Check

`test/run.sh <admin db url>` builds a neutral library schema on a scratch
database and proves: both overloads, the invoker/definer split, PUBLIC and role
grants, the trigger, the constraints and the policy appear; the same schema
created in another order gives the same contract; a revoked grant is a
different contract; two databases give separately identified artifacts; an
unreadable target and an unsafe output path leave no manifest.

## Deskilo

`scripts/contract_check.sh` is the thin wrapper the quality job runs: the
`public` schema, the three API roles, the committed contract's header, a
100-line floor and the comparison with `assets/instance/contract.txt`.

Licence: AGPL-3.0-or-later (see the repository `LICENSE`); the script uses no
third-party code.
