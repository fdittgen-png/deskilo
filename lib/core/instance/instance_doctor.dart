// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1075 — the check that would have caught it on the 7th.
//
// On 2026-09-06 `mailer_autoconfirm` was switched off on the live
// project. Every account for the previous two months had been confirmed
// within two seconds of creation — autoconfirm on, no mail ever sent,
// nobody ever asked to click. From the 7th, GoTrue started sending
// "Confirm your signup" for real, and the link in it pointed at the
// project's Site URL, which was still `http://localhost:3000`.
//
// Three people signed up over the next three days. None could confirm.
// Nothing anywhere said so: the app was green, CI was green, the store
// build was fine. It surfaced on the fourth day because one of them
// asked a human on WhatsApp whether the mail was real.
//
// Every signal needed was already in the project — the auth config and
// four rows of `auth.users`. This is the thing that reads them.

import 'instance_builder.dart';
import 'schema_compatibility.dart';
import 'instance_security_checks.dart';
import 'management_api.dart';

/// How serious a finding is. [alarm] means people are affected right now.
enum DoctorLevel { ok, warn, alarm }

/// One thing the doctor looked at.
class DoctorFinding {
  const DoctorFinding(this.level, this.title, this.detail, {this.count});

  final DoctorLevel level;
  final String title;

  /// #1313 — how many objects the finding is about, when it is about a
  /// list of them. The scheduled run publishes this number and not the
  /// names: its log is public.
  final int? count;

  /// What was found and, when something is wrong, what to do about it.
  final String detail;

  bool get isProblem => level != DoctorLevel.ok;

  @override
  String toString() => '${switch (level) {
        DoctorLevel.ok => 'ok   ',
        DoctorLevel.warn => 'warn ',
        DoctorLevel.alarm => 'ALARM',
      }}  $title\n        $detail';
}

/// Reads a live project and says whether people can actually sign in.
class InstanceDoctor {
  const InstanceDoctor(this.api);

  final SupabaseManagement api;

  /// Accounts unconfirmed for longer than this are stuck, not in flight.
  static const Duration stuckAfter = Duration(hours: 24);

  /// Storage buckets the schema's policies are written against. A
  /// missing one is not a slow avatar: the upload fails and the member
  /// is told nothing useful (0036, 0043).
  static const Set<String> expectedBuckets = {'avatars', 'floor-plans'};

  /// Every question on its own, so one that fails never silences the
  /// others (#1314).
  ///
  /// The install used to be asked in ONE statement with the security
  /// checks, and that statement read `supabase_migrations` — which a
  /// wizard-built instance did not have. The query raised, `examine`
  /// returned nothing, and a real RLS or definer problem on that instance
  /// sat behind a bookkeeping error.
  Future<List<DoctorFinding>> examine(
    String ref, {
    List<String> bundleMigrations = const [],
    int required = requiredSchemaVersion,
    Set<String> expectedPolicies = const {},
  }) async =>
      [
        ...await _probe('Auth configuration',
            () async => checkAuthConfig(await api.authConfig(ref))),
        ...await _probe('Sign-ups',
            () async => checkSignups(await api.query(ref, signupHealthSql))),
        ...await _probe(
            'Schema',
            () async => checkSchema(await api.query(ref, schemaHealthSql),
                required: required, bundleMigrations: bundleMigrations)),
        ...await _probe('Security',
            () async => checkSecurity(await api.query(ref, securityHealthSql))),
        // #1313 — structural, read-only, and the only check that can see a
        // policy no migration created: a replay cannot contain one.
        ...await _probe(
            'Policies',
            () async => checkPolicyDrift(
                await api.query(ref, policyDriftSql), expectedPolicies)),
        ...await _probe(
            'Storage scoping',
            () async =>
                checkStorageScoping(await api.query(ref, storageReadPolicySql))),
        ...await _probe('Hardening',
            () async => checkGuards(await api.query(ref, guardHealthSql))),
      ];

  Future<List<DoctorFinding>> _probe(
    String what,
    Future<List<DoctorFinding>> Function() ask,
  ) async {
    try {
      return await ask();
    } on ManagementApiException catch (e, st) {
      // A token that cannot read the project fails every probe the same
      // way: say that once, as the CLI does, not four times.
      // trace-exempt: an unauthorized answer is rethrown with its stack; any other becomes a finding the report prints.
      if (e.unauthorized) Error.throwWithStackTrace(e, st);
      return [
        DoctorFinding(
          DoctorLevel.alarm,
          '$what query failed',
          'Supabase answered ${e.status}: ${e.message}\n'
              '        The other checks ran without it.',
        ),
      ];
    }
  }

