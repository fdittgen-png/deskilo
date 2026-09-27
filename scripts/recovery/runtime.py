# SPDX-License-Identifier: AGPL-3.0-or-later
"""Disposable official local stacks. No remote URLs or existing projects accepted."""
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import urllib.error
import urllib.request

CLI = ['npx', '--yes', 'supabase@2.118.0']


class Refused(Exception):
    """Only fixed, nonsecret check codes leave the harness."""


def command(args, *, data=None, timeout=180, env=None, cwd=None):
    try:
        result = subprocess.run(args, input=data, capture_output=True,
                                timeout=timeout, env=env, cwd=cwd, check=False)
    except subprocess.TimeoutExpired:
        raise Refused('subprocess_timeout') from None
    except OSError:
        raise Refused('subprocess_unavailable') from None
    if result.returncode:
        diagnostic = os.environ.get('DESKILO_RECOVERY_PRIVATE_DIAGNOSTICS')
        if diagnostic:
            private_file(Path(diagnostic) / (secrets.token_hex(8) + '.log'),
                         (result.stderr + result.stdout)[-2 * 1024 * 1024:])
        raise Refused('subprocess_failed') from None
    return result.stdout


def private_file(path, data):
    # The file must be private from creation, not only after chmod.
    with os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'wb') as stream:
        stream.write(data)


def validate_paths(source, target):
    paths = []
    for raw in (source, target):
        if '://' in raw:
            raise Refused('nonlocal_target')
        path = Path(raw)
        if not path.is_absolute() or path.exists() or path.is_symlink():
            raise Refused('target_not_fresh')
        if not path.parent.is_dir() or path.parent.resolve() != path.parent:
            raise Refused('target_parent_not_canonical')
        paths.append(path)
    if paths[0] == paths[1] or paths[0] in paths[1].parents or paths[1] in paths[0].parents:
        raise Refused('source_target_overlap')
    return paths


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class Stack:
    def __init__(self, path, repo, label):
        self.path, self.repo, self.label = path, repo, label
        self.project = 'deskilo-recovery-' + secrets.token_hex(6)
        self.started = False
        self.created = False
        self.credentials = {}
        self.ports = []
        self.reserved_ports = set()

    def create(self):
        self.path.mkdir(mode=0o700)  # exclusive; cleanup owns only this directory
        self.created = True
        (self.path / '.recovery-owner').write_text(self.project)
        root = self.path / 'supabase'
        root.mkdir()
        shutil.copytree(self.repo / 'supabase/migrations', root / 'migrations')
        shutil.copytree(self.repo / 'supabase/tests', root / 'tests')
        holders = []
        try:
            while len(self.ports) < 3:
                sock = socket.socket()
                sock.bind(('127.0.0.1', 0))
                if sock.getsockname()[1] in self.reserved_ports:
                    sock.close()
                    continue
                holders.append(sock)
                self.ports.append(sock.getsockname()[1])
        finally:
            for sock in holders:
                sock.close()
        api, db, shadow = self.ports
        config = f'''project_id = "{self.project}"
[api]
enabled = true
port = {api}
schemas = ["public"]
extra_search_path = ["public", "extensions"]
[db]
port = {db}
shadow_port = {shadow}
major_version = 17
[db.seed]
enabled = false
[auth]
enabled = true
site_url = "https://fdittgen-png.github.io/deskilo/"
additional_redirect_urls = ["deskilo://**", "https://fdittgen-png.github.io/deskilo/**"]
signing_keys_path = "./signing_keys.json"
[auth.email]
enable_signup = true
enable_confirmations = false
[storage]
enabled = true
[studio]
enabled = false
[inbucket]
enabled = false
[analytics]
enabled = false
[realtime]
enabled = false
[edge_runtime]
enabled = false
'''
        (root / 'config.toml').write_text(config)
        key = json.loads(command(CLI + ['gen', 'signing-key', '--algorithm', 'ES256']))
        private_file(root / 'signing_keys.json', json.dumps(key if isinstance(key, list) else [key]).encode())

    def start(self):
        self.started = True  # even a partial start must be cleaned up
        command(CLI + ['start', '--workdir', str(self.path), '--exclude',
                       'studio,postgres-meta,imgproxy,logflare,vector,supavisor,edge-runtime,realtime,mailpit'],
                timeout=1800)
        self.credentials = json.loads(command(CLI + ['status', '--workdir', str(self.path), '-o', 'json']))
        self.url = f'http://127.0.0.1:{self.ports[0]}'
        if self.credentials.get('API_URL') != self.url:
            raise Refused('runtime_target_mismatch')

    def require_context(self, url):
        if url != self.url:
            raise Refused('stale_runtime_config')

    @property
    def db(self):
        return ['docker', 'exec', '-i', 'supabase_db_' + self.project]

    def sql(self, sql):
        return command(self.db + ['psql', '-U', 'postgres', '-d', 'postgres',
                                  '-At', '-v', 'ON_ERROR_STOP=1'], data=sql.encode()).decode().strip()

    def auth_config(self):
        # Read only the actual running container's three nonsecret settings.
        raw = json.loads(command(['docker', 'inspect', 'supabase_auth_' + self.project]))
        values = dict(item.split('=', 1) for item in raw[0]['Config']['Env'] if '=' in item)
        return {'site_url': values.get('GOTRUE_SITE_URL'),
                'uri_allow_list': values.get('GOTRUE_URI_ALLOW_LIST'),
                'mailer_autoconfirm': values.get('GOTRUE_MAILER_AUTOCONFIRM') == 'true'}

    def request(self, method, path, *, token=None, body=None, content_type='application/json', expect=(200,)):
        # Only generated loopback origin; no redirected credentials, no proxy.
        headers = {'apikey': self.credentials['ANON_KEY'],
                   'Authorization': 'Bearer ' + (token or self.credentials['SERVICE_ROLE_KEY']),
                   'Content-Type': content_type}
        payload = body if isinstance(body, bytes) else json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(self.url + path, data=payload, method=method, headers=headers)
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
        try:
            with opener.open(request, timeout=30) as response:
                status, data = response.status, response.read(12 * 1024 * 1024)
        except urllib.error.HTTPError as error:
            status, data = error.code, error.read(65536)
        except (OSError, ValueError):
            raise Refused('http_unavailable') from None
        if status not in expect:
            diagnostic = os.environ.get('DESKILO_RECOVERY_PRIVATE_DIAGNOSTICS')
            if diagnostic:
                private_file(Path(diagnostic) / (secrets.token_hex(8) + '.http'), data)
            if status == 400:
                try:
                    if json.loads(data).get('error') == 'InvalidKey':
                        raise Refused('unicode_storage_key_unsupported')
                except (ValueError, AttributeError):
                    pass  # The stable HTTP status remains the failure.
            raise Refused('http_unexpected_status_' + str(status))
        return data

    def close(self):
        if not self.created:
            return
        if (self.path / '.recovery-owner').read_text() != self.project:
            raise Refused('cleanup_owner_mismatch')
        if self.started:
            command(CLI + ['stop', '--workdir', str(self.path), '--no-backup'], timeout=180)
        shutil.rmtree(self.path)
        self.created = False
