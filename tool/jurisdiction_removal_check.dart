// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3337 -- can a jurisdiction module be physically removed?
//
//   dart run tool/jurisdiction_removal_check.dart deskilo_jurisdiction_it
//   dart run tool/jurisdiction_removal_check.dart <module> --facts facts.json
//
// facts.json is what a source tree cannot show, read from the instance:
// `jurisdiction_removal_facts_installation_v1(provider, format)` (the operator's
// whole-installation answer, grouped by space) or `jurisdiction_removal_facts_v1`
// (one space under its manager). Removing a module is an installation decision,
// so only the installation answer can make it "proven"; a one-space answer is
// reported as not covering the other spaces.
//
// Exit 0 = proven (source half and the whole installation), 1 = blocked,
// 2 = usage, 3 = nothing found but not proven (a half was not checked).
import 'dart:convert';
import 'dart:io';

import 'jurisdiction_removal/removal_check.dart';

void main(List<String> args) {
  final positional = [
    for (final a in args)
      if (!a.startsWith('--')) a,
  ];
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
      'NOT CHECKED  enabled capabilities, unsettled transmissions, correction '
      'routes of ANY space (supply --facts from '
      'jurisdiction_removal_facts_installation_v1)',
    );
  } else if (!report.installation) {
    stdout.writeln(
      'NOT CHECKED  the other spaces: this answer is one space\'s; removing a '
      'module is an installation decision (use '
      'jurisdiction_removal_facts_installation_v1)',
    );
  }
  if (!report.removable) {
    stdout.writeln('${report.module}: cannot be removed');
    exitCode = 1;
  } else if (!report.proven) {
    stdout.writeln(
      '${report.module}: nothing found in what was checked -- NOT a proof',
    );
    exitCode = 3;
  } else {
    stdout.writeln('${report.module}: nothing found that needs it');
  }
}