  /// One round trip for the whole picture: how many accounts exist, how
  /// many are stuck, how old the oldest stuck one is, and — the invariant
  /// that broke — how many people have actually confirmed lately.
  static const String signupHealthSql = '''
select
  count(*) filter (
    where created_at > now() - interval '7 days'
  ) as created_7d,
  count(*) filter (
    where email_confirmed_at > now() - interval '7 days'
  ) as confirmed_7d,
  count(*) filter (
    where email_confirmed_at is null
      and created_at < now() - interval '24 hours'
  ) as stuck,
  coalesce(
    extract(epoch from now() - min(created_at) filter (
      where email_confirmed_at is null
        and created_at < now() - interval '24 hours'
    )) / 3600, 0
  )::int as oldest_stuck_hours
from auth.users;
''';

  /// #1245 — how much schema is installed. #1314 split it from the
  /// security questions and made it safe to ask of any project:
  /// `supabase_migrations` is only read once `to_regclass` has found it,
  /// and `-1` says it does not exist. #1312 — `marker` is the schema's own
  /// version, null before 0226.
  static const String schemaHealthSql = 'select\n  '
      '${InstanceBuilder.markerColumnSql} as marker,' r'''

  case when to_regclass('supabase_migrations.schema_migrations') is null then -1
    else (xpath('/row/c/text()', query_to_xml(
      'select count(*) as c from supabase_migrations.schema_migrations',
      false, true, '')))[1]::text::int
  end as migrations_applied,
  (select count(*)::int from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r') as tables;
''';

  /// #1245 — the install's security, asked on its own (#1314).
  ///
  /// Every one of these is something the repository's own lints or the
  /// pgTAP suite check on a database CI built (#1226). An operator
  /// running DesKilo on their own Supabase has neither, so the same
  /// questions are asked of the live project instead:
  ///
  ///   * is row-level security on everywhere;
  ///   * is any table without a policy still handing `anon` a grant —
  ///     the finding that made 0211 necessary, and the one that would
  ///     turn a single `create policy` into a leak of the four tables
  ///     that hold secrets;
  ///   * is any `SECURITY DEFINER` function callable by `anon` — the
  ///     hole 0191 swept, which existed for months;
  ///   * do the storage buckets the policies are written against exist.
  static const String securityHealthSql = '''
select
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
      and not c.relrowsecurity) as tables_without_rls,
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
      and not exists (select 1 from pg_policy p where p.polrelid = c.oid)
      and (has_table_privilege('anon', c.oid, 'SELECT, INSERT, UPDATE, DELETE')
        or has_table_privilege('authenticated', c.oid,
                               'SELECT, INSERT, UPDATE, DELETE')))
    as open_policyless,
  (select coalesce(string_agg(p.proname, ', ' order by p.proname), '')
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef
      and has_function_privilege('anon', p.oid, 'EXECUTE')) as anon_definers,
  (select coalesce(string_agg(name, ', ' order by name), '')
     from storage.buckets) as buckets;
''';

  /// Does the project agree with [InstanceAuthConfig]?
  ///
  /// A redirect the allow-list does not carry is refused, and Supabase
  /// then quietly substitutes the Site URL — so a wrong Site URL is not
  /// cosmetic even once the client asks for the right thing.
  static List<DoctorFinding> checkAuthConfig(Map<String, Object?> config) {
    final findings = <DoctorFinding>[];
    final siteUrl = '${config['site_url'] ?? ''}';
    final allowList = '${config['uri_allow_list'] ?? ''}';
    final autoconfirm = config['mailer_autoconfirm'] == true;

    if (siteUrl != InstanceAuthConfig.siteUrl) {
      findings.add(DoctorFinding(
        siteUrl.contains('localhost') ? DoctorLevel.alarm : DoctorLevel.warn,
        'Site URL is not the app',
        'is  "$siteUrl"\n        want "${InstanceAuthConfig.siteUrl}"\n'
            '        Every mail GoTrue sends carries this link. A localhost '
            'here is a link nobody can open.\n'
            '        Fix: dart run tool/instance.dart auth --ref <ref>',
      ));
    } else {
      findings.add(const DoctorFinding(
          DoctorLevel.ok, 'Site URL', 'matches InstanceAuthConfig'));
    }

    final missing = [
      for (final entry in InstanceAuthConfig.redirectAllowList.split(','))
        if (!allowList.contains(entry.trim())) entry.trim(),
    ];
    findings.add(missing.isEmpty
        ? const DoctorFinding(
            DoctorLevel.ok, 'Redirect allow-list', 'carries every callback')
        : DoctorFinding(
            DoctorLevel.alarm,
            'Redirect allow-list is missing a callback',
            'missing: ${missing.join(', ')}\n'
                '        A redirect that is not listed is refused, and the '
                'Site URL is substituted instead.\n'
                '        Fix: dart run tool/instance.dart auth --ref <ref>',
          ));

    // Not a fault either way — but it decides whether anybody has to click
    // anything, so it must be visible when it changes.
    findings.add(DoctorFinding(
      DoctorLevel.ok,
      'Confirmation e-mail',
      autoconfirm
          ? 'mailer_autoconfirm is ON — accounts confirm themselves and no '
              'mail is sent'
          : 'mailer_autoconfirm is OFF — every new account must click a '
              'link, so the Site URL above has to be right',
    ));
    return findings;
  }

