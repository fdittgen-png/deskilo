// SPDX-License-Identifier: 0BSD
//
// #1313 — the structural half of the doctor: does this live project carry
// the security the migrations build?
//
// Read-only, and deliberately apart from the behavioural tenancy matrix
// (`supabase/tests/database/11_tenancy_matrix.sql`), which writes fixtures
// and must never touch a customer's project. These questions are asked of
// the catalogue: which policies exist, how storage reads are scoped, and
// four hardening properties that are clean today and must stay so.
//
// Its own file because the doctor is already long, and because these are
// pure functions over rows: the tests drive them directly.
import 'instance_doctor.dart';

/// #1313 — every row-level policy the project carries, by name.
const String policyDriftSql = '''
select coalesce(string_agg(schemaname || '.' || tablename || '.' || policyname,
                         ',' order by schemaname || '.' || tablename || '.' || policyname), '')
  as policies
from pg_policies where schemaname in ('public', 'storage');
''';

/// The permissive READ policies on storage objects, with their predicate.
const String storageReadPolicySql = '''
select coalesce(string_agg(policyname || ' :: ' || coalesce(qual, ''), '|' order by policyname), '')
  as read_policies
from pg_policies
 where schemaname = 'storage' and tablename = 'objects'
 and permissive = 'PERMISSIVE' and cmd in ('SELECT', 'ALL');
''';

/// #1313 — four structural guards that are clean today and must stay so:
/// realtime publishes only protected tables, every definer function has a
/// fixed search_path, no view hands `anon` its owner's rights, the tables
/// holding secrets grant nothing to the API roles, and no bucket is public.
const String guardHealthSql = '''
select
(select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
   from pg_publication_rel pr
   join pg_class c on c.oid = pr.prrelid
   join pg_publication p on p.oid = pr.prpubid
  where p.pubname = 'supabase_realtime'
    and (not c.relrowsecurity
         or not exists (select 1 from pg_policy pol where pol.polrelid = c.oid)))
  as realtime_unprotected,
(select coalesce(string_agg(p.proname, ', ' order by p.proname), '')
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef
    and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) cfg
                     where cfg like 'search_path=%')) as definers_unpinned,
(select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
   from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'v'
    and has_table_privilege('anon', c.oid, 'SELECT')
    and coalesce((select option_value from pg_options_to_table(c.reloptions)
                   where option_name = 'security_invoker'), 'false') <> 'true')
  as anon_views,
(select coalesce(string_agg(distinct t.table_name || ' to ' || t.grantee, ', '), '')
   from information_schema.role_table_grants t
  where t.table_schema = 'public'
    and t.table_name in ('payment_credentials', 'einvoice_credentials',
                         'push_config', 'badge_auth_attempts')
    and t.grantee in ('anon', 'authenticated')) as secret_grants,
(select coalesce(string_agg(id, ', ' order by id), '')
   from storage.buckets where public) as public_buckets;
''';


/// #1313 — the live policies against the set the migrations build.
///
/// [expected] comes from CI's replay onto an empty database
/// (`assets/instance/policies.txt`), never from parsing the SQL: 0030
/// creates a policy 0051 drops with its table, and a text parser still
/// expects it. Both directions are alarms — an extra policy is one
/// nobody reviewed (#1316's hand-made storage read was exactly that),
/// and a missing one is protection the migrations meant to install.
List<DoctorFinding> checkPolicyDrift(
  List<Map<String, Object?>> rows,
  Set<String> expected,
) {
  if (expected.isEmpty) {
    return const [
      DoctorFinding(DoctorLevel.warn, 'Policy drift not checked',
          'the expected list is empty — assets/instance/policies.txt was '
              'not read, so drift cannot be judged'),
    ];
  }
  if (rows.isEmpty) {
    return const [
      DoctorFinding(DoctorLevel.alarm, 'Policy drift',
          'the policy query returned no row'),
    ];
  }
  final live = {
    for (final name in '${rows.first['policies'] ?? ''}'.split(','))
      if (name.trim().isNotEmpty) name.trim(),
  };
  final extra = live.difference(expected).toList()..sort();
  final missing = expected.difference(live).toList()..sort();
  return [
    if (extra.isEmpty && missing.isEmpty)
      DoctorFinding(DoctorLevel.ok, 'Policies match the migrations',
          '${live.length} policies, exactly the set the migrations create',
          count: live.length),
    if (extra.isNotEmpty)
      DoctorFinding(
        DoctorLevel.alarm,
        'A policy no migration created',
        '${extra.join(', ')}\n'
            '        Nothing replays it, so no CI run and no other '
            'instance has it. Write the migration, or drop it.',
        count: extra.length,
      ),
    if (missing.isNotEmpty)
      DoctorFinding(
        DoctorLevel.alarm,
        'A policy the migrations create is missing',
        '${missing.join(', ')}\n'
            '        The rows it protects are open to whatever the grants '
            'allow.',
        count: missing.length,
      ),
  ];
}

