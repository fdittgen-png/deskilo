// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The release train's installation gate (tool/release_gate/gate.dart): reads
// the installation a track ships to and says whether the candidate checked out
// at --root may be published to it. It reads two public version functions as
// anon and changes nothing.
//
//   dart tool/release_gate.dart --track alpha [--root .] \
//     [--installations contracts/release/installations.json] \
//     [--timeout-seconds 20] [--summary <file>]
//
// Exit 0: ready, publish. Exit 1: the installation is behind or refuses this
// app (the missing migrations are named). Exit 2: not verified. Exit 64: a
// usage error. Anything but 0 stops every upload.
import 'dart:io';

import 'release_gate/gate.dart';

Future<void> main(List<String> args) async {
  String? option(String name) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final track = option('track');
  final root = Directory(option('root') ?? '.');
  final mapPath =
      option('installations') ??
      '${root.path}/contracts/release/installations.json';
  final timeout = Duration(
    seconds: int.tryParse(option('timeout-seconds') ?? '') ?? 20,
  );
  final summary = option('summary');
  if (track == null || track.isEmpty) {
    stderr.writeln(
      'usage: dart tool/release_gate.dart --track <alpha|production> [--root <dir>]',
    );
    exitCode = 64;
    return;
  }

  final Installation installation;
  final CandidateNeeds needs;
  try {
    installation = installationFor(File(mapPath).readAsStringSync(), track);
    needs = readCandidateNeeds(root);
  } on Exception catch (e) {
    // Without a named installation or a readable requirement there is no
    // evidence either way: not verified, nothing is published.
    stdout.writeln('Installation gate: not verified — $e');
    if (summary != null) {
      File(summary).writeAsStringSync(
        '## Installation gate\n\nNot verified: $e\n',
        mode: FileMode.append,
      );
    }
    exitCode = ReleaseVerdict.unverified.exitCode;
    return;
  }

  final schema = await callInstallation(
    installation,
    'deskilo_schema_version',
    timeout: timeout,
  );
  final floor = await callInstallation(
    installation,
    'deskilo_app_floor',
    timeout: timeout,
  );
  final result = judgeInstallation(needs: needs, schema: schema, floor: floor);
  final report = renderGate(
    track: track,
    installation: installation,
    needs: needs,
    result: result,
  );
  stdout.write(report);
  if (summary != null)
    File(summary).writeAsStringSync(report, mode: FileMode.append);
  if (result.verdict != ReleaseVerdict.sufficient) {
    stdout.writeln(
      '::error::the installation of the $track track is not proven ready: ${result.verdict.name}',
    );
  }
  exitCode = result.verdict.exitCode;
}
