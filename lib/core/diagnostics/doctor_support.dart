// SPDX-License-Identifier: AGPL-3.0-or-later
import '../instance/instance_doctor.dart';
import 'support_bundle.dart';
import 'support_evidence.dart';

/// Exact known finding names select fixed codes. Details, counts, arbitrary
/// names and provider errors never become part of the support document.
SupportBundle doctorSupportBundle(
  List<DoctorFinding> findings,
  DateTime now, {
  SupportEvidence? evidence,
}) {
  const known = {
    'Site URL': SupportCheck.siteUrl,
    'Site URL is not the app': SupportCheck.siteUrl,
    'Redirect allow-list': SupportCheck.redirects,
    'Redirect allow-list is missing a callback': SupportCheck.redirects,
    'Confirmation e-mail': SupportCheck.emailConfirmation,
    'Schema': SupportCheck.schema,
    'Schema is behind': SupportCheck.schema,
    'Schema has no version': SupportCheck.schema,
  };
  final checks = <SupportCheck, SupportStatus>{};
  for (final finding in findings) {
    final check = known[finding.title];
    if (check == null) continue;
    final status = finding.level == DoctorLevel.ok
        ? SupportStatus.ok
        : SupportStatus.attention;
    if (checks[check] != SupportStatus.attention) checks[check] = status;
  }
  return SupportBundle(
    evidence: evidence,
    from: now,
    until: now,
    mode: SupportMode.operator,
    platform: SupportPlatform.unknown,
    checks: checks,
  );
}
