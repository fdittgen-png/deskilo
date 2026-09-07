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

const _columns = [
  'created_datetime',
  'modified_datetime',
  'company_id',
  'site_id',
  'created_by_user',
  'modified_by_user',
];

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) =>
        f.path.endsWith('.dart') &&
        !f.path.endsWith('.g.dart') &&
        !f.path.endsWith('.freezed.dart'));

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

  test('the client never writes a system column — the server owns them', () {
    final offenders = <String>[];
    for (final file in _dartFiles('lib')) {
      if (file.path.endsWith('core/data/system_columns.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final column in _columns) {
          // A write names the column as a map KEY: `'column':`.
          if (lines[i].contains("'$column':")) {
            offenders.add('${file.path}:${i + 1}');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'The six system columns are stamped by the server (0184) '
            'and read through SystemColumns.fromRow; a client payload '
            'never names them.');
  });

  test('every row mapper hands its row to SystemColumns.fromRow', () {
    // A row mapper is recognisable by `<row>['id'] as String` inside a
    // named-argument constructor call; the stamp must sit in that call.
    final idRead = RegExp(r"(\w+)\['id'\] as String");
    final ctorCall = RegExp(r'(?:=> |return |\n\s*|: )([A-Z][A-Za-z]*)\(\s*\n');
    const notRows = {
      'SeatContext', 'ReservationLink', 'ConversationLink', 'EventLink',
      'InvoiceLink',
    };
    final missing = <String>{};
    for (final file in _dartFiles('lib')) {
      final text = file.readAsStringSync();
      for (final m in idRead.allMatches(text)) {
        final base = (m.start - 900).clamp(0, m.start);
        final before = text.substring(base, m.start);
        final ctor = ctorCall.allMatches(before).lastOrNull;
        if (ctor == null) continue;
        final name = ctor.group(1)!;
        if (notRows.contains(name)) continue;
        final call = text.substring(
            base + ctor.start, (m.end + 900).clamp(0, text.length));
        if (!call.contains('system: SystemColumns.fromRow(')) {
          missing.add('${file.path}: $name');
        }
      }
    }
    expect(missing, isEmpty,
        reason: 'An entity read from a table row carries its stamp: add '
            '`system: SystemColumns.fromRow(row)` to the constructor call '
            'and `SystemStamped` to the class (#992).');
  });
}
