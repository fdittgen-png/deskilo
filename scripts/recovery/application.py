#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""#1641: real local DB + Storage + Auth recovery, with scoped safe results."""
import argparse
import base64
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import secrets
import tempfile
import time

from runtime import CLI, Refused, Stack, command, private_file, validate_paths
from verify import financial_snapshot, objects_from_zip, upload, verify_objects, negative_objects, expect_failure
from authority import dump_exclusions, identity, no_authority, retained_target_identity
from reporting import Timings, environment, public_json

REPO = Path(__file__).resolve().parents[2]
SECRET_KEYS = ['ANON_KEY', 'SERVICE_ROLE_KEY', 'JWT_SECRET', 'SECRET_KEY',
               'S3_PROTOCOL_ACCESS_KEY_SECRET']
DATABASE_TESTS = ['12_storage_tenancy.sql', '20_money_invariants.sql',
                  '22_reconciliation.sql', '23_domain_invariants.sql', '28_schema_version.sql']


def run(args):
    paths = validate_paths(args.source, args.target)
    if not args.disposable:
        raise Refused('disposable_ack_required')
    if not args.apply:
        return {'format': 'deskilo.recovery', 'version': 1, 'status': 'planned'}
    source, target = [Stack(path, REPO, label) for path, label in zip(paths, ['source', 'target'])]
    report = {'format': 'deskilo.recovery', 'version': 1, 'status': 'failed',
              'scope': 'disposable_local_only', 'cli': '2.118.0',
              'limitations': ['raw_unicode_storage_keys_unsupported', 'email_delivery_not_exercised'],
              'mcp': 'not_exercised', 'hosted': 'not_exercised', 'checks': {}}
    phase = 'source_start'
    started = time.monotonic()
    timings = Timings()
    sensitive = []
    try:
        with tempfile.TemporaryDirectory(prefix='deskilo-recovery-artifacts-') as tmp:
            artifacts = Path(tmp)
            source.create()
            source.start()
            sensitive.extend(source.credentials.get(key, '') for key in SECRET_KEYS)
            report['environment'] = environment(source)
            report['checks'][phase] = 'pass'
            timings.finish(phase)
            phase = 'database_regressions'
            tap = command(CLI + ['test', 'db', '--local', '--workdir', str(source.path)] +
                [str(source.path / 'supabase/tests/database' / name) for name in DATABASE_TESTS], timeout=180)
            totals = re.search(rb'Files=(\d+), Tests=(\d+)', tap)
            if b'Result: PASS' not in tap or not totals or int(totals[1]) != len(DATABASE_TESTS) or int(totals[2]) == 0:
                raise Refused('database_test_report_missing')
            report['database_regressions'] = {'files': DATABASE_TESTS, 'assertions': int(totals[2])}
            report['checks'][phase] = 'pass'
            timings.finish(phase)
            phase = 'registered_users'
            users = []
            password = secrets.token_urlsafe(24) + 'aA1!'
            sensitive.append(password)
            for suffix in ['a', 'b']:
                email = f'restore-{suffix}@deskilo.test'
                # Registration is through real Auth, never a SQL-claims substitute.
                value = json.loads(source.request('POST', '/auth/v1/signup',
                    body={'email': email, 'password': password}, token=source.credentials['ANON_KEY']))
                users.append({'id': value['user']['id'], 'email': email, 'password': password})
            seed = (REPO / 'supabase/restore/seed.sql').read_text()
            import uuid
            a, b = [str(uuid.UUID(user['id'])) for user in users]
            source.sql(f"set deskilo.restore.precreated_auth = 'true'; set deskilo.restore.user_a = '{a}'; set deskilo.restore.user_b = '{b}';\n" + seed)
            report['checks'][phase] = 'pass'
            phase = 'source_private_objects'
            rows = json.loads(source.sql("select json_agg(json_build_object('workspace', w.id, 'member', m.id, 'period', to_char(now(),'YYYY-MM')) order by w.name) from public.workspaces w join public.members m on m.workspace_id=w.id;"))
            png = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j4ZkAAAAASUVORK5CYII=')
            for index, user in enumerate(users):
                user.update(rows[index])
                session = json.loads(source.request('POST', '/auth/v1/token?grant_type=password',
                    token=source.credentials['ANON_KEY'], body={'email': user['email'], 'password': password}))
                expect_failure(lambda: upload(source, user['workspace'] + '/café.png', png,
                    token=session['access_token']), 'unicode_storage_key_unsupported')
                sensitive.extend([session['access_token'], session['refresh_token']])
                for name in ['same.png', 'nested/cafe.png']:
                    upload(source, user['workspace'] + '/' + name, png + bytes([index]) + name.encode(), token=session['access_token'])
            fixture = {'disposable': True, 'phase': 'source', 'url': source.url,
                       'anon_key': source.credentials['ANON_KEY'], 'users': users,
                       'container': 'supabase_db_' + source.project,
                       'auth_config': source.auth_config(),
                       'artifacts': str(artifacts), 'captured_at': datetime.now(timezone.utc).isoformat()}
            fixture_path = artifacts / 'native.json'
            private_file(fixture_path, json.dumps(fixture).encode())
            def native():
                active = source if fixture['phase'] == 'source' else target
                active.require_context(fixture['url'])
                expect_failure(lambda: active.require_context('http://127.0.0.1:1'), 'stale_runtime_config')
                environment = dict(os.environ, DESKILO_RECOVERY_FIXTURE=str(fixture_path))
                command(['flutter', 'test', '--no-pub', 'test/core/instance/local_recovery_test.dart'],
                        timeout=300, env=environment, cwd=REPO)
                if json.loads(fixture_path.read_text()).get('completed') != fixture['phase']:
                    raise Refused('native_report_missing')
            phase = 'source_native_export'
            native()
            fixture = json.loads(fixture_path.read_text())
            objects = [item for i, user in enumerate(users)
                       for item in objects_from_zip(artifacts / f'workspace-{i}.zip', user['workspace'])]
            report['checks'][phase] = 'pass'
            timings.finish('source_auth_files_and_native_export')
            phase = 'existing_database_drill'
            command(['bash', 'scripts/restore_check.sh'], timeout=300, cwd=REPO, env=dict(os.environ,
                DESKILO_RESTORE_CONTAINER='supabase_db_' + source.project,
                DESKILO_RESTORE_COPY_DB='restore_' + secrets.token_hex(6), DESKILO_RESTORE_SKIP_SEED='1',
                TMPDIR=str(artifacts)))
            before = financial_snapshot(source)
            report['checks'][phase] = 'pass'
            timings.finish(phase)
            phase = 'database_backup'
            no_authority(source)
            source_id = identity(source)
            # #1648: a real protected client row must not travel to the clone.
            source.sql("select public.operator_register_identity_federation_client("
                "gen_random_uuid(), gen_random_uuid(), 'https://recovery.invalid/auth/v1');")
            # Recover synthetic accounts and identities, never active sessions,
            # refresh tokens, MFA/OAuth configuration or external credentials.
            dump = command(source.db + ['pg_dump', '-U', 'postgres', '-d', 'postgres',
                '--data-only', '--disable-triggers', '--no-owner', '--no-privileges',
                '--table=public.*', '--table=auth.users', '--table=auth.identities'] + dump_exclusions())
            if not dump:
                raise Refused('database_backup_empty')
            private_file(artifacts / 'database.sql', dump)
            timings.finish(phase)
            source.close()
            phase = 'target_start'
            target.reserved_ports.update(source.ports)
            target.create()
            target.start()
            sensitive.extend(target.credentials.get(key, '') for key in SECRET_KEYS)
            timings.finish('replace_source_with_target')
            target_id = identity(target)
            phase = 'database_restore'
            tables = target.sql("select string_agg(format('%I.%I',schemaname,tablename), ',') from pg_tables where (schemaname='public' and tablename not in ('installation_identity','mcp_runtime')) or (schemaname='auth' and tablename in ('users','identities'));")
            target.sql('truncate ' + tables + ' cascade;')
            command(target.db + ['psql', '-U', 'supabase_admin', '-d', 'postgres', '-q',
                '--single-transaction', '-v', 'ON_ERROR_STOP=1'], data=dump)
            if financial_snapshot(target) != before:
                raise Refused('financial_snapshot_mismatch')
            retained_target_identity(target, source_id, target_id)
            report['checks'][phase] = 'pass'
            timings.finish(phase)
            phase = 'storage_restore'
            for path, data in objects:
                upload(target, path, data)
            verify_objects(target, objects)
            report['checks'][phase] = 'pass'
            timings.finish(phase)
            phase = 'target_native_auth_and_reads'
            fixture.update(phase='target', url=target.url, anon_key=target.credentials['ANON_KEY'],
                container='supabase_db_' + target.project, auth_config=target.auth_config())
            fixture_path.write_text(json.dumps(fixture))
            native()
            report['checks'][phase] = 'pass'
            timings.finish(phase)
            phase = 'storage_damage_detection'
            negative_objects(target, objects)
            report['checks'][phase] = 'pass'
            timings.finish(phase)
            report['status'] = 'ready'
    except Refused as error:
        report['checks'][phase] = str(error)
        timings.finish(phase + '_failed')
    except Exception:
        report['checks'][phase] = 'unexpected_source_shape'
        timings.finish(phase + '_failed')
    finally:
        for stack in (target, source):
            try:
                stack.close()
            except Exception:
                report['checks']['cleanup_' + stack.label] = 'failed'
                report['status'] = 'failed'
        report['elapsed_seconds'] = round(time.monotonic() - started, 3)
        timings.finish('cleanup')
        report['timings_seconds'] = timings.values
    return json.loads(public_json(report, sensitive))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, help='Fresh absolute local project directory')
    parser.add_argument('--target', required=True, help='Different fresh absolute local project directory')
    parser.add_argument('--disposable', action='store_true')
    parser.add_argument('--apply', action='store_true', help='Without this, only a plan is produced')
    parser.add_argument('--report', help='New file for a nonsecret scoped result')
    parser.add_argument('--private-diagnostics', help='Existing private directory for failed subprocess output; never included in the report')
    args = parser.parse_args(argv)
    if args.private_diagnostics:
        diagnostic = Path(args.private_diagnostics)
        if not diagnostic.is_dir() or diagnostic.is_symlink() or diagnostic.stat().st_mode & 0o077:
            parser.error('diagnostics directory must be private')
        os.environ['DESKILO_RECOVERY_PRIVATE_DIAGNOSTICS'] = str(diagnostic)
    try:
        report = run(args)
    except Refused as error:
        report = {'format': 'deskilo.recovery', 'version': 1, 'status': 'refused', 'check': str(error)}
    output = json.dumps(report, indent=2) + '\n'
    if args.report:
        try:
            private_file(Path(args.report), output.encode())
        except OSError:
            print(json.dumps({'format': 'deskilo.recovery', 'version': 1,
                              'status': 'failed', 'check': 'report_write_failed'}))
            return 1
    print(output, end='')
    return 0 if report['status'] in ('planned', 'ready') else 1


if __name__ == '__main__':
    raise SystemExit(main())