  /// Can people actually complete a sign-up?
  static List<DoctorFinding> checkSignups(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) {
      return const [
        DoctorFinding(DoctorLevel.warn, 'Sign-ups', 'no rows came back'),
      ];
    }
    int at(String key) => int.tryParse('${rows.first[key] ?? 0}') ?? 0;
    final created = at('created_7d');
    final confirmed = at('confirmed_7d');
    final stuck = at('stuck');
    final oldestHours = at('oldest_stuck_hours');

    final findings = <DoctorFinding>[];

    // The invariant that broke: people kept arriving, nobody got in.
    if (created > 0 && confirmed == 0) {
      findings.add(DoctorFinding(
        DoctorLevel.alarm,
        'Nobody has confirmed in seven days',
        '$created signed up, 0 confirmed. Sign-up is not merely slow — no '
            'one has completed it.\n'
            '        Check the Site URL above first: that is what the mail '
            'links to.',
      ));
    } else {
      findings.add(DoctorFinding(DoctorLevel.ok, 'Sign-ups (7 days)',
          '$created created, $confirmed confirmed'));
    }

    if (stuck > 0) {
      findings.add(DoctorFinding(
        stuck > 2 ? DoctorLevel.alarm : DoctorLevel.warn,
        '$stuck account${stuck == 1 ? '' : 's'} cannot get in',
        'unconfirmed for more than 24 h; the oldest for $oldestHours h.\n'
            '        These are people who tried. They will not try again '
            'unprompted.',
      ));
    } else {
      findings.add(const DoctorFinding(
          DoctorLevel.ok, 'Stuck accounts', 'none older than 24 h'));
    }
    return findings;
  }

  /// #1245 — is the install itself sound? Both halves, from one row that
  /// carries every key — what the two queries return, side by side.
  static List<DoctorFinding> checkInstall(
    List<Map<String, Object?>> rows, {
    int required = requiredSchemaVersion,
    List<String> bundleMigrations = const [],
  }) =>
      [
        ...checkSchema(rows,
            required: required, bundleMigrations: bundleMigrations),
        ...checkSecurity(rows),
      ];

  /// #1312 — which version of the schema is installed, in migration
  /// numbers: the marker every migration from 0226 writes, compared with
  /// [required] — the last migration of the bundle this tool carries.
  ///
  /// Row counts in `supabase_migrations` decide nothing any more: a hosted
  /// project records timestamps and names there that map to no file, and
  /// an older installer recorded nothing at all. [bundleMigrations] (file
  /// names) only lets a "behind" finding name what is missing.
  static List<DoctorFinding> checkSchema(
    List<Map<String, Object?>> rows, {
    int required = requiredSchemaVersion,
    List<String> bundleMigrations = const [],
  }) {
    if (rows.isEmpty) {
      return const [
        DoctorFinding(DoctorLevel.alarm, 'Schema',
            'the schema query returned no row — the project did not answer it'),
      ];
    }
    final row = rows.first;
    int number(String key) => int.tryParse('${row[key] ?? ''}') ?? 0;
    final marker = int.tryParse('${row['marker'] ?? ''}');
    final tables = number('tables');
    const install = '        Fix: dart run tool/instance.dart install --ref <ref>';

    if (marker == null && tables == 0) {
      return const [
        DoctorFinding(DoctorLevel.alarm, 'Schema',
            'no migration has been applied. Nothing works yet.\n$install'),
      ];
    }
    if (marker == null) {
      return [
        DoctorFinding(
          DoctorLevel.alarm,
          'Schema has no version',
          '$tables tables exist, but no schema version: this instance '
              'predates migration 0226, so it is behind an app that needs '
              '$required. The install upgrades it from what it recorded.\n'
              '$install\n'
              '        If it cannot tell where to resume, first: '
              'dart run tool/instance.dart record --ref <ref> --through <NNNN>',
        ),
      ];
    }
    if (marker < required) {
      final missing = [
        for (final name in bundleMigrations)
          if ((int.tryParse(name.split('_').first) ?? 0) > marker) name,
      ];
      final behindBy = missing.isEmpty ? required - marker : missing.length;
      return [
        DoctorFinding(
          DoctorLevel.alarm,
          'Schema is behind',
          'version $marker, and this app needs $required — behind by '
              '$behindBy${missing.isEmpty ? '' : ': ${missing.join(', ')}'}.\n'
              '        A newer app on an older schema stops at "This server '
              'needs an update".\n$install',
          count: behindBy,
        ),
      ];
    }
    return [
      DoctorFinding(
        DoctorLevel.ok,
        'Schema',
        marker == required
            ? 'version $marker, current — $tables tables'
            : 'version $marker, ahead of this tool ($required) — supported; '
                'update the tooling before installing from it',
      ),
    ];
  }

  /// Is the installed schema closed to the people it must be closed to?
  static List<DoctorFinding> checkSecurity(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) {
      return const [
        DoctorFinding(DoctorLevel.alarm, 'Security',
            'the security query returned no row — nothing about RLS, grants '
                'or definer functions is known'),
      ];
    }
    final row = rows.first;
    String text(String key) => '${row[key] ?? ''}';

    final findings = <DoctorFinding>[];
    final noRls = text('tables_without_rls');
    findings.add(noRls.isEmpty
        ? const DoctorFinding(
            DoctorLevel.ok, 'Row-level security', 'on for every table')
        : DoctorFinding(
            DoctorLevel.alarm,
            'Row-level security is OFF on some tables',
            '$noRls\n'
                '        Every signed-in user of every other workspace can '
                'read these.',
          ));

    // The finding that made 0211 necessary: four tables holding secrets
    // were safe only because nobody had added a policy to them yet.
    final open = text('open_policyless');
    findings.add(open.isEmpty
        ? const DoctorFinding(DoctorLevel.ok, 'Closed tables',
            'a table with no policy grants nothing either')
        : DoctorFinding(
            DoctorLevel.warn,
            'A table with no policy still grants to anon or authenticated',
            '$open\n'
                '        RLS with no policy denies everything, so nothing '
                'leaks today — but one `create policy` on any of these '
                'opens it, and the grant says it is allowed.',
          ));

    // The hole 0191 swept, which existed for months.
    final definers = text('anon_definers');
    findings.add(definers.isEmpty
        ? const DoctorFinding(DoctorLevel.ok, 'Definer functions',
            'none is executable by anon')
        : DoctorFinding(
            DoctorLevel.alarm,
            'A SECURITY DEFINER function is callable without signing in',
            '$definers\n'
                '        A definer function runs as the owner and bypasses '
                'RLS by design; the EXECUTE grant is the only thing between '
                '`anon` and the whole database.',
          ));

    final present = text('buckets')
        .split(',')
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toSet();
    final missing = expectedBuckets.difference(present);
    findings.add(missing.isEmpty
        ? DoctorFinding(DoctorLevel.ok, 'Storage buckets',
            '${expectedBuckets.join(', ')} present')
        : DoctorFinding(
            DoctorLevel.alarm,
            'A storage bucket the policies are written against is missing',
            'missing: ${missing.join(', ')}\n'
                '        The upload fails and the member is told nothing '
                'useful.',
          ));

    return findings;
  }
}

