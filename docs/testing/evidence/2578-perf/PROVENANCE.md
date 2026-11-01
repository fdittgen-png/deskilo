# #2578 performance proof: fixture and provenance

What is here: the one-transaction proof `2578-explain.sql` (begin … rollback,
needs a direct database connection; the Management API cuts a request at
about 100 s) and the three split money seeds `19a/19b/19c-seed-money.sql`
(invoices 1..5000, 5001..10000, 10001..14400, each one request).

The rest of the split run (setup, 18 reservation chunks, explain, checks,
cleanup) generates no invoices and is unchanged. It stays in the harness
folder on the machine that ran it, together with the failed-run evidence.

## The fixture bug that is fixed here

The declared profile is 400 members x 36 months, one `full` invoice per
member-month. Invoice n went to member `(n-1) mod 400` and month
`(n-1) mod 36`; since lcm(400, 36) = 3600, n = 3601 repeated n = 1 and
violated `invoices_member_period_kind_uniq` (migration 0142: member_id,
period, kind): `23505`, seen in the first split run at `19a`.

Now: member `(n-1) mod members`, month `((n-1) div members) mod months`, and
`perf.invoices` = members x months = 14,400. Every expectation in the files
is read from the data, so nothing else depends on the count.

`test/lint/perf_fixture_2578_test.dart` replays the allocation for all 14,400
invoices (no database) and pins the files to it.

## State

Not run against a database. The proof stays NOT RUN until a direct
connection to the dev project exists; the gate then runs it rolled back.
