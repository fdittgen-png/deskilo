// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2585 C2 — void and refund carry a request id. The act is sent once; a lost
// answer is read back by THAT id (never by "the newest invoice"), and nothing
// here ever sends it a second time.
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/failure/app_failure.dart';
import 'package:deskilo/core/validation/pending_validation.dart';
import 'package:deskilo/features/money/application/invoice_action.dart';
import 'package:deskilo/features/money/domain/command_receipt.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';

/// The act commits on the fake, then the answer is lost (or held).
class _Commands extends FakeInvoiceActionCommands {
  // ignore: use_super_parameters
  _Commands(FakeMoneyRepository repo) : super(repo);

  int sends = 0;
  Object? answer = const JsonShapeException(
    'request_invoice_void_v1',
    'pending',
    'bool',
    'null',
  );

  @override
  Future<void> voidInvoice(
    String invoiceId, {
    required String requestId,
    String reason = '',
  }) async {
    sends++;
    await super.voidInvoice(invoiceId, requestId: requestId, reason: reason);
    final a = answer;
    if (a is Error) throw a;
    if (a is Exception) throw a;
  }
}

class _Reads extends FakeMoneyRepository {
  Exception? fails;
  CommandReceipt? forced;
  int reads = 0;

  @override
  Future<CommandReceipt> invoiceCommandOutcome({
    required String workspaceId,
    required String requestId,
  }) {
    reads++;
    final f = fails;
    if (f != null) throw f;
    return forced != null
        ? Future.value(forced)
        : super.invoiceCommandOutcome(
            workspaceId: workspaceId,
            requestId: requestId,
          );
  }
}

/// An answer that was lost.
CommandUnreached<void> _lost() =>
    CommandUnreached<void>(Defect(StateError('lost')));

void main() {
  late _Reads repo;
  late _Commands commands;
  late InvoiceReceiptActions actions;
  late String invoiceId;

  setUp(() async {
    repo = _Reads();
    repo.ledger.add(
      LedgerEntry(
        id: 'l1',
        memberId: 'member-1',
        kind: LedgerKind.charge,
        category: LedgerCategory.service,
        amountCents: 450,
        description: 'Coffee',
        period: '2026-09',
        createdAt: DateTime(2026, 9),
      ),
    );
    invoiceId = await repo.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'member-1',
      period: '2026-09',
    );
    commands = _Commands(repo);
    actions = InvoiceReceiptActions(commands, repo);
  });

  InvoiceActionAttempt attempt(String id, {String? workspace}) =>
      InvoiceActionAttempt(
        workspaceId: workspace ?? repo.invoices.first.workspaceId,
        invoiceId: invoiceId,
        kind: InvoiceActionKind.voidInvoice,
        requestId: id,
      );

  test('a lost answer after the commit is recovered by the request id, with no second send', () async {
    final sent = attempt('r1');
    final out = await actions.run(sent);
    expect(out, isA<CommandUnreached<void>>());
    expect(repo.invoices.first.isVoided, isTrue);
    final found = await actions.look(sent, out as CommandUnreached<void>);
    expect(found, isA<CommandDone<void>>());
    await actions.look(sent, out);
    expect(commands.sends, 1);
    expect(repo.reads, 2);
  });

  test(
    'a request that never committed stays unknown after every look',
    () async {
      final out = _lost();
      for (var i = 0; i < 3; i++) {
        expect(
          await actions.look(attempt('never'), out),
          isA<CommandUnreached<void>>(),
        );
      }
      expect(commands.sends, 0);
      expect(repo.invoices.first.isVoided, isFalse);
    },
  );

  test(
    'another request id, or the same id in another workspace, is not this act',
    () async {
      await actions.run(attempt('r2'));
      final other = await actions.look(attempt('r3'), _lost());
      expect(other, isA<CommandUnreached<void>>());
      final foreign = await actions.look(
        attempt('r2', workspace: 'ws-other'),
        _lost(),
      );
      expect(foreign, isA<CommandUnreached<void>>());
    },
  );

  test('held, declined and unreadable receipts', () async {
    final sent = attempt('r4');
    final unknown = _lost();
    repo.forced = const CommandReceipt(
      CommandReceiptState.pending,
      eventId: 'ev-1',
    );
    expect(
      (await actions.look(sent, unknown) as CommandHeld<void>).eventId,
      'ev-1',
    );
    repo.forced = const CommandReceipt(
      CommandReceiptState.refused,
      eventId: 'ev-1',
    );
    expect(
      (await actions.look(sent, unknown) as CommandRefused<void>).refusal.cause,
      isA<InvoiceActionDeclined>(),
    );
    repo
      ..forced = null
      ..fails = Exception('offline');
    expect(await actions.look(sent, unknown), isA<CommandUnreached<void>>());
  });

  test('a pending answer is held and a server refusal is refused', () async {
    commands.answer = const PendingValidationException('ev-2');
    expect(await actions.run(attempt('r5')), isA<CommandHeld<void>>());
    commands.answer = StateError('invoice already voided');
    expect(await actions.run(attempt('r6')), isA<CommandRefused<void>>());
  });

  test('the replay of one id acts once on the fake like the server', () async {
    commands.answer = null;
    await commands.voidInvoice(invoiceId, requestId: 'same');
    await commands.voidInvoice(invoiceId, requestId: 'same');
    expect(commands.sends, 2);
    expect(repo.invoices.where((i) => i.isVoided), hasLength(1));
  });
}