/// Every permissive read on storage names the folder that owns the file.
///
/// `floor-plans` and `avatars` are laid out one folder per workspace or
/// per user, so a read policy that grants by ROLE alone hands every
/// signed-in person every workspace's files — the live leak #1316 closed.
List<DoctorFinding> checkStorageScoping(
    List<Map<String, Object?>> rows) {
  if (rows.isEmpty) {
    return const [
      DoctorFinding(DoctorLevel.alarm, 'Storage scoping',
          'the storage policy query returned no row'),
    ];
  }
  final policies = [
    for (final entry in '${rows.first['read_policies'] ?? ''}'.split('|'))
      if (entry.trim().isNotEmpty) entry.trim(),
  ];
  if (policies.isEmpty) {
    return const [
      DoctorFinding(DoctorLevel.warn, 'Storage reads',
          'no read policy on storage.objects — either nothing is stored '
              'here yet, or uploads cannot be read back'),
    ];
  }
  final unscoped = [
    for (final policy in policies)
      if (!policy.contains('foldername')) policy.split(' :: ').first,
  ];
  return [
    unscoped.isEmpty
        ? DoctorFinding(DoctorLevel.ok, 'Storage reads are scoped',
            '${policies.length} read policies, each naming the folder that '
                'owns the file',
            count: policies.length)
        : DoctorFinding(
            DoctorLevel.alarm,
            'A storage read is not scoped to its folder',
            '${unscoped.join(', ')}\n'
                '        A read granted by role alone shows every '
                "workspace's files to every signed-in person.",
            count: unscoped.length,
          ),
  ];
}

/// #1313 — the four structural guards of [guardHealthSql].
List<DoctorFinding> checkGuards(List<Map<String, Object?>> rows) {
  if (rows.isEmpty) {
    return const [
      DoctorFinding(DoctorLevel.alarm, 'Hardening',
          'the hardening query returned no row'),
    ];
  }
  final row = rows.first;
  List<String> names(String key) => [
        for (final name in '${row[key] ?? ''}'.split(','))
          if (name.trim().isNotEmpty) name.trim(),
      ];

  DoctorFinding guard(
    String key,
    String okTitle,
    String okDetail,
    String alarmTitle,
    String alarmDetail,
  ) {
    final found = names(key);
    return found.isEmpty
        ? DoctorFinding(DoctorLevel.ok, okTitle, okDetail)
        : DoctorFinding(DoctorLevel.alarm, alarmTitle,
            '${found.join(', ')}\n        $alarmDetail',
            count: found.length);
  }

  return [
    guard(
      'realtime_unprotected',
      'Realtime',
      'every published table has row-level security and a policy',
      'A realtime-published table is unprotected',
      'Realtime replays row changes to subscribers through the same '
          'policies; a table without them publishes to everyone.',
    ),
    guard(
      'definers_unpinned',
      'Definer search_path',
      'every SECURITY DEFINER function pins its search_path',
      'A SECURITY DEFINER function has no fixed search_path',
      'It runs as the owner; an unpinned search_path lets a caller '
          'decide which table its unqualified names mean.',
    ),
    guard(
      'anon_views',
      'Views',
      'no view hands its owner rights to anon',
      'A view readable by anon runs as its owner',
      'Without security_invoker the view reads with the owner rights and '
          'bypasses the policies of the tables under it.',
    ),
    guard(
      'secret_grants',
      'Secret tables',
      'the credential tables grant nothing to anon or authenticated',
      'A table holding secrets grants to an API role',
      'Payment and e-invoice credentials, push configuration and badge '
          'attempts are read by the server, never by a client.',
    ),
    guard(
      'public_buckets',
      'Buckets',
      'no storage bucket is public',
      'A storage bucket is public',
      'A public bucket serves every object to anyone with the URL, '
          'whatever the policies say.',
    ),
  ];
}
