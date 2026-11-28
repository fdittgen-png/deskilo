// SPDX-License-Identifier: AGPL-3.0-or-later
// #4512 — the Demo keeps the expense categories under the rules the server applies: the five a business starts with, a name for every
// category that is not built in, an active name kept once (case-folded), a code that never moves, nothing deleted, retired not offered.
import 'package:deskilo/core/demo/data/money/demo_expense_categories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

Matcher _refused(String detail) =>
    throwsA(isA<PostgrestException>().having((e) => e.code, 'code', 'DKX01').having((e) => e.details, 'details', detail));

void main() {
  test('a business starts with coffee, supplies, equipment and other, and the retired scheduled', () async {
    final all = await DemoExpenseCategories().categories('ws');
    expect([for (final c in all) c.code], ['coffee', 'supplies', 'equipment', 'other', 'scheduled']);
    expect([for (final c in all) c.retired], [false, false, false, false, true]);
    expect(all.every((c) => c.builtIn && c.label.isEmpty), isTrue);
  });

  test('a new category has a name, kept once among the active ones', () async {
    final repo = DemoExpenseCategories();
    await expectLater(repo.save('ws', label: ' ', requestId: 'r1'), _refused('label_required'));
    final made = await repo.save('ws', label: 'Cleaning', requestId: 'r2');
    expect(made.builtIn, isFalse);
    await expectLater(repo.save('ws', label: ' CLEANING ', requestId: 'r3'), _refused('label_taken'));
  });

  test('a retired category frees its name; bringing it back meets an active one of the same name', () async {
    final repo = DemoExpenseCategories();
    final first = await repo.save('ws', label: 'Cleaning', requestId: 'r1');
    await repo.setRetired('ws', first.id, retired: true, requestId: 'r2');
    final second = await repo.save('ws', label: 'cleaning', requestId: 'r3');
    expect(second.id, isNot(first.id));
    await expectLater(repo.setRetired('ws', first.id, retired: false, requestId: 'r4'), _refused('label_taken'));
  });

  test('a rename keeps the code; an unknown category is refused; the workspaces are apart', () async {
    final repo = DemoExpenseCategories();
    final coffee = (await repo.categories('ws')).first;
    final renamed = await repo.save('ws', id: coffee.id, label: 'Tea and coffee', requestId: 'r1');
    expect(renamed.code, 'coffee');
    await expectLater(repo.save('ws', id: 'nope', label: 'x', requestId: 'r2'), _refused('expense_category_unknown'));
    expect((await repo.categories('other')).first.label, isEmpty);
  });
}
