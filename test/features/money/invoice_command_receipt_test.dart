// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2585 C2 — an issue attempt carries its own request id. A lost answer is
// recovered by reading THAT request's receipt: the original invoice id comes
// back, nothing is written again, and an invoice that merely looks like the
// attempt (same member and month) is never taken for it.
import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/validation/pending_validation.dart';
import 'package:deskilo/features/money/application/issue_invoice.dart';
import 'package:deskilo/features/money/data/command_receipt_decoder.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/command_receipt.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';

/// The server commits under the request id, then the answer is lost.
class _Server extends FakeMoneyRepository {
  CommandReceipt? receiptOnRead;
  Exception? readFails;
  bool loseAnswer = true;
  int issueCalls = 0;
  int legacyCalls = 0;
  int outcomeReads = 0;
  final readIds = <String>[];

  @override
  Future<String> issueInvoiceWithReceipt(InvoiceIssueCommand command) async {
    issueCalls++;
    await super.issueInvoiceWithReceipt(command);
    if (!loseAnswer) return 'seeded';
    throw const JsonShapeException(
      'request_invoice_issue_v1',
      'invoice_id',
      'String',
      'null',
    );
  }

  @override
  Future<String> createInvoice({
    required String workspaceId,
    required String memberId,
    required String period,
    String? replacesId,
    bool detailed = false,
    InvoiceKind kind = InvoiceKind.full,
    String buyerReference = '',
    String purchaseOrder = '',
    String correctionReason = '',
  }) {
    legacyCalls++;
    return super.createInvoice(
      workspaceId: workspaceId,
      memberId: memberId,
      period: period,
      replacesId: replacesId,
      detailed: detailed,
      kind: kind,
    );
  }

  @override
  Future<CommandReceipt> invoiceCommandOutcome({
    required String workspaceId,
    required String requestId,
  }) {
    outcomeReads++;
    readIds.add('$workspaceId|$requestId');
    final fail = readFails;
    if (fail != null) throw fail;
    return receiptOnRead != null
        ? Future.value(receiptOnRead)
        : super.invoiceCommandOutcome(
            workspaceId: workspaceId,
            requestId: requestId,
          );
  }
}

InvoiceIssueAttempt _attempt(
  String requestId, {
  String? workspaceId,
  String? replacesId,
}) => InvoiceIssueAttempt(
  workspaceId: workspaceId ?? 'ws-1',
  memberId: 'member-1',
  period: '2026-09',
  requestId: requestId,
  replacesId: replacesId,
);

/// Commits the replacement, then loses the answer.
class _LossyReplace extends FakeInvoiceActionCommands {
  // ignore: use_super_parameters
  _LossyReplace(FakeMoneyRepository repo) : super(repo);

  int sends = 0;

  @override
  Future<String> replaceInvoiceOnce(InvoiceIssueCommand c) async {
    sends++;
    await super.replaceInvoiceOnce(c);
    throw const JsonShapeException(
      'create_invoice_replacement_v1',
      'id',
      'String',
      'null',
    );
  }
}

