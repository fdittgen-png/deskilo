// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4492 -- a loss says why. The invariant: goods written off carry a cause from the fixed list, and a note when the
// person wrote one; a loss without its cause is refused and moves nothing; the movement keeps what it was written with
// and shows it. Proven on the rules (a pure check), on the Demo's port (the server's rule in memory: refusal, nothing
// moved, the same loss taken once it says why, a retried request answers once) and on what a movement reads and shows
// (a cause this app does not know is shown as it came, never taken for a known one).
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_operations.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_operations.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/presentation/stock_loss_text.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

final _en = AppLocalizationsEn();

Map<String, Object?> _row({String reason = 'loss', String? cause, String? note}) => {
  'workspace_id': 'ws-1',
  'id': 'm-1',
  'item_id': 'i-1',
  'item_name': 'Yoghurt',
  'from_location_id': 'p-1',
  'from_location_code': 'MAIN',
  'to_location_id': 'p-9',
  'to_location_code': 'LOSS',
  'quantity': '1',
  'unit': 'piece',
  'entered_quantity': '1',
  'entered_unit': 'piece',
  'occurred_at': '2026-11-26T10:00:00Z',
  'reason': reason,
  'loss_cause': cause,
  'loss_note': note,
};

void main() {
  test('a loss says why, and its note has a length', () {
    expect(checkStockLoss(null, ''), StockLossProblem.causeMissing);
    expect(checkStockLoss(null, 'x' * 600), StockLossProblem.causeMissing, reason: 'the cause is asked first');
    expect(checkStockLoss(StockLossCause.expired, ''), isNull);
    expect(checkStockLoss(StockLossCause.other, 'x' * kStockLossNoteMaxLength), isNull);
    expect(checkStockLoss(StockLossCause.other, 'x' * (kStockLossNoteMaxLength + 1)), StockLossProblem.noteTooLong);
    expect(checkStockLoss(StockLossCause.other, '  ${'x' * kStockLossNoteMaxLength}  '), isNull, reason: 'the note counts as it is sent, trimmed');
    expect([const StockLoss(cause: StockLossCause.damaged, note: '  dropped  ').noteOrNull, const StockLoss(cause: StockLossCause.damaged, note: '   ').noteOrNull], ['dropped', null]);
    expect([for (final c in StockLossCause.values) c.wire], ['expired', 'damaged', 'spoiled', 'missing', 'other'], reason: 'the server\'s list, in the order the sheet offers it');
  });

  group('the Demo keeps the loss command\'s rule', () {
    late DemoStockLedger ledger;
    late DemoStockOperations operations;
    late String main;

    setUp(() async {
      final config = DemoStockConfigCommands('ws-1');
      ledger = DemoStockLedger('ws-1', config);
      operations = DemoStockOperations(ledger);
      main = (await config.places('ws-1')).firstWhere((p) => p.code == 'MAIN').id;
    });

    List<StockLineDraft> mugs(String quantity) => [StockLineDraft(itemId: 'demo-item-mugs', quantity: quantity, fromLocationId: main)];

    test('a loss without a cause is refused and moves nothing; with its cause the same loss is taken', () async {
      final before = ledger.balance('demo-item-mugs', main).text;
      final moves = ledger.movements.length;
      await expectLater(
        operations.takeOut('ws-1', StockTakeOutReason.loss, mugs('1'), 'req-1'),
        throwsA(isA<StockConfigRefused>().having((e) => (e.field, e.reason), 'what is refused', ('cause', StockRefusal.required))),
      );
      expect([ledger.balance('demo-item-mugs', main).text, ledger.movements.length], [before, moves]);
      // recovery: the same request, now saying why
      final done = await operations.takeOut('ws-1', StockTakeOutReason.loss, mugs('1'), 'req-1', loss: const StockLoss(cause: StockLossCause.damaged, note: ' chipped '));
      expect(done.movements, 1);
      final lost = ledger.movements.first;
      expect([lost.reason, lost.lossCause, lost.lossNote], ['loss', 'damaged', 'chipped']);
      expect(ledger.movements.length, moves + 1);
    });

    test('a note beyond its length is refused and moves nothing', () async {
      final moves = ledger.movements.length;
      await expectLater(
        operations.takeOut('ws-1', StockTakeOutReason.loss, mugs('1'), 'req-2', loss: StockLoss(cause: StockLossCause.other, note: 'x' * (kStockLossNoteMaxLength + 1))),
        throwsA(isA<StockConfigRefused>().having((e) => (e.field, e.reason), 'what is refused', ('note', StockRefusal.tooLong))),
      );
      expect(ledger.movements.length, moves);
    });

    test('a loss sent again answers once', () async {
      const loss = StockLoss(cause: StockLossCause.expired);
      await operations.takeOut('ws-1', StockTakeOutReason.loss, mugs('1'), 'req-3', loss: loss);
      final moves = ledger.movements.length;
      await operations.takeOut('ws-1', StockTakeOutReason.loss, mugs('1'), 'req-3', loss: loss);
      expect(ledger.movements.length, moves);
    });

    test('goods the business uses carry no cause, whatever is passed beside them', () async {
      await operations.takeOut('ws-1', StockTakeOutReason.consumption, mugs('1'), 'req-4', loss: const StockLoss(cause: StockLossCause.damaged, note: 'not a loss'));
      final used = ledger.movements.first;
      expect([used.reason, used.lossCause, used.lossNote], ['consumption', null, null]);
    });
  });

  test('a movement reads the cause and the note of its loss; another movement has none', () {
    final lost = StockMovementRow.fromJson(_row(cause: 'spoiled', note: 'left in the sun'));
    expect([lost.lossCause, lost.lossNote], ['spoiled', 'left in the sun']);
    final old = StockMovementRow.fromJson(_row());
    expect([old.lossCause, old.lossNote], [null, null], reason: 'a loss recorded without a cause has none: nothing is guessed');
    final received = StockMovementRow.fromJson(_row(reason: 'receipt')..remove('loss_cause')..remove('loss_note'));
    expect(received.lossCause, isNull, reason: 'an answer of a server that does not know the cause yet');
  });

  test('every cause has its words; one this app does not know is shown as it came', () {
    expect({for (final c in StockLossCause.values) stockLossCauseText(_en, c.wire)}.length, StockLossCause.values.length);
    expect(stockLossCauseText(_en, 'expired'), _en.stockLossCauseExpired);
    expect(stockLossCauseText(_en, 'recalled'), 'recalled');
    expect(stockLossProblemText(_en, StockLossProblem.causeMissing), ('cause', _en.stockLossCauseRequired));
    expect(stockLossProblemText(_en, StockLossProblem.noteTooLong), ('note', _en.stockLossNoteTooLong));
  });
}
