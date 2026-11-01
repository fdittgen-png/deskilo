// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 — the server's list of connectable accounting targets IS the app's
// target registry.
//
// `open_accounting_connection_v1` refuses a target id, or a way of
// connecting it, that `public.accounting_connection_targets()` does not
// name. A target added to `accountingTargets` without the server's copy
// could not be connected; a copy that drifted would accept a target the
// app does not define. So the latest migration defining the function must
// hold exactly what `tool/build_accounting_targets_sql.dart` prints.
import 'dart:convert';

import 'package:deskilo/features/money/domain/accounting_format.dart';
import 'package:deskilo/features/money/domain/accounting_target_registry_sql.dart';
import 'package:flutter_test/flutter_test.dart';
import 'lint_sources.dart';

const _definition =
    'create or replace function public.accounting_connection_targets()';

({String file, String sql})? _latest() {
  for (final f in sqlFiles('supabase/migrations').reversed) {
    final sql = f.readAsStringSync();
    if (sql.contains(_definition)) {
      return (file: f.uri.pathSegments.last, sql: sql);
    }
  }
  return null;
}

void main() {
  test('the latest accounting_connection_targets() is the Dart registry', () {
    final latest = _latest();
    expect(latest, isNotNull,
        reason: 'no migration defines accounting_connection_targets()');
    expect(
      latest!.sql.contains(accountingConnectionTargetsSql()),
      isTrue,
      reason: '${latest.file} is stale: run '
          'dart run tool/build_accounting_targets_sql.dart into a new migration',
    );
  });

  test('every target that connects is listed with exactly its ways', () {
    final listed =
        jsonDecode(accountingConnectionTargetsJson()) as Map<String, dynamic>;
    expect(listed, {
      for (final t in accountingTargets)
        if (t.connectsBy.isNotEmpty)
          t.id: ([for (final k in t.connectsBy) k.wire]..sort()),
    });
    // A file target connects by nothing and is never listed.
    for (final t in accountingTargets) {
      if (t.connectsBy.isEmpty) expect(listed, isNot(contains(t.id)));
    }
  });
}
