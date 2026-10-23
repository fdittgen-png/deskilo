// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2867 — writes the setup step catalogue to contracts/setup/steps.json
// and prints the server's setup_step_catalogue() for a migration, then
// the server's setup_level_catalogue().
//
//   dart run tool/build_setup_steps.dart          # write the JSON, print the SQL
import 'dart:io';

import 'package:deskilo/features/workspace/domain/setup_level_catalogue.dart';
import 'package:deskilo/features/workspace/domain/setup_steps.dart';

void main() {
  File('contracts/setup/steps.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(setupStepsJson());
  stdout
    ..writeln(setupStepCatalogueSql())
    ..writeln()
    ..writeln(setupLevelCatalogueSql());
}
