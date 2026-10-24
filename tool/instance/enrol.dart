// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2562 C2a -- the operator enrols a workspace installation at a personal
// home, through the Management API (the service owner), never through a
// client session.
//
//   dart run tool/instance.dart enrol --token … --ref HOME list
//   dart run tool/instance.dart enrol --token … --ref HOME add --workspace-ref W [--not-accepting] [--apply]
//   dart run tool/instance.dart enrol --token … --ref HOME revoke --installation UUID [--apply]
//
// The token must reach both projects: holding the home's Management API is
// what makes the caller its operator. Without --apply nothing is written:
// the plan is printed and the exit is 0. The facts recorded are read from
// the workspace project, never typed. A refusal (not a workspace host, not
// a personal home, the same installation, the database's own checks) is
// exit 1. No token or key is printed.
import 'dart:io';

import 'package:deskilo/core/instance/installation_enrolment.dart';
import 'package:deskilo/core/instance/management_api.dart';

Future<int> runEnrol(
  SupabaseManagement api, {
  required String ref,
  required String action,
  String? workspaceRef,
  String? installation,
  bool accepting = true,
  bool apply = false,
  IOSink? out,
}) async {
  final o = out ?? stdout;
  final enrolment = InstallationEnrolment(api);
  try {
    switch (action) {
      case 'list':
        final rows = await enrolment.list(ref);
        o.writeln('$ref: ${rows.length} enrolled installation(s)');
        for (final r in rows) {
          o.writeln(
            '  ${r.installationId}  ${r.origin}  '
            '${r.enabled ? (r.acceptingNewWorkspaces ? 'accepting new workspaces' : 'not accepting new workspaces') : 'revoked'}',
          );
        }
        return 0;
      case 'add':
        if (workspaceRef == null || workspaceRef.isEmpty) {
          o.writeln(
            'enrol add needs --workspace-ref with the workspace project\'s ref',
          );
          return 2;
        }
        final candidate = await enrolment.inspect(workspaceRef);
        await enrolment.checkHome(ref, candidate);
        final plan =
            'enrol installation ${candidate.installationId} '
            '(${candidate.origin}, ${candidate.roles.join('+')}, '
            '${candidate.capabilities.join(' ')}) at $ref, '
            '${accepting ? 'accepting' : 'not accepting'} new workspaces';
        if (!apply) {
          o.writeln('dry run: would $plan. Nothing was written; add --apply.');
          return 0;
        }
        final r = await enrolment.enrol(ref, candidate, accepting: accepting);
        o.writeln(
          '$plan: ${r.unchanged ? 'already so, nothing changed' : r.status}',
        );
        return 0;
      case 'revoke':
        if (installation == null || !isInstallationId(installation)) {
          o.writeln(
            'enrol revoke needs --installation with the installation id',
          );
          return 2;
        }
        final plan =
            'revoke the enrolment of installation $installation at $ref';
        if (!apply) {
          o.writeln('dry run: would $plan. Nothing was written; add --apply.');
          return 0;
        }
        final r = await enrolment.revoke(ref, installation);
        o.writeln(
          '$plan: ${r.unchanged ? 'already revoked, nothing changed' : r.status}',
        );
        return 0;
      default:
        o.writeln(
          'enrol: list | add --workspace-ref W | revoke --installation UUID',
        );
        return 2;
    }
  } on EnrolmentRefused catch (e) {
    o.writeln('refused: ${e.message}');
    return 1;
  } on ManagementApiException catch (e) {
    if (e.unauthorized) rethrow;
    o.writeln('refused by the database: ${e.message}');
    return 1;
  }
}
