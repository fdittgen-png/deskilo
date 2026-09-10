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

  Future<List<DoctorFinding>> examine(String ref) async {
    final config = await api.authConfig(ref);
    final rows = await api.query(ref, signupHealthSql);
    return [...checkAuthConfig(config), ...checkSignups(rows)];
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
