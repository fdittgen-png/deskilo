# SPDX-License-Identifier: AGPL-3.0-or-later
"""#1791: prove a populated upgrade using real native Auth, then run its pgTAP.
Only disposable local official stacks; no hosted credentials or target accepted.
"""
import argparse
import json
import secrets
import shutil
import sys
import tempfile
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / 'scripts/recovery'))
from runtime import Stack, Refused


def verify_upgrade(stack):
    email, password = 'legacy@directory.deskilo.test', secrets.token_urlsafe(24) + 'aA1!'
    user = json.loads(stack.request('POST', '/auth/v1/signup', token=stack.credentials['ANON_KEY'],
                                   body={'email': email, 'password': password}))
    account = user['user']['id']
    workspace = json.loads(stack.request('POST', '/rest/v1/rpc/create_workspace', token=user['access_token'],
        body={'p_name': 'Directory upgrade', 'p_country_code': 'FR', 'p_currency_code': 'EUR',
              'p_timezone': 'Europe/Paris', 'p_environment': 'dev', 'p_with_twin': False, 'p_feature_flags': {}}))
    member = json.loads(stack.request('POST', '/rest/v1/rpc/create_managed_member', token=user['access_token'],
        body={'p_workspace_id': workspace, 'p_identity': {'first_name': 'Existing', 'last_name': 'Member'}}))
    stack.request('PATCH', '/rest/v1/profiles?id=eq.' + account, token=user['access_token'],
                  body={'clock': '12h', 'first_name': 'Original'}, expect=(204,))
    # Before migration, all old public rows are a baseline, excluding server
    # stamps that an additive backfill may legitimately advance.
    snapshot = "select jsonb_agg(to_jsonb(m)-public.system_column_names() order by id)::text from public.members m"
    before = json.loads(stack.sql(snapshot))
    migration = (REPO / 'supabase/migrations/0299_directory_people.sql').read_text()
    # Prove the migration is transaction-safe before committing it locally.
    stack.sql('begin;\n' + migration + '\nrollback;')
    stack.sql(migration)
    after = json.loads(stack.sql(snapshot))
    assert before == [{k: v for k, v in row.items() if k not in ('person_id', 'preferred_locale_override')} for row in after]
    assert all(row['person_id'] for row in after)
    assert next(row for row in after if row['id'] == member)['user_id'] is None
    # Existing credentials and existing active token both still work.
    profile = json.loads(stack.request('GET', '/rest/v1/profiles?id=eq.' + account, token=user['access_token']))[0]
    assert profile['first_name'] == 'Original' and profile['clock'] == '12h'
    assert profile['person_id'] != account
    # NOTIFY refreshes PostgREST asynchronously after the migration commits.
    # Retry only its brief missing-RPC response, never other API failures.
    deadline = time.monotonic() + 10
    while True:
        try:
            settings = json.loads(stack.request('POST', '/rest/v1/rpc/my_personal_preferences',
                token=user['access_token'], body={'p_workspace_id': workspace}))
            break
        except Refused as error:
            if str(error) != 'http_unexpected_status_404' or time.monotonic() >= deadline:
                raise
            time.sleep(.1)
    assert settings['defaults']['clock'] == '12h' and not settings['overrides']
    session = json.loads(stack.request('POST', '/auth/v1/token?grant_type=password',
        token=stack.credentials['ANON_KEY'], body={'email': email, 'password': password}))
    assert session['user']['id'] == account
    stack.sql('create extension if not exists pgtap with schema extensions')
    result = stack.sql('set search_path=public,extensions;\n' +
        (REPO / 'supabase/tests/database/86_directory_people.sql').read_text())
    assert 'not ok' not in result and 'Looks like' not in result
    print('PASS: populated upgrade, unchanged memberships, native sessions, defaults and directory pgTAP')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--disposable', action='store_true', required=True)
    parser.parse_args()
    root = Path(tempfile.mkdtemp(prefix='deskilo-directory-')).resolve()
    stack = Stack(root / 'legacy', REPO, 'directory')
    try:
        stack.create()
        # Fixed historical boundary: start before the directory migration.
        for migration in (stack.path / 'supabase/migrations').glob('*.sql'):
            if int(migration.name.split('_')[0]) >= 299:
                migration.unlink()
        stack.start()
        verify_upgrade(stack)
    finally:
        stack.close()
        shutil.rmtree(root)


if __name__ == '__main__':
    main()
