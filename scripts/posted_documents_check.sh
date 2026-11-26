#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #4492 row 4 -- a posted document stays: the forbidden writes, attempted on
# the rows the database tests themselves post.
#
# Each pgTAP file is one transaction that builds a business, posts documents
# through the real commands and rolls back. This runs a file up to its last
# assertion and, before the rollback, hands the open transaction to
# scripts/posted_documents_probe.sql: on every posted-document table that
# holds a posted row it tries an UPDATE of every column, a DELETE, a TRUNCATE
# and a forged INSERT, as the owner under row-level security, as the same
# owner through a delegated token and as the server's own role. So the
# fixtures are the ones already proven by the suite, and a table is covered as
# soon as any swept file posts into it.
#
#   scripts/posted_documents_check.sh <db url>
#
#   POSTED_SWEEP   a regular expression over the pgTAP file names to sweep
#                  (default: the money, counter, stock and filing files)
#   POSTED_BUDGET  seconds after which no further file is started (default 420);
#                  the verdict says how many files were swept
#   POSTED_TABLES  the tables that MUST have been reached (default: the list at
#                  the end of this file); a table no fixture posted into is a
#                  failure, not a silence
#
# The verdict:
#   * the owner and the delegated owner change NOTHING: every attempt is
#     refused (42501: no privilege, no policy) or reaches no row. Anything
#     else fails.
#   * the server's role is what the Edge functions and an import run as, and
#     no policy restrains it: only the guards (triggers) stand. What it CAN
#     change on a posted row is listed in scripts/posted_documents_allowed.txt
#     with the reason; an attempt that gets through and is not listed fails,
#     and a listed one that no longer gets through is reported.
#
# Writes nothing that stays: every file rolls back, as it does in the suite.
set -uo pipefail

DB_URL=${1:?usage: posted_documents_check.sh <db url>}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PSQL=${PSQL_BIN:-psql}
SWEEP="${POSTED_SWEEP:-counter|till|invoice|credit|ledger|stock|verifactu|book_period|vat_|money|payment|purchase|number|archive|goods}"
BUDGET="${POSTED_BUDGET:-420}"
ALLOWED="$HERE/posted_documents_allowed.txt"
OUT="${POSTED_OUT:-}"
if [ -z "$OUT" ]; then
  if [ -d preview ]; then OUT=preview/posted-documents; else OUT=report/posted-documents; fi
fi
REQUIRED="${POSTED_TABLES:-invoices ledger_entries counter_receipts counter_receipt_lines counter_tenders counter_refunds counter_cash_entries counter_till_sessions counter_day_closes stock_movements}"

fail() { echo "::error::posted documents: $*"; exit 1; }
say() { printf '  %s\n' "$*"; }

mkdir -p "$OUT"
: > "$OUT/attempts.tsv"
WORK="$(mktemp -d -t deskilo-posted-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

"$PSQL" "$DB_URL" -X -At -c 'select 1' >/dev/null 2>&1 || fail "cannot reach the database"

