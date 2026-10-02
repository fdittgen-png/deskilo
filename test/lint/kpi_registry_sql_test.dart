// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1921 — the server's KPI registry IS the Dart catalogue, and the
// catalogue's disclosure rules hold for every entry.
//
// `kpi_readable(ws, kpi)` decides every KPI read from `kpi_registry()`.
// A KPI added in Dart without the server's copy would be unreadable; a
// copy that drifted would grant or refuse the wrong people. So the latest
// migration defining the registry must hold exactly `kpiRegistryJson()`.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter_test/flutter_test.dart';

const _definition = 'create or replace function public.kpi_registry()';

Map<String, dynamic>? _latestRegistry() {
  final files =
      Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files.reversed) {
    final sql = f.readAsStringSync();
    final at = sql.indexOf(_definition);
    if (at < 0) continue;
    final open = sql.indexOf("select '", at) + "select '".length;
    final close = sql.indexOf("'::jsonb", open);
    return jsonDecode(sql.substring(open, close)) as Map<String, dynamic>;
  }
  return null;
}

void main() {
  test('the latest kpi_registry() is the Dart catalogue', () {
    final stored = _latestRegistry();
    expect(stored, isNotNull, reason: 'no migration defines kpi_registry()');
    expect(
      jsonEncode(stored),
      kpiRegistryJson(),
      reason: 'regenerate the registry into a new migration',
    );
  });

  group('every KPI says what it discloses and asks for it', () {
    final wire = {for (final p in WorkspacePermission.values) p.wireName};

    for (final k in kpiCatalogue) {
      test(k.id, () {
        expect(k.permissions, isNotEmpty);
        expect(
          wire.containsAll(k.permissions),
          isTrue,
          reason: 'only catalogued permissions',
        );
        expect(
          k.permissions,
          isNot(equals(['exportData'])),
          reason: 'exportData alone never reads',
        );
        switch (k.disclosure) {
          case KpiDisclosure.aggregateOperational:
          case KpiDisclosure.own:
            break;
          case KpiDisclosure.financial:
            expect(k.permissions, contains('viewFinances'));
          case KpiDisclosure.personalOperational:
            expect(k.permissions, contains('viewPersonalData'));
            expect(
              k.minCohort,
              isNotNull,
              reason: 'a figure about people needs a minimum cohort',
            );
        }
      });
    }
  });
}
