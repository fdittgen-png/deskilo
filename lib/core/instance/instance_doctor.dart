// SPDX-License-Identifier: 0BSD
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
import 'management_api.dart';

/// How serious a finding is. [alarm] means people are affected right now.
enum DoctorLevel { ok, warn, alarm }

/// One thing the doctor looked at.
class DoctorFinding {
  const DoctorFinding(this.level, this.title, this.detail);

  final DoctorLevel level;
  final String title;

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

  Future<List<DoctorFinding>> examine(String ref) async {
    final config = await api.authConfig(ref);
    final rows = await api.query(ref, signupHealthSql);
    final install = await api.query(ref, installHealthSql);
    return [
      ...checkAuthConfig(config),
      ...checkSignups(rows),
      ...checkInstall(install),
    ];
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

  /// #1245 — one round trip for the INSTALL, the way [signupHealthSql]
  /// is one round trip for sign-in.
  ///
  /// Every one of these is something the repository's own lints or the
  /// pgTAP suite check on a database CI built (#1226). An operator
  /// running DesKilo on their own Supabase has neither, so the same
  /// questions are asked of the live project instead:
  ///
  ///   * did the schema install at all, and how much of it;
  ///   * is row-level security on everywhere;
  ///   * is any table without a policy still handing `anon` a grant —
  ///     the finding that made 0211 necessary, and the one that would
  ///     turn a single `create policy` into a leak of the four tables
  ///     that hold secrets;
  ///   * is any `SECURITY DEFINER` function callable by `anon` — the
  ///     hole 0191 swept, which existed for months;
  ///   * do the storage buckets the policies are written against exist.
  static const String installHealthSql = '''
select
  (select count(*)::int from supabase_migrations.schema_migrations)
    as migrations_applied,
  (select count(*)::int from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r') as tables,
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

  /// #1245 — is the install itself sound?
  ///
  /// [minimumMigrations] is how much schema a working instance has.
  /// It is a floor rather than an equality on purpose: a project may
  /// legitimately carry more (a hand-applied fix, a newer bundle than
  /// the binary running this), and refusing to start over a number
  /// being larger would be the doctor causing the outage.
  static List<DoctorFinding> checkInstall(
    List<Map<String, Object?>> rows, {
    int minimumMigrations = 200,
  }) {
    if (rows.isEmpty) {
      return const [
        DoctorFinding(DoctorLevel.alarm, 'Schema',
            'the install query returned nothing — the project is not '
                'reachable, or `supabase_migrations` does not exist, which '
                'means no migration has ever run here'),
      ];
    }
    final row = rows.first;
    String text(String key) => '${row[key] ?? ''}';
    int number(String key) => int.tryParse(text(key)) ?? 0;

    final findings = <DoctorFinding>[];
    final applied = number('migrations_applied');
    final tables = number('tables');

    if (applied == 0) {
      findings.add(const DoctorFinding(DoctorLevel.alarm, 'Schema',
          'no migration has been applied. Nothing works yet.\n'
              '        Fix: dart run tool/instance.dart install --ref <ref>'));
    } else if (applied < minimumMigrations) {
      findings.add(DoctorFinding(
        DoctorLevel.alarm,
        'Schema is behind',
        '$applied migrations applied, $tables tables. A working instance '
            'has at least $minimumMigrations.\n'
            '        A half-installed schema fails at the first feature '
            'whose table is missing, and says nothing until then.\n'
            '        Fix: dart run tool/instance.dart install --ref <ref>',
      ));
    } else {
      findings.add(DoctorFinding(DoctorLevel.ok, 'Schema',
          '$applied migrations applied, $tables tables'));
    }

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

/// The findings as a report — the same text on a terminal and in an issue.
String doctorReport(String ref, List<DoctorFinding> findings) {
  final buffer = StringBuffer('instance doctor — $ref\n\n');
  for (final finding in findings) {
    buffer.writeln(finding);
  }
  final problems = findings.where((f) => f.isProblem).length;
  buffer.writeln();
  buffer.writeln(problems == 0
      ? 'Everything checked is healthy.'
      : '$problems finding${problems == 1 ? '' : 's'} need a human.');
  return buffer.toString();
}
