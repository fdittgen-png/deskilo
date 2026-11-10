// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The instance doctor's findings as data (#1075, #3489): what one check saw,
// how serious it is, and -- for a typed finding -- the words it is worded
// from. Split from instance_doctor.dart so the checks stay under their budget.
import '../diagnostics/doctor_english.dart';

/// #3489 -- findings the panel words from the ARB catalogue.
enum DoctorWords {
  stuckAccounts,
  installationHeld,
  probeFailed,
  signupsNobodyConfirmed,
  schemaNoVersion,
  policyDriftSkipped,
  policiesMatch,
  storageScoped,
  guardRealtime,
  guardDefiner,
  guardAnonView,
  guardSecretGrants,
  guardPublicBucket,
  rolesUndeclared,
  rolesUnknown,
}

/// The questions the doctor asks, each named once: a failed one is worded in
/// the reader's language, so its name is data, not a sentence.
enum DoctorProbe {
  auth,
  signups,
  schema,
  security,
  policies,
  storage,
  hardening,
  roles,
}

/// How serious a finding is. [alarm] means people are affected right now.
enum DoctorLevel { ok, warn, alarm }

/// One thing the doctor looked at.
class DoctorFinding {
  const DoctorFinding(
    this.level,
    String title,
    String detail, {
    this.count,
    this.words,
    this.facts = const [],
  }) : _title = title,
       _detail = detail;

  /// #3489 -- a finding that is only data: its sentence is the catalogue's
  /// (`instanceDoctor*` in the ARB for the panel, [doctorEnglish] for the
  /// operator's command line).
  const DoctorFinding.typed(
    this.level,
    DoctorWords this.words, {
    this.count,
    this.facts = const [],
  }) : _title = null,
       _detail = null;

  final String? _title;
  final String? _detail;

  /// #3489 -- the words of a finding whose title carries a count, as data:
  /// the panel words it in the member's language (ICU plural, [count]);
  /// [title] stays the English the operator's command line prints. Null for a
  /// finding still worded by [title] and [detail] alone.
  final DoctorWords? words;

  /// The numbers [words] is worded from (workspaces and members for
  /// [DoctorWords.installationHeld]).
  final List<Object> facts;

  final DoctorLevel level;

  /// What was found, in the operator's English.
  String get title => _title ?? doctorEnglish(this).title;

  /// #1313 — how many objects the finding is about, when it is about a
  /// list of them. The scheduled run publishes this number and not the
  /// names: its log is public.
  final int? count;

  /// What was found and, when something is wrong, what to do about it.
  String get detail => _detail ?? doctorEnglish(this).detail;

  bool get isProblem => level != DoctorLevel.ok;

  @override
  String toString() => '${switch (level) {
        DoctorLevel.ok => 'ok   ',
        DoctorLevel.warn => 'warn ',
        DoctorLevel.alarm => 'ALARM',
      }}  $title\n        $detail';
}
