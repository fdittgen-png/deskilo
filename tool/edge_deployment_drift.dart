// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3520 -- do the edge functions deployed on the dev project match
// `supabase/functions`? Read-only: one GET of the project's function list.
//
//   SUPABASE_ACCESS_TOKEN=... dart run tool/edge_deployment_drift.dart \
//       --ref <dev project> --expected-ref <dev project, from the repository
//       variable> [--summary $GITHUB_STEP_SUMMARY]
//
// THREE RESULTS, never two:
//   verified      every repository function is deployed, nothing else is, and
//                 each one's `verify_jwt` is what the repository says  (exit 0)
//   drift         a function missing, an orphan, or a flipped `verify_jwt`
//                 (exit 1)
//   not verified  the check could not look: no token, no ref, the ref is not the
//                 expected one, the API refused (401/403), timed out or answered
//                 something unreadable, or a deployed entry does not say its
//                 `verify_jwt`  (exit 3). A missing credential is NEVER a pass.
//
// The repository side is `functionVerifyJwt` (tool/build_instance.dart), which
// test/lint/function_verify_jwt_test.dart holds equal to supabase/config.toml
// and to the folders: no second TOML parse here, and no remote setting is
// assumed from a local default. The identity check (--ref equals
// --expected-ref) is what keeps a pasted production ref from being examined.
import 'dart:io';

import 'package:deskilo/core/instance/management_api.dart';

import 'build_instance.dart' show functionVerifyJwt;

enum DriftStatus { verified, drift, notVerified }

class DriftReport {
  const DriftReport(this.status, this.rows, this.problems);
  final DriftStatus status;

  /// `slug | repository | deployed | verdict` per function, sorted by slug.
  final List<String> rows;

  /// What is wrong, one sentence each.
  final List<String> problems;
}

String _jwt(bool? v) => v == null ? 'unknown' : (v ? 'true' : 'false');

/// The pure comparison. [deployed] is null when the list could not be read.
DriftReport compare(
  List<({String slug, bool? verifyJwt})>? deployed,
  Map<String, bool> local,
) {
  if (deployed == null) {
    return const DriftReport(DriftStatus.notVerified, [], [
      'the deployed functions could not be read',
    ]);
  }
  final remote = <String, bool?>{for (final d in deployed) d.slug: d.verifyJwt};
  final drift = <String>[];
  final unknown = <String>[];
  final rows = <String>[];
  for (final slug in {...local.keys, ...remote.keys}.toList()..sort()) {
    final inRepo = local.containsKey(slug);
    final onDev = remote.containsKey(slug);
    String verdict;
    if (!onDev) {
      verdict = 'MISSING on dev';
      drift.add('$slug is in supabase/functions but not deployed');
    } else if (!inRepo) {
      verdict = 'ORPHAN on dev';
      drift.add('$slug is deployed but has no folder in supabase/functions');
    } else if (remote[slug] == null) {
      verdict = 'not verified';
      unknown.add('$slug: the API did not say its verify_jwt');
    } else if (remote[slug] != local[slug]) {
      verdict = 'DIFFERS';
      drift.add(
        '$slug: verify_jwt is ${_jwt(local[slug])} in the repository and '
        '${_jwt(remote[slug])} on dev',
      );
    } else {
      verdict = 'ok';
    }
    rows.add(
      '$slug | ${inRepo ? _jwt(local[slug]) : '-'} | '
      '${onDev ? _jwt(remote[slug]) : '-'} | $verdict',
    );
  }
  if (drift.isNotEmpty) {
    return DriftReport(DriftStatus.drift, rows, [...drift, ...unknown]);
  }
  if (unknown.isNotEmpty) {
    return DriftReport(DriftStatus.notVerified, rows, unknown);
  }
  return DriftReport(DriftStatus.verified, rows, const []);
}

int _exitFor(DriftStatus s) => switch (s) {
  DriftStatus.verified => 0,
  DriftStatus.drift => 1,
  DriftStatus.notVerified => 3,
};

String _markdown(DriftReport r, String headline) {
  final b = StringBuffer('## Edge function drift (dev) -- $headline\n\n');
  for (final p in r.problems) {
    b.writeln('- $p');
  }
  if (r.problems.isNotEmpty) b.writeln();
  if (r.rows.isNotEmpty) {
    b
      ..writeln('| function | repository verify_jwt | dev verify_jwt | result |')
      ..writeln('|---|---|---|---|');
    for (final row in r.rows) {
      b.writeln('| $row |');
    }
  }
  return b.toString();
}

void main(List<String> args) async {
  exitCode = await run(args, Platform.environment, DioSupabaseManagement.new);
}

/// [makeApi] builds the Management API client from the access token; a test
/// passes a fake. [out] receives the log lines (default: stdout).
Future<int> run(
  List<String> args,
  Map<String, String> env,
  SupabaseManagement Function(String token) makeApi, {
  Map<String, bool>? local,
  StringSink? out,
}) async {
  final o = out ?? stdout;
  String? option(String name) {
    final i = args.indexOf('--$name');
    return i < 0 || i + 1 >= args.length ? null : args[i + 1].trim();
  }

  final summary = option('summary');
  int finish(DriftReport r, String headline) {
    o.writeln('Edge function drift (dev): $headline');
    for (final p in r.problems) {
      o.writeln('  - $p');
    }
    r.rows.forEach(o.writeln);
    if (summary != null && summary.isNotEmpty) {
      File(summary).writeAsStringSync(_markdown(r, headline), mode: FileMode.append);
    }
    return _exitFor(r.status);
  }

  int notVerified(String why) => finish(
    DriftReport(DriftStatus.notVerified, const [], [why]),
    'NOT VERIFIED (this is not a pass)',
  );

  final token = env['SUPABASE_ACCESS_TOKEN'] ?? '';
  final ref = (option('ref') ?? '').trim();
  final expected = (option('expected-ref') ?? '').trim();
  if (token.isEmpty) {
    return notVerified(
      'SUPABASE_ACCESS_TOKEN is not set: nothing was compared. Set the '
      'repository secret (a read-capable token) to run this check',
    );
  }
  if (ref.isEmpty) {
    return notVerified(
      'no project ref: pass the ref input or set the SUPABASE_DEV_PROJECT_REF '
      'secret. Nothing was compared',
    );
  }
  if (expected.isEmpty) {
    return notVerified(
      'the repository variable that names the dev project (the identity check) '
      'is not set: nothing was compared',
    );
  }
  if (ref != expected) {
    return notVerified(
      'the ref is not the dev project the repository variable names: nothing '
      'was read. A ref pasted by hand is never examined',
    );
  }
  final List<({String slug, bool? verifyJwt})> deployed;
  try {
    deployed = await makeApi(token).listDeployedFunctions(ref);
  } on ManagementApiException catch (e) {
    // the status only: a response body is never copied into a public log
    return notVerified(
      e.unauthorized
          ? 'the token was refused (HTTP ${e.status}): nothing was compared'
          : 'the Management API did not answer usefully (HTTP ${e.status}): '
                'nothing was compared',
    );
  } on Object catch (_) {
    return notVerified(
      'the Management API could not be read (timeout, network or an '
      'unreadable answer): nothing was compared',
    );
  }
  final report = compare(deployed, local ?? functionVerifyJwt);
  final headline = switch (report.status) {
    DriftStatus.verified => 'verified: ${report.rows.length} functions match',
    DriftStatus.drift => 'DRIFT',
    DriftStatus.notVerified => 'NOT VERIFIED (this is not a pass)',
  };
  return finish(report, headline);
}
