# SPDX-License-Identifier: AGPL-3.0-or-later
"""Reuse the native workspace ZIP manifest and verify actual private object bytes."""
import hashlib
import json
from urllib.parse import quote
import zipfile

from runtime import Refused

TABLES = 'workspaces members levels offices desks seats reservations invoices ledger_entries invoice_matches'.split()


def financial_snapshot(stack):
    return {table: stack.sql(f"select count(*)::text || ':' || md5(coalesce(string_agg(row_to_json(t)::text, '|' order by row_to_json(t)::text), '')) from public.{table} t;") for table in TABLES}


def objects_from_zip(path, workspace):
    objects = []
    with zipfile.ZipFile(path) as archive:
        info = archive.getinfo('manifest.json')
        if info.file_size > 65536:
            raise Refused('manifest_oversized')
        manifest = json.loads(archive.read(info))
        if manifest.get('format_version') != 1 or manifest.get('workspace_id') != workspace:
            raise Refused('manifest_wrong_context')
        files = manifest.get('files')
        if not isinstance(files, list) or len(files) != 2:
            raise Refused('manifest_inventory')
        seen = set()
        for item in files:
            name = item.get('path', '')
            parts = name.split('/')
            if not name.startswith('files/') or any(p in ('', '.', '..') for p in parts) or '\\' in name or name in seen:
                raise Refused('manifest_unsafe_path')
            seen.add(name)
            info = archive.getinfo(name)
            if info.file_size > 10485760 or info.file_size != item.get('bytes'):
                raise Refused('object_size')
            data = archive.read(info)
            if hashlib.sha256(data).hexdigest() != item.get('sha256'):
                raise Refused('object_checksum')
            objects.append((workspace + '/' + name[6:], data))
    return objects


def upload(stack, path, data, *, method='POST', token=None):
    stack.request(method, '/storage/v1/object/floor-plans/' + quote(path, safe='/'),
                  token=token, body=data, content_type='image/png', expect=(200, 201))


def verify_objects(stack, objects):
    try:
        bucket = json.loads(stack.request('GET', '/storage/v1/bucket/floor-plans'))
    except Refused:
        raise Refused('bucket_inaccessible') from None
    if bucket.get('public') is not False:
        raise Refused('bucket_not_private')
    for path, expected in objects:
        try:
            data = stack.request('GET', '/storage/v1/object/floor-plans/' + quote(path, safe='/'))
        except Refused:
            raise Refused('object_missing_or_inaccessible') from None
        if hashlib.sha256(data).digest() != hashlib.sha256(expected).digest():
            raise Refused('object_checksum')


def expect_failure(action, code):
    try:
        action()
    except Refused as error:
        if str(error) == code:
            return
        raise Refused('negative_wrong_failure') from None
    raise Refused('negative_not_detected')


def negative_objects(stack, objects):
    path, data = objects[0]
    stack.request('DELETE', '/storage/v1/object/floor-plans', body={'prefixes': [path]})
    expect_failure(lambda: verify_objects(stack, objects), 'object_missing_or_inaccessible')
    upload(stack, path, data)
    upload(stack, path, data + b'changed', method='PUT')
    expect_failure(lambda: verify_objects(stack, objects), 'object_checksum')
    upload(stack, path, data, method='PUT')
    upload(stack, path, objects[-1][1], method='PUT')
    expect_failure(lambda: verify_objects(stack, objects), 'object_checksum')
    upload(stack, path, data, method='PUT')
    stack.request('PUT', '/storage/v1/bucket/floor-plans', body={'public': True})
    expect_failure(lambda: verify_objects(stack, objects), 'bucket_not_private')
    stack.request('PUT', '/storage/v1/bucket/floor-plans', body={'public': False})
    privileged = stack.credentials['SERVICE_ROLE_KEY']
    try:
        stack.credentials['SERVICE_ROLE_KEY'] = stack.credentials['ANON_KEY']
        expect_failure(lambda: verify_objects(stack, objects), 'bucket_inaccessible')
    finally:
        stack.credentials['SERVICE_ROLE_KEY'] = privileged
    verify_objects(stack, objects)
