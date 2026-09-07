// SPDX-License-Identifier: 0BSD
//
// #992 — six system columns on every table: created_datetime,
// modified_datetime, company_id, site_id, created_by_user,
// modified_by_user. Migration 0183 added them to every table that
// existed; every CREATE TABLE after it must call
// ensure_system_columns('<table>') in the same migration, so a new
// table never ships without them.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _sinceMigration = 183;

void main() {
  test('0183 carries the stamp trigger, the helper and the sweep', () {
    final sql = File('supabase/migrations/0183_system_columns.sql')
        .readAsStringSync();
    for (final piece in [
      'create or replace function public.system_columns_stamp()',
      'create or replace function public.system_column_names()',
      'zz_system_columns_stamp',
      'create or replace function public.ensure_system_columns(p_table text)',
      "table_type = 'BASE TABLE'",
      'perform public.ensure_system_columns(t.table_name)',
    ]) {
      expect(sql, contains(piece));
    }
    for (final column in [
      'created_datetime',
      'modified_datetime',
      'company_id',
      'site_id',
      'created_by_user',
      'modified_by_user',
    ]) {
      expect(sql, contains('add column if not exists $column'));
    }
  });

  test('every table created after 0183 calls ensure_system_columns in the '
      'same migration', () {
    final files = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final createTable = RegExp(
        r'create table (?:if not exists )?public\.([a-z_]+)',
        caseSensitive: false);
    final missing = <String>[];
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final number = int.tryParse(name.substring(0, 4)) ?? 0;
      if (number <= _sinceMigration) continue;
      final sql = file.readAsStringSync();
      for (final m in createTable.allMatches(sql)) {
        final table = m.group(1)!;
        if (!sql.contains("ensure_system_columns('$table')")) {
          missing.add('$name: $table');
        }
      }
    }
    expect(missing, isEmpty,
        reason: 'A new table ships with the six system columns: add '
            "`select public.ensure_system_columns('<table>');` after its "
            'CREATE TABLE (docs/AGENT_RULES.md, #992).');
  });
}
