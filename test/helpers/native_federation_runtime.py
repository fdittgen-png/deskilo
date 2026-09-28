# SPDX-License-Identifier: AGPL-3.0-or-later
"""#1791: real canonical Auth and two target Auth installations, no production data.

The pinned Auth rejects private OIDC discovery URLs. An explicitly requested
temporary HTTPS tunnel exposes ONLY the disposable authority's OAuth endpoints,
behind an unguessable path. Signup, admin, SQL, REST and storage stay private.
Requires cloudflared; never accepts a remote project, identity or credential.
"""
import argparse
import base64
import hashlib
import http.server
import json
import ipaddress
import re
import secrets
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / 'scripts/recovery'))
from runtime import Stack, NoRedirect, Refused, command, private_file


def raw(url, method='GET', body=None, headers=None):
    headers = dict(headers or {})
    if body is not None:
        headers.setdefault('Content-Type', 'application/json')
        body = body if isinstance(body, bytes) else json.dumps(body).encode()
    request = urllib.request.Request(url, method=method, data=body, headers=headers)
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    try:
        with opener.open(request, timeout=30) as response:
            return response.status, response.headers, response.read(1024 * 1024)
    except urllib.error.HTTPError as error:
        return error.code, error.headers, error.read(65536)


class OAuthProxy(http.server.BaseHTTPRequestHandler):
    upstream = ''
    prefix = ''
    public_key = ''
    allowed = {'/.well-known/openid-configuration', '/.well-known/jwks.json',
               '/oauth/authorize', '/oauth/token', '/oauth/userinfo'}

    def log_message(self, *args):
        pass  # No request URI, code, token or Authorization header is logged.

    def do_GET(self):
        path = urllib.parse.urlsplit(self.path)
        if not path.path.startswith(self.prefix) or path.path[len(self.prefix):] not in self.allowed:
            self.send_error(404)
            return
        size = int(self.headers.get('Content-Length', '0'))
        if size < 0 or size > 32768:
            self.send_error(413)
            return
        headers = {key: self.headers[key] for key in ('Authorization', 'Content-Type') if key in self.headers}
        headers['apikey'] = self.public_key
        destination = self.upstream + '/auth/v1' + self.path[len(self.prefix):]
        try:
            status, response_headers, data = raw(destination, self.command,
                self.rfile.read(size) if size else None, headers)
            self.send_response(status)
            for key in ('Content-Type', 'Location', 'Cache-Control'):
                if key in response_headers:
                    self.send_header(key, response_headers[key])
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except (OSError, ValueError):
            self.send_error(502)

    do_POST = do_GET


