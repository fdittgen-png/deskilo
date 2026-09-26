// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1655 — prints `public.template_field_registry()` generated from
// templateFieldRegistry().
//
//   dart run tool/build_template_field_registry_sql.dart
//
// Paste the output into a new migration whenever a field record is added,
// removed or changes its disposition; template_field_registry_sql_test
// fails until the latest definition matches.
import 'dart:io';

import 'package:deskilo/features/workspace/domain/template_field_registry_sql.dart';

void main() => stdout.writeln(templateFieldRegistrySql());
