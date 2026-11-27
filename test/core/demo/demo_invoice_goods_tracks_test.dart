// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4436 (G21) -- a goods line sold in the Demo names the lots it took: a store holding two lots of an item sells
// from the one received first and then the next, and the issued invoice freezes both with their quantities; an item
// held without a lot leaves no track.
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/money/demo_standalone_invoice_commands.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/seed/demo_london_seed.dart';
import 'package:deskilo/features/money/domain/standalone_invoice.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/standalone_invoice_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/real_async.dart';

void main() {
  late DemoFixture fixture;
  late ProviderContainer container;
  late String workspaceId;
  late String customer;

  setUp(() async {
    fixture = DemoFixture.build();
    container = ProviderContainer(overrides: demoOverrides(fixture))
      ..listen(currentWorkspaceProvider, (_, _) {});
    await container.read(currentWorkspaceProvider.future);
    workspaceId = demoLondonSpaceId;
    container.read(activeWorkspaceIdProvider.notifier).activate(workspaceId);
    expect((await container.read(currentWorkspaceProvider.future))?.id, workspaceId);
    // the Demo seeds its archive after the space opens: wait for it, so no
    // seeding lands between an issue and the reading of its invoice
    await untilReal(
      () async => (await container.read(invoiceQueriesProvider).fetchInvoices(workspaceId)).isNotEmpty,
      what: 'the demo archive',
    );
    final members = await container.read(workspaceMembersProvider.future);
    customer = members.firstWhere((m) => !m.isKiosk).id;
  });
  tearDown(() => container.dispose());

  StandaloneDraft goodsDraft(String itemId, String quantity) => StandaloneDraft(
    subjectMemberId: customer,
    serviceDate: fixture.seededAt,
    dueOn: fixture.seededAt.add(const Duration(days: 30)),
    lines: [
      StandaloneLine(
        description: 'Goods',
        quantity: quantity,
        unitCode: 'piece',
        unitLabel: 'pc',
        unEceCode: 'C62',
        unitPrice: '20',
        supply: 'goods',
        itemId: itemId,
      ),
    ],
  );

  late DemoStockLedger ledger;
  late DemoStandaloneInvoiceCommands commands;

  setUp(() async {
    // a ledger of its own: the shirt has no stock yet, so the lots below are all it holds
    ledger = DemoStockLedger(workspaceId, DemoStockConfigCommands(workspaceId));
    commands = container.read(standaloneInvoiceCommandsProvider) as DemoStandaloneInvoiceCommands..goods = ledger;
    final shirt = DemoStockLedger.items.firstWhere((i) => i.id == 'demo-item-shirt');
    for (final (id, code) in [('lot-1', 'EARLY'), ('lot-2', 'LATE')]) {
      await ledger.post(DemoStockPost(
        item: shirt,
        quantity: ExactQuantity.parse('3'),
        from: 'demo-place-supplier',
        to: 'demo-place-main',
        reason: 'receipt',
        lotId: id,
        lotCode: code,
      ));
    }
  });

  Future<Invoice> issued(StandaloneDraft draft, String request) async {
    final saved = await commands.saveDraft(workspaceId: workspaceId, draft: draft);
    final done = await commands.issue(workspaceId: workspaceId, draftId: saved.draftId, revision: saved.revision, requestId: request);
    final all = await container.read(invoiceQueriesProvider).fetchInvoices(workspaceId);
    return all.firstWhere((i) => i.id == done.invoiceId);
  }

  test('4 shirts from two lots of 3: the invoice freezes EARLY x3 and LATE x1, and the stock shows it', () async {
    final invoice = await issued(goodsDraft('demo-item-shirt', '4'), 'req-lots');
    final lineId = invoice.lines.single.commercialLineId!;
    expect(invoice.lineTracks[lineId]!.map((t) => t.text), ['EARLY ×3', 'LATE ×1']);
    expect(ledger.balance('demo-item-shirt', 'demo-place-main', lotId: 'lot-1').text, '0');
    expect(ledger.balance('demo-item-shirt', 'demo-place-main', lotId: 'lot-2').text, '2');
  });

  test('more than the lots hold is refused as before, and moves nothing', () async {
    final saved = await commands.saveDraft(workspaceId: workspaceId, draft: goodsDraft('demo-item-shirt', '7'));
    final preview = await commands.preview(workspaceId: workspaceId, draftId: saved.draftId, revision: saved.revision);
    expect(preview.missing, ['line_1_stock_not_enough']);
    expect(ledger.balance('demo-item-shirt', 'demo-place-main', lotId: 'lot-1').text, '3');
  });

  test('an item held without a lot sells as before and freezes no track', () async {
    final mugs = DemoStockLedger.items.firstWhere((i) => i.id == 'demo-item-mugs');
    final held = ledger.balance(mugs.id, 'demo-place-main');
    final invoice = await issued(goodsDraft(mugs.id, '1'), 'req-loose');
    expect(invoice.lineTracks, isEmpty);
    expect((held - ledger.balance(mugs.id, 'demo-place-main')).text, '1');
  });

  StandaloneDraft mugsIn(String unit, String quantity) => StandaloneDraft(
    subjectMemberId: customer,
    serviceDate: fixture.seededAt,
    dueOn: fixture.seededAt.add(const Duration(days: 30)),
    lines: [
      StandaloneLine(
        description: 'Mugs',
        quantity: quantity,
        unitCode: unit,
        unitLabel: unit,
        unitPrice: '11',
        supply: 'goods',
        itemId: 'demo-item-mugs',
      ),
    ],
  );

  test('#4479 two cartons of mugs (12 each) leave 24 pieces: the stock moves in the inventory unit', () async {
    final held = ledger.balance('demo-item-mugs', 'demo-place-main');
    await issued(mugsIn('carton', '2'), 'req-carton');
    expect((held - ledger.balance('demo-item-mugs', 'demo-place-main')).text, '24');
  });

  test('#4479 a unit the item has no conversion from is refused naming the unit, and moves nothing', () async {
    final held = ledger.balance('demo-item-mugs', 'demo-place-main');
    final saved = await commands.saveDraft(workspaceId: workspaceId, draft: mugsIn('kg', '1'));
    final preview = await commands.preview(workspaceId: workspaceId, draftId: saved.draftId, revision: saved.revision);
    expect(preview.missing, ['line_1_unit']);
    expect(ledger.balance('demo-item-mugs', 'demo-place-main'), held);
  });
}
