# SPDX-License-Identifier: AGPL-3.0-or-later
"""#1285: rehearse the exact read-only preflight on rolled-back synthetic rows."""
import argparse
from pathlib import Path
import re
import subprocess


def rehearsal_sql():
    root = Path(__file__).resolve().parent.parent
    preflight = (root / 'docs/guides/workspace_alignment_preflight.sql').read_text()
    fixture = (root / 'scripts/workspace_alignment_fixture.sql').read_text()
    return '''begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
create function pg_temp.alignment_report() returns jsonb language plpgsql as $capture$
begin
  begin
    execute $source$''' + preflight + '''$source$;
  exception when raise_exception then
    if sqlerrm like 'PREFLIGHT CLEAR %' then
      return substring(sqlerrm from length('PREFLIGHT CLEAR ') + 1)::jsonb;
    end if;
    return jsonb_build_object('error', sqlerrm);
  end;
  raise exception 'preflight failed to abort';
end;
$capture$;
''' + fixture + '\nselect * from finish();\nrollback;\n'


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sql', action='store_true', help='print the rolled-back rehearsal SQL')
    parser.add_argument('database_url', nargs='?')
    args = parser.parse_args()
    if args.sql:
        print(rehearsal_sql())
    else:
        if not args.database_url:
            parser.error('a disposable test database URL or --sql is required')
        result = subprocess.run(['psql', args.database_url, '-XAt', '-v', 'ON_ERROR_STOP=1'],
                                input=rehearsal_sql(), text=True, capture_output=True)
        print(result.stdout, end='')
        if result.returncode:
            print(result.stderr, end='')
        plan = re.search(r'^1\.\.(\d+)$', result.stdout, re.M)
        passed = re.findall(r'^ok \d+\b', result.stdout, re.M)
        failed = re.search(r'^(not ok|# Looks like)', result.stdout, re.M)
        raise SystemExit(0 if result.returncode == 0 and plan and
                         len(passed) == int(plan[1]) and not failed else 1)
