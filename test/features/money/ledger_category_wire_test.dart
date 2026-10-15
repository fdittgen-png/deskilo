// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2570 — the ledger categories the database accepts are exactly the ones
// the app can read.
import 'dart:io';

import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:flutter_test/flutter_test.dart';

/// #2570 — the ledger categories the database accepts are exactly the ones
/// the app can read: the last migration that rewrote
/// `ledger_entries_category_check` names every `LedgerCategory`.
void main() {
  test('the latest ledger category check lists every LedgerCategory', () {
    final files =
        Directory('supabase/migrations')
            .listSync()
            .whereType<File>()
            .where(
              (f) => f.readAsStringSync().contains(
                'add constraint ledger_entries_category_check',
              ),
            )
            .map((f) => f.path)
            .toList()
          ..sort();
    final sql = File(files.last).readAsStringSync();
    final check = sql.substring(
      sql.indexOf('add constraint ledger_entries_category_check'),
    );
    final listed = RegExp(r"'([a-z]+)'")
        .allMatches(check.substring(0, check.indexOf(');')))
        .map((m) => m.group(1)!)
        .toSet();
    expect(listed, LedgerCategory.values.map((c) => c.name).toSet());
  });
}
