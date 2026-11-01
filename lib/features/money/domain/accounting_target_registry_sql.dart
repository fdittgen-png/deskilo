// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 — the targets a connection may be opened for, as the database
// reads them.
//
// `open_accounting_connection_v1` refuses a target id the app does not
// define, and a way of connecting the target does not take. The list is
// the app's descriptor ([accountingTargets], [AccountingTarget.connectsBy]),
// never typed a second time: `public.accounting_connection_targets()` carries
// the text GENERATED here (`dart run tool/build_accounting_targets_sql.dart`),
// and `accounting_targets_sql_test` requires the latest migration defining
// the function to hold exactly it, so a target added in Dart without the
// server's copy fails the build and names the target.
import 'package:meta/meta.dart';

import 'accounting_format.dart' show accountingTargets;

/// Per connectable target id (sorted), the wire names of the ways it is
/// connected (sorted). File targets connect by nothing and are absent.
@visibleForTesting
String accountingConnectionTargetsJson() {
  final byId = <String, List<String>>{
    for (final t in accountingTargets)
      if (t.connectsBy.isNotEmpty)
        t.id: [for (final k in t.connectsBy) k.wire]..sort(),
  };
  final ids = byId.keys.toList()..sort();
  final lines = [
    for (final id in ids)
      '    "$id": [${byId[id]!.map((k) => '"$k"').join(', ')}]',
  ];
  return '{\n${lines.join(',\n')}\n  }';
}

/// The whole `create or replace function` statement for a migration.
///
/// `immutable`: the list is compiled into the schema; it changes only when
/// a migration replaces the function.
String accountingConnectionTargetsSql() => '''
create or replace function public.accounting_connection_targets()
returns jsonb
language sql
immutable
set search_path = public
as \$\$
  select '${accountingConnectionTargetsJson()}'::jsonb
\$\$;''';
