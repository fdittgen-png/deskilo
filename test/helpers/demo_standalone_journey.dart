// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4165 — the journey of a standalone customer invoice in the reference
// business, through the app's providers and commands on a Demo scope of its
// own: shared by the scenario checklist.
import 'package:deskilo/features/money/domain/command_receipt.dart';
import 'package:deskilo/features/money/domain/payment_claims.dart';
import 'package:deskilo/features/money/domain/standalone_invoice.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/standalone_invoice_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import 'demo_outbox_journeys.dart' show withDemoSession;

/// The owner invoices 1.5 hours at 80.00 to a customer with no booking behind
/// it: the preview and the issued invoice carry the exact quantity and the
/// server's net, and a second issue under the same request is the same invoice;
/// the customer then declares it paid in one declaration of its own kind.
Future<bool> standaloneInvoiceJourney() =>
    withDemoSession((fixture, outbox, c) async {
      c.listen(currentWorkspaceProvider, (_, _) {});
      await c.read(currentWorkspaceProvider.future);
      final members = await c.read(workspaceMembersProvider.future);
      final customer = members.firstWhere((m) => !m.isKiosk).id;
      final commands = c.read(standaloneInvoiceCommandsProvider);
      final saved = await commands.saveDraft(
        workspaceId: 'ws-1',
        draft: StandaloneDraft(
          subjectMemberId: customer,
          serviceDate: fixture.seededAt,
          dueOn: fixture.seededAt.add(const Duration(days: 30)),
          lines: const [
            StandaloneLine(
              description: 'Consulting',
              quantity: '1.5',
              unitCode: 'hour',
              unitLabel: 'h',
              unEceCode: 'HUR',
              unitPrice: '80',
            ),
          ],
        ),
      );
      final preview = await commands.preview(
        workspaceId: 'ws-1',
        draftId: saved.draftId,
        revision: saved.revision,
      );
      final first = await commands.issue(
        workspaceId: 'ws-1',
        draftId: saved.draftId,
        revision: saved.revision,
        requestId: 'scenario-standalone',
      );
      final again = await commands.issue(
        workspaceId: 'ws-1',
        draftId: saved.draftId,
        revision: saved.revision,
        requestId: 'scenario-standalone',
      );
      final receipt = await c.read(invoiceQueriesProvider).invoiceCommandOutcome(
        workspaceId: 'ws-1',
        requestId: 'scenario-standalone',
      );
      // #4165 B2 — the customer declares it paid, as invoices without a month
      // are paid: one declaration, spent only on that invoice
      final declared = await fixture.money.accountCommands.declareInvoicesPaid(
        workspaceId: 'ws-1',
        memberId: customer,
        claim: InvoiceClaim.standalone(
          amountCents: preview.totalCents,
          invoiceIds: [first.invoiceId],
        ),
      );
      final event = fixture.events.events.firstWhere((e) => e.id == declared);
      return preview.ready &&
          event.payload['allocation_mode'] == 'explicit' &&
          fixture.money.claims[declared]?.single == first.invoiceId &&
          preview.lines.single.quantityText == '1.5' &&
          receipt.state == CommandReceiptState.applied &&
          receipt.invoiceId == first.invoiceId &&
          again.replayed &&
          again.invoiceId == first.invoiceId;
    });
