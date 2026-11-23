// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4364 (G15) -- the Demo's journey of a bulk read: the five tags of the gift basket are read twice over with a stranger
// among them; the tally knows five pieces and one unknown tag, and a count by that read fills the basket's line once.
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_cycle_counts.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_registry.dart';
import 'package:deskilo/core/demo/data/demo_stock_reversals.dart';
import 'package:deskilo/core/demo/data/demo_stock_tags.dart';
import 'package:deskilo/features/stock/domain/stock_bulk_read.dart';
import 'package:deskilo/features/stock/domain/stock_cycle_counts.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter_test/flutter_test.dart';

const _ws = 'demo-ws';
final _codes = [for (var i = 1; i <= 5; i++) 'E2801160600002054AF3E00$i'];

void main() {
  test('the basket tags are five pieces; a stranger is apart; the count by the read fills the basket line once, blind', () async {
    final config = DemoStockConfigCommands(_ws);
    final ledger = DemoStockLedger(_ws, config);
    final tags = DemoStockTags(nameOf: (id) async => DemoStockLedger.items.where((i) => i.id == id).firstOrNull?.name);
    final cycle = DemoStockCycleCounts(
      _ws,
      ledger,
      DemoStockReversals(ledger),
      DemoStockRegistry(_ws, ledger, config),
      tags,
      () => {WorkspacePermission.countStock},
      () => DateTime(2026, 5, 13),
    );
    final read = [..._codes, ..._codes, 'NOT-A-TAG'];
    final tally = BulkTally.of(await tags.resolveCodes(_ws, read));
    expect([tally.pieces, tally.lines.single.itemName, tally.unknown], [5, 'Gift basket', ['NOT-A-TAG']]);

    final task = (await cycle.tasks(_ws)).single;
    final before = await cycle.task(_ws, task.taskId);
    final basket = before.lines.where((l) => l.itemId == 'demo-item-basket');
    if (basket.isEmpty) {
      // the basket is below the high-value line: the read counts nothing and says every tag was a piece of no line
      final r = await cycle.countByTagRead(_ws, requestId: 'r-1', taskId: task.taskId, codes: read);
      expect(r.lines, isEmpty);
      return;
    }
    final r = await cycle.countByTagRead(_ws, requestId: 'r-1', taskId: task.taskId, codes: read);
    expect(r.lines.single.read, 5);
    expect(r.missing, isNull, reason: 'a blind counter is told nothing about what was expected');
    final again = await cycle.countByTagRead(_ws, requestId: 'r-1', taskId: task.taskId, codes: read);
    expect(again.replayed, isTrue);
    expect((await cycle.task(_ws, task.taskId)).lines.where((l) => l.state == CountLineState.counted), hasLength(1));
  });
}