/// True when anything the doctor found needs a human.
bool hasProblem(List<DoctorFinding> findings) =>
    findings.any((f) => f.isProblem);

/// #1308 — an alarm blocks; a warning is shown and does not.
bool hasAlarm(List<DoctorFinding> findings) =>
    findings.any((f) => f.level == DoctorLevel.alarm);

/// The findings as a report — the same text on a terminal and in an issue.
///
/// #1313 — [redacted] is for a run whose log is PUBLIC: the scheduled
/// workflow lives in a public repository, so it publishes each finding's
/// level, title and count, never an object name, a policy definition or a
/// row. The names are for `tool/instance.dart doctor` run by an operator.
String doctorReport(
  String ref,
  List<DoctorFinding> findings, {
  bool redacted = false,
}) {
  final buffer = StringBuffer('instance doctor — $ref\n\n');
  for (final finding in findings) {
    buffer.writeln(redacted
        ? '${switch (finding.level) {
            DoctorLevel.ok => 'ok   ',
            DoctorLevel.warn => 'warn ',
            DoctorLevel.alarm => 'ALARM',
          }}  ${finding.title}'
            '${finding.count == null ? '' : ' (${finding.count})'}'
        : '$finding');
  }
  final problems = findings.where((f) => f.isProblem).length;
  buffer.writeln();
  buffer.writeln(problems == 0
      ? 'Everything checked is healthy.'
      : '$problems finding${problems == 1 ? '' : 's'} need a human.');
  return buffer.toString();
}
