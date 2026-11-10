// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3489 -- the instance doctor's English, in one place: what the operator's
// command line (`tool/instance.dart doctor`) and the support bundle print for
// a typed finding. The panel words the same findings from the ARB catalogue
// (`instanceDoctor*`) in the member's language; the core of the checks holds
// facts and no sentence. Pure Dart: the command line cannot load the
// Flutter localizations.
import 'package:intl/intl.dart';

import '../instance/doctor_finding.dart';
import '../instance/instance_security_checks.dart' show heldInEnglish;

/// The report footer when nothing is wrong.
const String doctorHealthyEnglish = 'Everything checked is healthy.';

/// The report footer when [problems] findings need a person.
String doctorNeedsHumanEnglish(int problems) => Intl.plural(
  problems,
  one: '$problems finding needs a human.',
  other: '$problems findings need a human.',
  locale: 'en',
);

/// The name of a probe, as the operator reads it.
String _probeEnglish(DoctorProbe probe) => switch (probe) {
  DoctorProbe.auth => 'Auth configuration',
  DoctorProbe.signups => 'Sign-ups',
  DoctorProbe.schema => 'Schema',
  DoctorProbe.security => 'Security',
  DoctorProbe.policies => 'Policies',
  DoctorProbe.storage => 'Storage scoping',
  DoctorProbe.hardening => 'Hardening',
  DoctorProbe.roles => 'Installation roles',
};

const String _install =
    '        Fix: dart run tool/instance.dart install --ref <ref>';
const String _pad = '\n        ';

/// The title and detail of a typed [finding].
({String title, String detail}) doctorEnglish(DoctorFinding finding) {
  final f = finding.facts;
  int n(int i) => f[i] as int;
  String s(int i) => '${f[i]}';
  return switch (finding.words!) {
    DoctorWords.probeFailed => (
      title: '${_probeEnglish(f[0] as DoctorProbe)} query failed',
      detail:
          'Supabase answered ${n(1)}: ${s(2)}${_pad}The other checks ran '
          'without it.',
    ),
    DoctorWords.signupsNobodyConfirmed => (
      title: 'Nobody has confirmed in seven days',
      detail:
          '${n(0)} signed up, 0 confirmed. Sign-up is not merely slow — no '
          'one has completed it.${_pad}Check the Site URL above first: that '
          'is what the mail links to.',
    ),
    DoctorWords.schemaNoVersion => (
      title: 'Schema has no version',
      detail:
          '${n(0)} tables exist, but no schema version: this instance '
          'predates migration 0226, so it is behind an app that needs '
          '${n(1)}. The install upgrades it from what it recorded.\n'
          '$_install\n'
          '        If it cannot tell where to resume, first: '
          'dart run tool/instance.dart record --ref <ref> --through <NNNN>',
    ),
    DoctorWords.policyDriftSkipped => (
      title: 'Policy drift not checked',
      detail:
          'the expected list is empty — assets/instance/policies.txt was '
          'not read, so drift cannot be judged',
    ),
    DoctorWords.policiesMatch => (
      title: 'Policies match the migrations',
      detail:
          '${n(0)} policies, exactly the set the migrations create',
    ),
    DoctorWords.storageScoped => (
      title: 'Storage reads are scoped',
      detail:
          '${n(0)} read policies, each naming the folder that owns the file',
    ),
    DoctorWords.guardRealtime => (
      title: 'A realtime-published table is unprotected',
      detail:
          '${s(0)}${_pad}Realtime replays row changes to subscribers through '
          'the same policies; a table without them publishes to everyone.',
    ),
    DoctorWords.guardDefiner => (
      title: 'A SECURITY DEFINER function has no fixed search_path',
      detail:
          '${s(0)}${_pad}It runs as the owner; an unpinned search_path lets a '
          'caller decide which table its unqualified names mean.',
    ),
    DoctorWords.guardAnonView => (
      title: 'A view readable by anon runs as its owner',
      detail:
          '${s(0)}${_pad}Without security_invoker the view reads with the '
          'owner rights and bypasses the policies of the tables under it.',
    ),
    DoctorWords.guardSecretGrants => (
      title: 'A table holding secrets grants to an API role',
      detail:
          '${s(0)}${_pad}Payment and e-invoice credentials, push configuration '
          'and badge attempts are read by the server, never by a client.',
    ),
    DoctorWords.guardPublicBucket => (
      title: 'A storage bucket is public',
      detail:
          '${s(0)}${_pad}A public bucket serves every object to anyone with '
          'the URL, whatever the policies say.',
    ),
    DoctorWords.rolesUndeclared => (
      title: 'Installation roles not declared',
      detail:
          'the schema predates the roles column; the installation behaves as '
          'combined (personal home and workspace host) — '
          '${heldInEnglish(n(0), n(1))}.\n$_install',
    ),
    DoctorWords.rolesUnknown => (
      title: 'Installation roles are not a known set',
      detail:
          '${s(0)}${_pad}Only personal_home and workspace_host exist; '
          'operator_set_installation_roles writes a valid set.',
    ),
    DoctorWords.stuckAccounts || DoctorWords.installationHeld => (
      title: '',
      detail: '',
    ),
  };
}
