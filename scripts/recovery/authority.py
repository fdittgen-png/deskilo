# SPDX-License-Identifier: AGPL-3.0-or-later
"""A different installation retains its own identity and disabled MCP runtime."""
from runtime import Refused

# These are authority/configuration, not the synthetic business fixture.
EXCLUDED = ['installation_identity', 'identity_authority', 'identity_bindings',
            'database_administrators', 'database_authority_audit',
            'platform_admins', 'platform_access_log', 'mcp_*', 'workspace_mcp_*']


def dump_exclusions():
    return ['--exclude-table-data=public.' + name for name in EXCLUDED]


def identity(stack):
    return stack.sql('select installation_id from public.installation_identity;')


def no_authority(stack):
    tables = stack.sql("select tablename from pg_tables where schemaname='public' "
        "and (tablename like 'mcp_%' or tablename like 'workspace_mcp_%' or "
        "tablename in ('identity_bindings','identity_authority','database_administrators','platform_admins')) "
        "and tablename <> 'mcp_runtime';").splitlines()
    for table in tables:
        if not table.replace('_', '').isalnum():
            raise Refused('authority_catalog_invalid')
        if stack.sql(f'select count(*) from public."{table}";') != '0':
            raise Refused('unexpected_authority')
    if stack.sql('select count(*) from public.mcp_runtime where enabled;') != '0':
        raise Refused('mcp_runtime_enabled')


def retained_target_identity(stack, source_id, target_id):
    if not target_id or target_id == source_id or identity(stack) != target_id:
        raise Refused('installation_identity_not_isolated')
    no_authority(stack)
    if stack.sql('select count(*) from auth.sessions;') != '0':
        raise Refused('source_sessions_transferred')