def change_fixture_issuer(stack, issuer, root, public_host=None):
    """Recreate only our disposable Auth container with its supported JWT issuer.

    Secrets remain in a mode-0600 env file, never command-line arguments/logs.
    No database, migration or security validation is bypassed.
    """
    name = 'supabase_auth_' + stack.project
    inspected = json.loads(command(['docker', 'inspect', name]))[0]
    assert not inspected['Mounts'], 'unexpected_auth_mount'
    network = next(iter(inspected['NetworkSettings']['Networks']))
    env = dict(item.split('=', 1) for item in inspected['Config']['Env'] if '=' in item)
    if issuer is not None:
        env['GOTRUE_JWT_ISSUER'] = issuer
    env_file = root / 'canonical-auth.env'
    private_file(env_file, '\n'.join(key + '=' + value for key, value in env.items()).encode())
    args = ['docker', 'run', '-d', '--name', name, '--network', network, '--env-file', str(env_file)]
    if public_host:
        args += ['--add-host', ':'.join(public_host)]
    for key, value in inspected['Config']['Labels'].items():
        args += ['--label', key + '=' + value]
    args += [inspected['Config']['Image']]
    command(['docker', 'rm', '-f', name])
    command(args)
    env_file.unlink()
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        try:
            if raw(stack.url + '/auth/v1/health', headers={'apikey': stack.credentials['ANON_KEY']})[0] == 200:
                return
        except OSError:
            pass
        time.sleep(.2)
    raise Refused('fixture_auth_restart_failed')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--disposable', action='store_true', required=True)
    parser.add_argument('--public-test-tunnel', action='store_true', required=True)
    parser.parse_args()
    root = Path(tempfile.mkdtemp(prefix='deskilo-native-federation-')).resolve()
    canonical = Stack(root / 'canonical', REPO, 'canonical')
    targets = [Stack(root / name, REPO, name) for name in ('target-a', 'target-b')]
    tunnel = None
    server = None
    checks = []
    try:
        for stack in [canonical] + targets:
            stack.create()
        config = canonical.path / 'supabase/config.toml'
        config.write_text(config.read_text() + '\n[auth.oauth_server]\nenabled = true\n'
            'authorization_url_path = "/oauth/consent"\nallow_dynamic_registration = false\n'
            '[auth.hook.custom_access_token]\nenabled = true\n'
            'uri = "pg-functions://postgres/public/identity_federation_token_hook"\n')
        OAuthProxy.prefix = '/' + secrets.token_urlsafe(24) + '/auth/v1'
        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), OAuthProxy)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        tunnel_log = root / 'tunnel.log'
        empty_config = root / 'tunnel.yml'
        empty_config.write_text('{}\n')
        with tunnel_log.open('wb') as output:
            tunnel = subprocess.Popen(['cloudflared', 'tunnel', '--config', str(empty_config),
                '--no-autoupdate', '--protocol', 'http2', '--url',
                'http://127.0.0.1:' + str(server.server_port)], stdout=output, stderr=output)
        deadline = time.monotonic() + 60
        public_url = None
        while time.monotonic() < deadline and tunnel.poll() is None:
            text = tunnel_log.read_text()
            urls = [url for url in re.findall(r'https://[a-z0-9-]+\.trycloudflare\.com', text)
                    if urllib.parse.urlsplit(url).hostname != 'api.trycloudflare.com']
            if urls and 'Registered tunnel connection' in text:
                public_url = urls[0]
                break
            time.sleep(.25)
        if public_url is None:
            raise Refused('temporary_https_unavailable')
        issuer = public_url + OAuthProxy.prefix
        # Some developer resolvers omit newly allocated tunnel names. Resolve
        # this owned hostname through public DNS; pin only its public address
        # inside this process and these disposable containers. TLS hostname,
        # issuer and Auth's public-address validation remain enabled.
        hostname = urllib.parse.urlsplit(public_url).hostname
        deadline = time.monotonic() + 60
        while True:
            status, _, data = raw('https://cloudflare-dns.com/dns-query?' +
                urllib.parse.urlencode({'name': hostname, 'type': 'A'}),
                headers={'accept': 'application/dns-json'})
            answers = json.loads(data) if status == 200 else {}
            addresses = [entry['data'] for entry in answers.get('Answer', [])
                         if entry.get('type') == 1]
            if addresses and all(ipaddress.ip_address(ip).is_global for ip in addresses):
                break
            if time.monotonic() > deadline:
                raise Refused('temporary_public_dns_unavailable')
            time.sleep(1)
        public_ip = addresses[0]
        original_lookup = socket.getaddrinfo
        def fixture_lookup(host, *args, **kwargs):
            return original_lookup(public_ip if host == hostname else host, *args, **kwargs)
        socket.getaddrinfo = fixture_lookup
        print('HTTPS transport ready; starting disposable canonical Auth and two targets', flush=True)
        for stack in [canonical] + targets:
            stack.start()
            print('Disposable stack ready: ' + stack.project.rsplit('-', 1)[-1], flush=True)
        OAuthProxy.upstream = canonical.url
        OAuthProxy.public_key = canonical.credentials['ANON_KEY']
        change_fixture_issuer(canonical, issuer, root, (hostname, public_ip))
        for target in targets:
            change_fixture_issuer(target, None, root, (hostname, public_ip))
        deadline = time.monotonic() + 45
        while True:
            try:
                status, _, data = raw(issuer + '/.well-known/openid-configuration')
                if status == 200 and json.loads(data)['issuer'] == issuer:
                    break
            except (OSError, ValueError):
                pass  # A new temporary hostname can precede DNS propagation.
            if time.monotonic() > deadline:
                raise Refused('temporary_discovery_unavailable')
            time.sleep(.5)
        assert raw(public_url + '/auth/v1/admin/users')[0] == 404
        signup = json.loads(canonical.request('POST', '/auth/v1/signup',
            token=canonical.credentials['ANON_KEY'], body={'email': 'one@federation.deskilo.test',
            'password': secrets.token_urlsafe(24) + 'aA1!'}))
        native = signup['access_token']
        canonical_id = signup['user']['id']
        checks.append('one_product_registration_only')
        local_users = []
        for target in targets:
            installation = target.sql('select installation_id from public.installation_identity')
            assert target.sql('select count(*) from public.workspaces') == '0'
            assert target.sql('select count(*) from public.database_administrators') == '0'
            callback = target.url + '/auth/v1/callback'
            client = json.loads(canonical.request('POST', '/auth/v1/admin/oauth/clients', body={
                'client_name': 'Disposable target', 'client_type': 'confidential',
                'redirect_uris': [callback], 'token_endpoint_auth_method': 'client_secret_basic',
                'grant_types': ['authorization_code', 'refresh_token'], 'response_types': ['code']}, expect=(200, 201)))
            cid = client['client_id']
            canonical.sql("select public.operator_register_identity_federation_client('" + cid + "','" +
                installation + "','" + target.url + "/auth/v1'); select public.operator_set_identity_federation_client('" + cid + "',true)")
            target.request('POST', '/auth/v1/admin/custom-providers', body={
                'identifier': 'custom:deskilo', 'provider_type': 'oidc', 'name': 'Deskilo',
                'issuer': issuer, 'client_id': cid, 'client_secret': client['client_secret'],
                'scopes': ['openid', 'profile'], 'email_optional': True, 'pkce_enabled': True,
                'skip_nonce_check': False, 'enabled': True}, expect=(200, 201))
            target.sql("insert into public.identity_authority(kind,issuer,oidc_provider) values ('oidc','" +
                       issuer + "','custom:deskilo')")
            verifier = secrets.token_urlsafe(48)
            challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).decode().rstrip('=')
            redirect = 'deskilo://auth-callback'
            query = urllib.parse.urlencode({'provider': 'custom:deskilo', 'redirect_to': redirect,
                'code_challenge': challenge, 'code_challenge_method': 's256'})
            status, headers, _ = raw(target.url + '/auth/v1/authorize?' + query)
            assert status in (302, 303), 'target_authorize_refused'
            location = headers['Location']
            assert location.startswith(issuer + '/oauth/authorize?'), 'foreign_authority'
            status, headers, _ = raw(location)
            assert status in (302, 303), 'canonical_authorize_refused'
            aid = urllib.parse.parse_qs(urllib.parse.urlsplit(headers['Location']).query)['authorization_id'][0]
            details = json.loads(canonical.request('GET', '/auth/v1/oauth/authorizations/' + aid, token=native))
            assert details['client']['id'] == cid and details['scope'] == 'openid profile'
            approved = json.loads(canonical.request('POST', '/auth/v1/oauth/authorizations/' + aid + '/consent',
                token=native, body={'action': 'approve'}))
            returned = approved['redirect_url']
            assert returned.startswith(callback + '?'), 'foreign_target_callback'
            status, headers, _ = raw(returned)
            assert status in (302, 303), 'target_callback_refused'
            returned = urllib.parse.urlsplit(headers['Location'])
            assert returned.scheme == 'deskilo' and returned.netloc == 'auth-callback'
            query = urllib.parse.parse_qs(returned.query)
            assert 'code' in query, 'target_did_not_issue_native_code'
            session = json.loads(target.request('POST', '/auth/v1/token?grant_type=pkce',
                token=target.credentials['ANON_KEY'], body={'auth_code': query['code'][0], 'code_verifier': verifier}))
            local_id = session['user']['id']
            binding = json.loads(target.request('POST', '/rest/v1/rpc/finalize_identity_binding',
                token=session['access_token'], body={}))
            assert binding['status'] == 'verified' and binding['issuer'] == issuer
            assert target.sql("select subject from public.identity_bindings where local_user_id='" + local_id + "'") == canonical_id
            assert target.sql('select count(*) from public.members') == '0'
            assert target.sql('select count(*) from public.database_administrators') == '0'
            assert target.sql('select count(*) from public.profiles where person_id is not null') == '1'
            assert target.sql("select count(*) from auth.users where coalesce(encrypted_password,'')<>''") == '0'
            local_users.append((local_id, session['access_token']))
            checks.append('real_oidc_target_' + str(len(local_users)) + '_native_binding_without_signup_or_rights')
        assert len({canonical_id, *(item[0] for item in local_users)}) == 3
        for token in [native, local_users[0][1]]:
            status, _, _ = raw(targets[1].url + '/rest/v1/profiles?select=id', headers={
                'apikey': targets[1].credentials['ANON_KEY'], 'Authorization': 'Bearer ' + token})
            assert status in (401, 403), 'foreign_token_accepted'
        checks.append('canonical_and_target_a_tokens_refused_at_target_b')
        print(json.dumps({'status': 'pass', 'checks': checks, 'auth': 'v2.197.0',
            'cli': '2.118.0', 'schema': 299, 'transport': 'temporary_https_oauth_only',
            'not_exercised': ['physical_provider_accounts', 'physical_devices', 'hosted_project']}), flush=True)
    finally:
        if tunnel is not None:
            tunnel.terminate()
            try:
                tunnel.wait(timeout=15)
            except subprocess.TimeoutExpired:
                tunnel.kill()
                tunnel.wait(timeout=5)
        if server is not None:
            server.shutdown()
            server.server_close()
        for stack in targets + [canonical]:
            stack.close()
        shutil.rmtree(root)


if __name__ == '__main__':
    main()
