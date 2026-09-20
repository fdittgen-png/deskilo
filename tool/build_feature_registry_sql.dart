// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1333 — prints `public.feature_registry()` generated from featureManifest.
//
//   dart run tool/build_feature_registry_sql.dart
//
// Paste the output into a new migration whenever a feature is added,
// removed, re-parented or changes its default; feature_registry_sql_test
// fails until the latest definition matches.
import 'dart:io';

import 'package:deskilo/features/workspace/domain/feature_registry_sql.dart';

void main() => stdout.writeln(featureRegistrySql());
