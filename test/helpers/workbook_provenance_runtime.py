# SPDX-License-Identifier: AGPL-3.0-or-later
"""#1661: two disposable Auth/PostgREST installations and independent OOXML checks.

DOCKER_HOST=<local socket> python3 test/helpers/workbook_provenance_runtime.py --disposable
Flutter must be on PATH. No remote project, credentials or existing data accepted.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / 'scripts/recovery'))
from runtime import Stack, command, private_file

TEMPLATE = '00000000-0000-4000-8000-000000166101'


def seed(stack, config, enabled):
    ws = config['workspace']
    # Generated UUID returned by the real authenticated create_workspace RPC.
    import uuid
    ws = str(uuid.UUID(ws))
    stack.sql(f"""insert into public.workspace_templates
      (id,key,name,visibility,owner_workspace_id,configuration,entities)
      values ('{TEMPLATE}','same_key','Same name','private','{ws}',
        '{{"workspace":{{"feature_flags":{{"kioskMode":{str(enabled).lower()}}}}}}}',
        '{{features}}')""")
    config['installation'] = stack.sql('select installation_id from public.installation_identity')
    config['template_id'] = TEMPLATE
    config['stranger'] = json.loads(stack.request('POST', '/auth/v1/signup',
        token=stack.credentials['ANON_KEY'], body={'email': 'stranger@workbook.deskilo.test',
        'password': secrets.token_urlsafe(24) + 'aA1!'}))


def verify(root, configs):
    ns = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
    for i, config in enumerate(configs):
        data = (root / f'{i}.xlsx').read_bytes()
        with zipfile.ZipFile(root / f'{i}.xlsx') as archive:
            texts = [archive.read(n).decode() for n in archive.namelist() if n.endswith('.xml')]
            all_text = '\n'.join(texts)
            assert config['url'] not in all_text
            assert config['session']['user']['id'] not in all_text
            assert config['session']['access_token'] not in all_text
            for name in archive.namelist():
                assert not any(x in name.lower() for x in ('externallink', 'vba', 'connection'))
            assert not any(e.tag.endswith('}f') for text in texts for e in ET.fromstring(text).iter())
            def rows(number):
                tree = ET.fromstring(archive.read(f'xl/worksheets/sheet{number}.xml'))
                return [[(''.join(c.itertext())) for c in row.findall('s:c', ns)]
                        for row in tree.findall('.//s:row', ns)]
            template_rows = rows(2)
            record = dict(zip(template_rows[0], template_rows[1]))
            source = hashlib.sha256((config['url'] + '/rest/v1').encode()).hexdigest()
            assert record['source_id'] == source
            assert record['installation_id'] == config['installation']
            assert record['template_id'] == TEMPLATE
            assert record['scoped_template_id'] == f"{source}:{config['installation']}:{TEMPLATE}"
            feature = next(row for row in rows(4) if row[0] == 'kioskMode')
            assert feature[2] == ('true' if i else 'false')
        print(f'installation {i}: independent XML source/value/exclusion checks passed; sha256={hashlib.sha256(data).hexdigest()}')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--disposable', action='store_true', required=True)
    parser.parse_args()
    root = Path(tempfile.mkdtemp(prefix='deskilo-workbook-')).resolve()
    stacks, configs = [], []
    try:
        for i in range(2):
            stack = Stack(root / str(i), REPO, f'workbook-{i}')
            stacks.append(stack)
            stack.create()
            stack.start()
            password = secrets.token_urlsafe(24) + 'aA1!'
            user = json.loads(stack.request('POST', '/auth/v1/signup', token=stack.credentials['ANON_KEY'],
                body={'email': 'owner@workbook.deskilo.test', 'password': password}))
            workspace = json.loads(stack.request('POST', '/rest/v1/rpc/create_workspace', token=user['access_token'],
                body={'p_name': 'Workbook fixture', 'p_country_code': 'FR', 'p_currency_code': 'EUR',
                      'p_timezone': 'Europe/Paris', 'p_environment': 'dev', 'p_with_twin': False, 'p_feature_flags': {}}))
            config = {'url': stack.url, 'key': stack.credentials['ANON_KEY'], 'session': user,
                      'workspace': workspace, 'password': password}
            seed(stack, config, bool(i))
            configs.append(config)
        private_file(root / 'sessions.json', json.dumps(configs).encode())
        before = [stack.sql('select md5(string_agg(row_to_json(t)::text, chr(10) order by id)) from public.workspace_templates t')
                  for stack in stacks]
        for i, stack in enumerate(stacks):
            stack.request('POST', '/rest/v1/rpc/inspect_workspace_template',
                body={'p_template_id': TEMPLATE}, token=configs[1-i]['session']['access_token'], expect=(401, 403))
        env = dict(os.environ, DESKILO_WORKBOOK_FIXTURE=str(root / 'sessions.json'))
        result = command(['flutter', 'test', '--no-pub',
            'test/features/workspace/application/workbook_provenance_runtime_test.dart'], cwd=REPO, env=env, timeout=180)
        print(result.decode())
        verify(root, configs)
        assert before == [stack.sql('select md5(string_agg(row_to_json(t)::text, chr(10) order by id)) from public.workspace_templates t')
                          for stack in stacks], 'export mutated template data'
    finally:
        for stack in reversed(stacks):
            stack.close()
        shutil.rmtree(root)


if __name__ == '__main__':
    main()
