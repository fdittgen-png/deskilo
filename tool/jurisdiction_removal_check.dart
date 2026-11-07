// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3337 -- can a jurisdiction module be physically removed?
//
//   dart run tool/jurisdiction_removal_check.dart deskilo_jurisdiction_it
//   dart run tool/jurisdiction_removal_check.dart <module> --facts facts.json
//
// facts.json is the answer of `jurisdiction_removal_facts_v1(workspace,
// provider, format)` for one space -- what a source tree cannot show:
// `enabled_capabilities`, `unsettled_transmissions`, `needed_correction_routes`,
// each a list of objects with ids. Without it only the source half is checked
// and the output says so. Exit 0 = nothing found, 1 = blocked, 2 = usage.
import 'dart:convert';
import 'dart:io';

import 'jurisdiction_removal/removal_check.dart';

void main(List<String> args) {
  final positional = [for (final a in args) if (!a.startsWith('--')) a];
  if (positional.isEmpty) {
    stderr.writeln('usage: jurisdiction_removal_check <module> [--facts file]');
    exitCode = 2;
    return;
  }
  RemovalFacts? facts;
  final at = args.indexOf('--facts');
  if (at >= 0 && at + 1 < args.length) {
    facts = RemovalFacts.fromJson(
      jsonDecode(File(args[at + 1]).readAsStringSync()) as Map<String, Object?>,
    );
  }
  final report = removalCheck('.', positional.first, facts: facts);
  for (final b in report.blockers) {
    stdout.writeln('BLOCKED  $b');
  }
  if (!report.runtime) {
    stdout.writeln(
      'NOT CHECKED  enabled capabilities, pending submissions, correction '
      'routes (supply --facts)',
    );
  }
  stdout.writeln(
    report.removable
        ? '${report.module}: nothing found that needs it'
        : '${report.module}: cannot be removed',
  );
  exitCode = report.removable ? 0 : 1;
}
