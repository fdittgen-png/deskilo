// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 — prints `public.accounting_connection_targets()` generated from
// the app's accounting target registry.
//
//   dart run tool/build_accounting_targets_sql.dart
//
// Paste the output into a new migration whenever a target that connects is
// added or removed, or changes how it is connected;
// accounting_targets_sql_test fails until the latest definition matches.
import 'dart:io';

import 'package:deskilo/features/money/domain/accounting_target_registry_sql.dart';

void main() => stdout.writeln(accountingConnectionTargetsSql());