started=$SECONDS
swept=0; total=0; unusable=""
echo "--- the forbidden writes, on the rows the suite posts"
for f in supabase/tests/database/*.sql; do
  name="$(basename "$f" .sql)"
  printf '%s\n' "$name" | grep -qE "$SWEEP" || continue
  total=$((total + 1))
  if [ "$((SECONDS - started))" -ge "$BUDGET" ]; then continue; fi
  # The file up to its last `rollback;`, the probe, then the rollback.
  last="$(grep -n -iE '^[[:space:]]*rollback;[[:space:]]*$' "$f" | tail -1 | cut -d: -f1)"
  if [ -z "$last" ]; then unusable="$unusable $name(no-rollback)"; continue; fi
  { head -n "$((last - 1))" "$f"; cat "$HERE/posted_documents_probe.sql"; printf '\nrollback;\n'; } > "$WORK/run.sql"
  "$PSQL" "$DB_URL" -X -At -q -f "$WORK/run.sql" > "$WORK/out.txt" 2> "$WORK/err.txt"
  swept=$((swept + 1))
  if grep -q '^ZZPOSTED' "$WORK/out.txt"; then
    grep '^ZZPOSTED' "$WORK/out.txt" | sed "s/^ZZPOSTED/$name/" >> "$OUT/attempts.tsv"
  elif grep -q 'zz_posted_probe\|current transaction is aborted' "$WORK/err.txt"; then
    unusable="$unusable $name"
  fi
done
say "swept $swept of $total files in $((SECONDS - started))s ($(cut -f1 "$OUT/attempts.tsv" | sort -u | grep -c '') posted into a document table)"
[ -z "$unusable" ] || say "could not be probed (their own transaction had failed, or no rollback line):$unusable"
[ -s "$OUT/attempts.tsv" ] || fail "no file posted a document: nothing was attempted"

grep -vE '^[[:space:]]*(#|$)' "$ALLOWED" 2>/dev/null | sed -E 's/[[:space:]]+#.*$//' > "$WORK/allowed.txt"
python3 -B - "$OUT/attempts.tsv" "$WORK/allowed.txt" "$OUT" $REQUIRED <<'PY'
import collections, sys

attempts, allowed_path, out, required = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
allowed = {tuple(l.split()) for l in open(allowed_path, encoding='utf-8') if l.strip()}
# (table, caller, answer) -> the attempts; and where each was seen
got = collections.defaultdict(set)
rows = collections.defaultdict(int)
files = collections.defaultdict(set)
for line in open(attempts, encoding='utf-8'):
    parts = line.rstrip('\n').split('\t')
    if len(parts) != 6:
        continue
    source, table, n, caller, answer, ops = parts
    got[(table, caller, answer)].update(ops.split(','))
    rows[table] = max(rows[table], int(n or 0))
    files[table].add(source)

def kind(answer):
    if answer == 'changed': return 'CHANGED'
    if answer == 'same': return 'reached'
    if answer == 'norows': return 'no row'
    if answer == '42501': return 'refused (privilege or policy)'
    # 55000 is how the match history's guard answers (0750)
    if answer in ('P0001', '55000') or answer.startswith('DK'): return 'refused (guard)'
    if answer.startswith('23'): return 'PAST THE GUARDS (stopped by a constraint)'
    if answer == 'no_owner': return 'not tried (no owner)'
    return 'not answered (the attempt itself failed)'

tables = sorted({t for t, _, _ in got})
print('  tables reached: ' + ', '.join(f'{t} ({rows[t]} rows, {len(files[t])} files)' for t in tables))
failures, through = [], set()
lines = []
for (table, caller, answer), ops in sorted(got.items()):
    k = kind(answer)
    lines.append(f'{table}\t{caller}\t{answer}\t{k}\t{",".join(sorted(ops))}')
    if caller in ('owner', 'delegated'):
        if answer in ('changed', 'same') or answer.startswith('23'):
            failures.append(f'{caller} on {table}: {k}: {",".join(sorted(ops))}')
    elif caller == 'server':
        if answer == 'changed' or answer.startswith('23'):
            for op in ops:
                through.add((table, op))
open(out + '/matrix.tsv', 'w', encoding='utf-8').write('\n'.join(lines) + '\n')

print('  as the owner and as the delegated owner:')
for caller in ('owner', 'delegated'):
    summary = collections.Counter()
    for (table, c, answer), ops in got.items():
        if c == caller:
            summary[kind(answer)] += len(ops)
    print(f'    {caller}: ' + ', '.join(f'{n} {k}' for k, n in sorted(summary.items())))
print('  as the server role:')
summary = collections.Counter()
for (table, c, answer), ops in got.items():
    if c == 'server':
        summary[kind(answer)] += len(ops)
print('    ' + ', '.join(f'{n} {k}' for k, n in sorted(summary.items())))
unanswered = sorted((t, c, a, sorted(o)) for (t, c, a), o in got.items() if kind(a).startswith('not answered'))
for t, c, a, o in unanswered:
    print(f'    not answered: {c} on {t}: {a}: {",".join(o)[:300]}')

status = 0
for f in failures:
    print(f'::error::posted documents: {f[:600]}')
    status = 1
new = sorted(through - allowed)
gone = sorted(allowed - through)
if through:
    print('  what the server role can do to a posted row (table, attempt):')
    for t, op in sorted(through):
        print(f'    {t} {op}' + ('' if (t, op) in allowed else '   <-- not listed'))
if new:
    print(f'::error::posted documents: the server role gets {len(new)} writes through that scripts/posted_documents_allowed.txt does not list')
    status = 1
if gone:
    print('  listed as allowed and no longer getting through (remove the line): ' + ', '.join(' '.join(g) for g in gone))
missing = [t for t in required if t not in tables]
if missing:
    print('::error::posted documents: no swept file posted into: ' + ', '.join(missing))
    status = 1
sys.exit(status)
PY
status=$?
echo "posted documents took $((SECONDS - started))s; the attempts are in $OUT/"
exit $status
