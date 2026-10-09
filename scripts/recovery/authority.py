# SPDX-License-Identifier: AGPL-3.0-or-later
"""A different installation retains its own identity and disabled MCP runtime."""
from fnmatch import fnmatchcase
from runtime import Refused

# These are authority/configuration, not the synthetic business fixture.
EXCLUDED = ['installation_identity', 'identity_authority', 'identity_bindings',
            'identity_federation_clients',
            'database_administrators', 'database_authority_audit',
            'platform_admins', 'platform_access_log', 'mcp_*', 'workspace_mcp_*']
SETTINGS = ('mcp_limits', 'mcp_disclosure_maximum', 'mcp_installation_settings')


def dump_exclusions():
    return ['--exclude-table-data=public.' + name for name in EXCLUDED]


def identity(stack):
    return stack.sql('select installation_id from public.installation_identity;')


def configuration(stack):
    return {table: stack.sql(f'select coalesce(jsonb_agg(to_jsonb(t) order by singleton), '
                            f"'[]'::jsonb) from public.\"{table}\" t;")
            for table in SETTINGS}


def restore_table_list(stack):
    # Restore and dump share the same exclusions: fresh target settings
    # must neither be replaced by source settings nor erased by TRUNCATE.
    tables = stack.sql("select tablename from pg_tables where schemaname='public' order by tablename;").splitlines()
    if any(not name.replace('_', '').isalnum() for name in tables):
        raise Refused('restore_catalog_invalid')
    restored = [f'public."{name}"' for name in tables
                if not any(fnmatchcase(name, pattern) for pattern in EXCLUDED)]
    return ','.join(restored + ['auth.users', 'auth.identities'])


def no_authority(stack):
    tables = stack.sql("select tablename from pg_tables where schemaname='public' "
        "and (tablename like 'mcp_%' or tablename like 'workspace_mcp_%' or "
        "tablename in ('identity_bindings','identity_authority','identity_federation_clients','database_administrators','platform_admins')) "
        "and tablename <> 'mcp_runtime';").splitlines()
    for table in tables:
        if not table.replace('_', '').isalnum():
            raise Refused('authority_catalog_invalid')
        # Singleton settings are installed by migrations, not account grants.
        # They never travel in the dump and the target retains its own copy.
        if table in SETTINGS:
            continue
        if stack.sql(f'select count(*) from public."{table}";') != '0':
            raise Refused('unexpected_authority')
    if stack.sql('select count(*) from public.mcp_runtime where enabled;') != '0':
        raise Refused('mcp_runtime_enabled')


def retained_target_identity(stack, source_id, target_id, target_configuration):
    if not target_id or target_id == source_id or identity(stack) != target_id:
        raise Refused('installation_identity_not_isolated')
    no_authority(stack)
    if configuration(stack) != target_configuration:
        raise Refused('target_configuration_changed')
    if stack.sql('select count(*) from auth.sessions;') != '0':
        raise Refused('source_sessions_transferred')
