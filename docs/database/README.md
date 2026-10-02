# The data dictionary

The complete, current data model of the DesKilo database: every non-system
table, partition and view in the application schema (`public`), every
column with its type, nullability, default and identity or generated
expression, every key, check, index and relationship. It is **generated
from the PostgreSQL catalogues** after the real migration replay, never
written by hand and never derived from Dart models or `CREATE TABLE`
history.

| File | What it is |
|---|---|
| `dictionary.json` | The source of truth: one catalogue extraction. Deterministic, byte-stable for one schema. Records the schema marker (the last migration), the PostgreSQL major version, the object counts and a catalogue checksum. |
| `dictionary.html` | One self-contained page: searchable, a section per table with anchors per column, a relation diagram per table. No network access, no external script, font or image. Open it from disk. |
| `columns.csv` | One row per column. |
| `relationships.csv` | One row per relationship: `defined` (a foreign key, with its ON DELETE / ON UPDATE and validation status) or `inferred`. |

## Defined versus inferred

A **defined** relationship is a foreign key constraint in the catalogue,
shown with its columns in key order and, for `ON DELETE SET NULL (col)`,
the columns that are nulled. An **inferred** relationship is only a naming
match: a column `<thing>_id` without a foreign key, where `<thing>` is a
table with a single-column primary key of the same type. It is a logical
link the database does not enforce, and it is italic in the page.
`company_id` and `site_id` are tenancy stamps present on every table and
are never inferred as keys. A `jsonb` column is a physical field; the
dictionary does not imply a normalised table behind it.

## What is not in it

`pg_catalog`, `information_schema`, `pg_toast`, objects an extension owns,
the managed platform schemas (`auth`, `storage`, `realtime`, ...), row
values, function bodies and view definitions. A foreign key into a managed
table (`auth.users`) stays as a reference marked *(managed)*. The managed
schemas belong to the platform version, not to a migration; the run
artifact lists the ones present. Defaults of columns whose name says
secret, token, password, API or private key, credential, vault, e-mail,
phone, IBAN, first or last name are shown as `<redacted>`.

This is the **data model as it is**. Proposed schemas and roadmap issues
are not in it, and it is not an API contract (the public network contract
lives in `contracts/public_network`).

## How it is kept true

`quality · database` replays every migration onto an empty Postgres and the
step *Effective contract* then runs `scripts/db_dictionary.sh --advisory`:
it extracts the dictionary from the replay (twice, refusing a run in which
DDL ran in between) and WARNS when `docs/database/dictionary.json` differs.
The comparison does not fail a migration PR, so adding a column costs no
extra CI round (#2088). Two things keep the file true instead:

- `CI · Dictionary refresh` runs after every merge to master (and nightly):
  it regenerates the JSON and the renderings from the replay and keeps ONE
  pull request, `ci/dictionary-refresh`, with auto-merge. The workflow
  token cannot start the required checks of a pull request, so it
  dispatches `quality.yml` on the branch; and creating pull requests from
  Actions is a repository setting, which, while off, leaves the pushed
  branch and a run summary naming the command that opens the PR.
- `test/tool/db_dictionary_test.dart` is the hard gate that needs no
  replay: it fails when a rendering is not what `dictionary.json` renders,
  when the extraction is incomplete or inconsistent, or when the marker
  is newer than the migrations.

To regenerate by hand, copy `db-dictionary.json` from a database job's
`quality-database` artifact (or from `scripts/db_dictionary.sh`) over
`docs/database/dictionary.json`, then run
`dart run tool/build_db_dictionary.dart`; `--check` only verifies. The
artifact also holds `db-dictionary-run.json`: snapshot time, exact server
version and the managed schemas present, which are deliberately not in the
committed file.

## Operator export

Read-only, catalogue-only, safe against a production instance; the
connection string is an argument and is never written:

```
scripts/db_dictionary.sh "$DB_URL"          # writes report/db-dictionary*.json
dart run tool/build_db_dictionary.dart      # renders docs/database/* from the committed JSON
```

The query is `scripts/db_dictionary.sql`. It runs in one read-only
transaction, twice. A live database is never claimed to be one atomic
snapshot: only the disposable replay is.