void main() {
  late _Server server;
  late InvoiceIssuance issuance;
  setUp(() {
    server = _Server();
    issuance = InvoiceIssuance(server, server);
  });

  test(
    'a lost answer after the commit is recovered by the request id',
    () async {
      final unknown = await issuance.issue(_attempt('req-1'));
      expect(unknown, isA<InvoiceIssueUnknown>());
      final found = await issuance.look(unknown as InvoiceIssueUnknown);
      expect(found, isA<InvoiceIssued>());
      final original = (await server.fetchInvoices('ws-1')).single.id;
      expect((found as InvoiceIssued).invoiceId, original);
      // Looking twice reads again and never writes again.
      await issuance.look(unknown);
      expect(server.issueCalls, 1);
      expect(server.legacyCalls, 0);
      expect(server.outcomeReads, 2);
      expect(await server.fetchInvoices('ws-1'), hasLength(1));
    },
  );

  test(
    'another request for the same member and month is not this one',
    () async {
      // A different attempt (another actor, another id) already issued it.
      server.loseAnswer = false;
      await server.issueInvoiceWithReceipt(
        const InvoiceIssueCommand(
          workspaceId: 'ws-1',
          memberId: 'member-1',
          period: '2026-09',
          requestId: 'someone-else',
        ),
      );
      final unknown = InvoiceIssueUnknown(
        _attempt('req-2'),
        StateError('lost'),
      );
      final out = await issuance.look(unknown);
      expect(out, isA<InvoiceIssueUnknown>());
      expect(out.attempt.requestId, 'req-2');
    },
  );

  test('equal request ids in two workspaces never meet', () async {
    server.loseAnswer = false;
    await server.issueInvoiceWithReceipt(
      const InvoiceIssueCommand(
        workspaceId: 'ws-2',
        memberId: 'member-1',
        period: '2026-09',
        requestId: 'same-id',
      ),
    );
    final out = await issuance.look(
      InvoiceIssueUnknown(_attempt('same-id'), StateError('lost')),
    );
    expect(out, isA<InvoiceIssueUnknown>());
    expect(server.readIds.single, 'ws-1|same-id');
  });

  test('pending and declined receipts resolve with their event', () async {
    final unknown = InvoiceIssueUnknown(_attempt('req-3'), StateError('lost'));
    server.receiptOnRead = const CommandReceipt(
      CommandReceiptState.pending,
      eventId: 'ev-1',
    );
    expect((await issuance.look(unknown) as InvoiceIssueHeld).eventId, 'ev-1');
    server.receiptOnRead = const CommandReceipt(
      CommandReceiptState.refused,
      eventId: 'ev-1',
    );
    final declined = await issuance.look(unknown) as InvoiceIssueRefused;
    expect(declined.error, isA<InvoiceIssueDeclined>());
  });

  test('an unreadable receipt keeps the attempt unknown', () async {
    server.readFails = Exception('offline');
    final out = await issuance.look(
      InvoiceIssueUnknown(_attempt('req-4'), StateError('lost')),
    );
    expect(out, isA<InvoiceIssueUnknown>());
    expect(out.attempt.requestId, 'req-4');
  });

  test('an attempt without a request id keeps the legacy path', () async {
    const attempt = InvoiceIssueAttempt(
      workspaceId: 'ws-1',
      memberId: 'member-1',
      period: '2026-09',
      replacesId: 'inv-x',
    );
    expect(attempt.hasReceipt, isFalse);
    final out = await issuance.issue(attempt);
    expect(server.legacyCalls, 1);
    expect(server.issueCalls, 0);
    expect(out, isA<InvoiceIssueRefused>()); // unknown replaced invoice
  });

  test(
    'a replacement under a request id is recovered by it after a lost answer',
    () async {
      server.loseAnswer = false;
      final erroneous = await server.createInvoice(
        workspaceId: 'ws-1',
        memberId: 'member-1',
        period: '2026-09',
      );
      final lossy = _LossyReplace(server);
      final withActions = InvoiceIssuance(server, server, lossy);
      final attempt = InvoiceIssueAttempt(
        workspaceId: 'ws-1',
        memberId: 'member-1',
        period: '2026-09',
        replacesId: erroneous,
        correctionReason: 'R2',
        requestId: 'rep-1',
      );
      expect(attempt.hasReceipt, isTrue);
      final out = await withActions.issue(attempt);
      expect(out, isA<InvoiceIssueUnknown>());
      final found =
          await withActions.look(out as InvoiceIssueUnknown) as InvoiceIssued;
      final replacement = server.invoices.firstWhere(
        (i) => i.replacesInvoiceId == erroneous,
      );
      expect(found.invoiceId, replacement.id);
      await withActions.look(out);
      expect(lossy.sends, 1, reason: 'looking never sends again');
      expect(
        server.invoices.where((i) => i.replacesInvoiceId == erroneous),
        hasLength(1),
      );
    },
  );

  test('the pending answer of the receipt path is a hold, not a failure', () {
    expect(
      () => applyOrPending({
        'pending': true,
        'event_id': 'ev-9',
        'replayed': true,
      }),
      throwsA(isA<PendingValidationException>()),
    );
  });

  group('decodeCommandReceipt', () {
    test('every state', () {
      expect(
        decodeCommandReceipt({'state': 'not_observed'}).state,
        CommandReceiptState.notObserved,
      );
      expect(
        decodeCommandReceipt({'state': 'applied', 'invoice_id': 'i'}).invoiceId,
        'i',
      );
      expect(
        decodeCommandReceipt({'state': 'pending', 'event_id': 'e'}).eventId,
        'e',
      );
      expect(
        decodeCommandReceipt({
          'state': 'refused',
          'event_id': 'e',
          'event_status': 'rejected',
        }).state,
        CommandReceiptState.refused,
      );
    });

    test('refuses what the server did not say', () {
      for (final bad in <Object?>[
        null,
        <String, Object?>{},
        {'state': 'done'},
        {'state': 'applied'},
        {'state': 'applied', 'invoice_id': ''},
        {'state': 'pending'},
      ]) {
        expect(
          () => decodeCommandReceipt(bad),
          throwsA(isA<JsonShapeException>()),
          reason: '$bad',
        );
      }
    });
  });
}
