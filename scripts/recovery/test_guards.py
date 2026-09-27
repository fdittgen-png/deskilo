# SPDX-License-Identifier: AGPL-3.0-or-later
"""Recovery refuses unsafe targets and corrupt bytes before external mutations."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from application import main
from runtime import Refused, Stack, command, validate_paths
from reporting import public_json
from verify import objects_from_zip


class RecoveryGuards(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name).resolve()
        self.source, self.target = self.root / 'source', self.root / 'target'

    def test_dry_run_creates_nothing_and_does_not_start_tools(self):
        with patch('runtime.subprocess.run') as run, patch('builtins.print'):
            self.assertEqual(main(['--source', str(self.source), '--target', str(self.target), '--disposable']), 0)
        run.assert_not_called()
        self.assertEqual(list(self.root.iterdir()), [])

    def test_non_disposable_refused_without_tools(self):
        with patch('runtime.subprocess.run') as run, patch('builtins.print'):
            self.assertEqual(main(['--source', str(self.source), '--target', str(self.target), '--apply']), 1)
        run.assert_not_called()

    def test_missing_target_refused_without_tools(self):
        with patch('runtime.subprocess.run') as run, patch('sys.stderr'), self.assertRaises(SystemExit):
            main(['--source', str(self.source), '--disposable', '--apply'])
        run.assert_not_called()

    def test_wrong_runtime_refused_before_requests(self):
        stack = Stack(self.source, self.root, 'source')
        stack.url = 'http://127.0.0.1:12345'
        with self.assertRaisesRegex(Refused, 'stale_runtime_config'):
            stack.require_context('http://127.0.0.1:54321')

    def test_report_canaries_refuse_publication(self):
        for secret in ['password_canary', 'token_canary', 'credential_canary']:
            output = public_json({'status': 'ready', 'accident': secret}, [secret])
            self.assertNotIn(secret, output)
            self.assertEqual(json.loads(output)['status'], 'failed')

    def test_existing_report_not_overwritten(self):
        report = self.root / 'report.json'
        report.write_text('preserve')
        with patch('builtins.print'):
            self.assertEqual(main(['--source', str(self.source), '--target', str(self.target),
                                   '--disposable', '--report', str(report)]), 1)
        self.assertEqual(report.read_text(), 'preserve')

    def test_same_existing_remote_relative_and_symlink_targets_refused(self):
        existing = self.root / 'existing'
        existing.mkdir()
        link = self.root / 'link'
        link.symlink_to(existing)
        cases = [(str(self.source), str(self.source)),
                 (str(self.source), str(existing)),
                 (str(self.source), 'https://project.supabase.co'),
                 (str(self.source), 'relative'),
                 (str(self.source), str(link / 'new'))]
        for source, target in cases:
            with self.subTest(target=target), self.assertRaises(Refused):
                validate_paths(source, target)

    def test_subprocess_failure_and_timeout_never_echo_canaries(self):
        canary = b'password_token_canary'
        failures = [subprocess.CompletedProcess([], 1, canary, canary),
                    subprocess.TimeoutExpired('test', 1, output=canary)]
        for failure in failures:
            with patch.dict('os.environ', {}, clear=True):
                with patch('runtime.subprocess.run') as run:
                    if isinstance(failure, Exception):
                        run.side_effect = failure
                    else:
                        run.return_value = failure
                    with self.assertRaises(Refused) as caught:
                        command(['unused'])
                    self.assertNotIn(canary.decode(), str(caught.exception))

    def archive(self, *, workspace='tenant', name='files/nested/café.png', damage=False):
        data = b'private bytes'
        manifest = {'format_version': 1, 'workspace_id': workspace,
                    'files': [{'path': path, 'bytes': len(data),
                               'sha256': hashlib.sha256(data).hexdigest()}
                              for path in [name, 'files/same.png']]}
        path = self.root / 'workspace.zip'
        with zipfile.ZipFile(path, 'w') as archive:
            archive.writestr('manifest.json', json.dumps(manifest))
            for item in manifest['files']:
                archive.writestr(item['path'], b'changed bytes' if damage else data)
        return path

    def test_unicode_manifest_bytes_are_preserved_without_extraction(self):
        objects = objects_from_zip(self.archive(), 'tenant')
        self.assertEqual(objects[0], ('tenant/nested/café.png', b'private bytes'))

    def test_tenant_swap_traversal_and_byte_damage_are_refused(self):
        for kwargs in [{'workspace': 'other'}, {'name': 'files/../outside'},
                       {'name': 'files//outside'}, {'name': 'files/./outside'}, {'damage': True}]:
            with self.subTest(kwargs=kwargs), self.assertRaises(Refused):
                objects_from_zip(self.archive(**kwargs), 'tenant')


if __name__ == '__main__':
    unittest.main()
