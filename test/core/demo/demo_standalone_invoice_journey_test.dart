// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4165 (A2) -- a standalone customer invoice in the Demo, through the Demo's
// own composition and the application's once-only issue: a consultant invoices
// 1.5 hours, a second deliberate invoice of the same customer and month
// coexists, the same request never issues twice, a stale revision and a goods
// line are refused before an invoice exists.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/seed/demo_london_seed.dart';
import 'package:deskilo/core/failure/app_failure.dart';
import 'package:deskilo/features/money/application/issue_standalone_invoice.dart';
import 'package:deskilo/features/money/domain/standalone_invoice.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/standalone_invoice_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
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

  StandaloneDraft draft({String quantity = '1.5', String supply = 'general', String? id, int? revision}) =>
      StandaloneDraft(
        draftId: id,
        revision: revision,
        subjectMemberId: customer,
        serviceDate: fixture.seededAt,
        dueOn: fixture.seededAt.add(const Duration(days: 30)),
        lines: [
          StandaloneLine(
            description: 'Consulting',
            quantity: quantity,
            unitCode: 'hour',
            unitLabel: 'h',
            unEceCode: 'HUR',
            unitPrice: '80',
            supply: supply,
          ),
        ],
      );

  test('1.5 hours at 80.00: the preview and the issued invoice carry the exact facts', () async {
    final commands = container.read(standaloneInvoiceCommandsProvider);
    final saved = await commands.saveDraft(workspaceId: workspaceId, draft: draft());
    expect(saved.revision, 1);
    expect(saved.lines.single.lineId, isNotNull, reason: 'the line keeps its own identity');
    final preview = await commands.preview(
      workspaceId: workspaceId,
      draftId: saved.draftId,
      revision: saved.revision,
    );
    expect(preview.missing, isEmpty);
    final line = preview.lines.single;
    expect(line.quantityText, '1.5');
    expect(line.exactFacts?.amounts.netMinor, 12000);
    expect(preview.vatTotals.single.netCents, 12000);

    final outcome = await container.read(standaloneIssuanceProvider).issue(
      StandaloneIssueAttempt(
        workspaceId: workspaceId,
        draftId: saved.draftId,
        revision: saved.revision,
        requestId: 'req-1',
      ),
    );
    expect(outcome, isA<CommandDone<StandaloneIssued>>());
    final id = (outcome as CommandDone<StandaloneIssued>).value.invoiceId;
    final invoices = await container.read(invoiceQueriesProvider).fetchInvoices(workspaceId);
    final invoice = invoices.firstWhere((i) => i.id == id);
    expect(invoice.lines.single.quantityText, '1.5');
    expect(invoice.totalCents, preview.totalCents);
  });

  test('the same request never issues twice, and a second draft is its own invoice', () async {
    final commands = container.read(standaloneInvoiceCommandsProvider);
    final a = await commands.saveDraft(workspaceId: workspaceId, draft: draft());
    final first = await commands.issue(
      workspaceId: workspaceId, draftId: a.draftId, revision: a.revision, requestId: 'req-a');
    final again = await commands.issue(
      workspaceId: workspaceId, draftId: a.draftId, revision: a.revision, requestId: 'req-a');
    expect([again.invoiceId, again.replayed], [first.invoiceId, true]);
    final b = await commands.saveDraft(workspaceId: workspaceId, draft: draft(quantity: '2'));
    final second = await commands.issue(
      workspaceId: workspaceId, draftId: b.draftId, revision: b.revision, requestId: 'req-b');
    expect(second.invoiceId, isNot(first.invoiceId));
    expect(second.number, isNot(first.number));
  });

  test('a stale revision, a closed draft and a goods line naming no item are refused before an invoice exists', () async {
    final commands = container.read(standaloneInvoiceCommandsProvider);
    final a = await commands.saveDraft(workspaceId: workspaceId, draft: draft());
    final before = (await container.read(invoiceQueriesProvider).fetchInvoices(workspaceId)).length;
    final newer = await commands.saveDraft(
      workspaceId: workspaceId, draft: draft(id: a.draftId, revision: a.revision));
    expect(newer.revision, 2);
    final stale = await container.read(standaloneIssuanceProvider).issue(
      StandaloneIssueAttempt(workspaceId: workspaceId, draftId: a.draftId, revision: 1, requestId: 'req-s'));
    expect(stale, isA<CommandRefused<StandaloneIssued>>());
    final goods = await commands.saveDraft(workspaceId: workspaceId, draft: draft(supply: 'goods'));
    final p = await commands.preview(workspaceId: workspaceId, draftId: goods.draftId, revision: goods.revision);
    // #4433: goods are a supply kind now; a goods line without one of the business's items is missing its item.
    expect(p.missing, ['line_1_item']);
    final tooPrecise = await commands.saveDraft(workspaceId: workspaceId, draft: draft(quantity: '0.0000001'));
    expect((await commands.preview(workspaceId: workspaceId, draftId: tooPrecise.draftId, revision: 1)).missing,
        ['line_1_quantity']);
    expect((await container.read(invoiceQueriesProvider).fetchInvoices(workspaceId)).length, before);
  });
}
