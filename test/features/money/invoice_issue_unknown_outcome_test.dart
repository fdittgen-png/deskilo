// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2585 — an invoice whose issue COMMITTED on the server but whose answer
// was lost or did not decode. The invariant: the command is sent exactly
// once; the person is told the outcome is unknown (no success notice, no
// generic failure that invites issuing again); "Check again" only READS the
// archive of the attempt's own workspace and, when the invoice exists, hands
// back the ORIGINAL invoice id.
import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/core/validation/pending_validation.dart';
import 'package:deskilo/features/money/application/issue_invoice.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_commands.dart';
import 'package:deskilo/features/money/domain/invoice_queries.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/screens/invoices.dart';

/// The server commits, then the answer is malformed (or never arrives).
class _LostAnswer extends FakeMoneyRepository {
  _LostAnswer({required this.commits});

  /// Whether the request reached the server before the answer was lost.
  final bool commits;
  int writes = 0;
  final fetched = <String>[];

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
  }) async {
    writes++;
    if (commits) {
      await super.createInvoice(
        workspaceId: workspaceId,
        memberId: memberId,
        period: period,
        replacesId: replacesId,
        detailed: detailed,
        kind: kind,
        buyerReference: buyerReference,
        purchaseOrder: purchaseOrder,
        correctionReason: correctionReason,
      );
    }
    throw const JsonShapeException(
      'request_invoice_issue',
      'invoice_id',
      'String',
      'null',
    );
  }

  @override
  Future<List<Invoice>> fetchInvoices(String workspaceId) {
    fetched.add(workspaceId);
    return super.fetchInvoices(workspaceId);
  }
}

Future<void> _submitTheForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('invoice-create-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('invoice-member-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Flo').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('invoice-submit')));
  await tester.pumpAndSettle();
}

void main() {
  group('the issue form', () {
    testWidgets(
      'commit then a lost answer: one write, an unknown outcome instead '
      'of a success notice, and a look finds the ORIGINAL invoice',
      (tester) async {
        final money = _LostAnswer(commits: true);
        await pumpInvoices(tester, money: money);
        await _submitTheForm(tester);

        expect(money.writes, 1);
        expect(find.text('Outcome unknown'), findsOneWidget);
        expect(find.text('Invoice issued.'), findsNothing);
        expect(
          find.text('Something went wrong. Please try again.'),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const ValueKey('invoice-issue-check-again')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Outcome unknown'), findsNothing);
        expect(find.text('Invoice issued.'), findsOneWidget);
        expect(money.writes, 1, reason: 'a look never writes');
        expect(
          money.invoices,
          hasLength(1),
          reason: 'the archive holds the one original invoice',
        );
        expect(money.fetched, everyElement('ws-1'));
      },
    );

    testWidgets('a request that never committed: repeated checks stay explicit '
        'about not finding it, never resend, and never claim success', (
      tester,
    ) async {
      final money = _LostAnswer(commits: false);
      await pumpInvoices(tester, money: money);
      await _submitTheForm(tester);
      expect(money.writes, 1);

      for (var i = 0; i < 3; i++) {
        await tester.tap(
          find.byKey(const ValueKey('invoice-issue-check-again')),
        );
        await tester.pumpAndSettle();
      }

      expect(money.writes, 1, reason: 'checking is a read, never a new write');
      expect(money.invoices, isEmpty);
      expect(find.text('Outcome unknown'), findsOneWidget);
      expect(find.textContaining('Not found yet'), findsOneWidget);
      expect(find.text('Invoice issued.'), findsNothing);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Outcome unknown'), findsNothing);
      expect(find.text('Invoice issued.'), findsNothing);
      expect(money.writes, 1);
    });
  });

  group('InvoiceIssuance', () {
    const attempt = InvoiceIssueAttempt(
      workspaceId: 'ws-captured',
      memberId: 'member-1',
      period: '2026-09',
      buyerReference: 'PO-7',
    );

    test(
      'sends once; a decode error is unknown, a pending answer is held',
      () async {
        final commands = _ScriptedCommands(
          const JsonShapeException(
            'request_invoice_issue',
            'invoice_id',
            'String',
            'null',
          ),
        );
        final issuance = InvoiceIssuance(commands, _Archive(const []));

        final outcome = await issuance.issue(attempt);

        expect(outcome, isA<InvoiceIssueUnknown>());
        expect(commands.calls, 1);
        expect(
          commands.last?.buyerReference,
          'PO-7',
          reason: 'the draft travels with the attempt',
        );

        final held = await InvoiceIssuance(
          _ScriptedCommands(const PendingValidationException('evt-1')),
          _Archive(const []),
        ).issue(attempt);
        expect(held, isA<InvoiceIssueHeld>());
        expect((held as InvoiceIssueHeld).eventId, 'evt-1');
      },
    );

    test(
      'a refusal from the function is refused; a gateway status is not',
      () async {
        final refused = await InvoiceIssuance(
          _ScriptedCommands(
            const PostgrestException(
              message: 'already invoiced',
              code: 'P0001',
            ),
          ),
          _Archive(const []),
        ).issue(attempt);
        expect(refused, isA<InvoiceIssueRefused>());

        final gateway = await InvoiceIssuance(
          _ScriptedCommands(
            const PostgrestException(message: 'timeout', code: '504'),
          ),
          _Archive(const []),
        ).issue(attempt);
        expect(gateway, isA<InvoiceIssueUnknown>());
      },
    );

    test('the look reads the CAPTURED workspace and matches the original '
        'invoice, not another member, month or a voided one', () async {
      final archive = _Archive([
        _invoice('other-ws', workspaceId: 'ws-other'),
        _invoice('other-month', period: '2026-08'),
        _invoice('voided', voided: true),
        _invoice('original'),
      ]);
      final unknown = InvoiceIssueUnknown(attempt, StateError('lost'));

      final found = await InvoiceIssuance(
        _ScriptedCommands(null),
        archive,
      ).look(unknown);

      expect(archive.asked, ['ws-captured']);
      expect((found as InvoiceIssued).invoiceId, 'original');
    });

    test('a look that finds nothing, or cannot read, stays unknown', () async {
      final unknown = InvoiceIssueUnknown(attempt, StateError('lost'));
      final empty = await InvoiceIssuance(
        _ScriptedCommands(null),
        _Archive([_invoice('x', period: '2026-01')]),
      ).look(unknown);
      expect(empty, same(unknown));

      final denied = await InvoiceIssuance(
        _ScriptedCommands(null),
        _Archive(const [], failWith: StateError('denied')),
      ).look(unknown);
      expect(denied, isA<InvoiceIssueUnknown>());
    });
  });
}

Invoice _invoice(
  String id, {
  String workspaceId = 'ws-captured',
  String period = '2026-09',
  bool voided = false,
}) => Invoice(
  id: id,
  workspaceId: workspaceId,
  memberId: 'member-1',
  number: 'INV-$id',
  issuedAt: DateTime.utc(2026, 10),
  period: period,
  title: period,
  lines: const [],
  totalCents: 1000,
  currency: 'EUR',
  memberName: 'Flo',
  memberAddress: '',
  workspaceName: 'Space',
  workspaceAddress: '',
  issuerName: 'Owner',
  signature: 'sig',
  voidedAt: voided ? DateTime.utc(2026, 10, 2) : null,
);

class _ScriptedCommands implements InvoiceCommands {
  _ScriptedCommands(this.error);
  final Object? error;
  int calls = 0;
  ({String buyerReference})? last;

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
  }) async {
    calls++;
    last = (buyerReference: buyerReference);
    if (error != null) Error.throwWithStackTrace(error!, StackTrace.current);
    return 'inv-new';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Archive implements InvoiceQueries {
  _Archive(this.invoices, {this.failWith});
  final List<Invoice> invoices;
  final Object? failWith;
  final asked = <String>[];

  @override
  Future<List<Invoice>> fetchInvoices(String workspaceId) async {
    asked.add(workspaceId);
    if (failWith != null) {
      Error.throwWithStackTrace(failWith!, StackTrace.current);
    }
    return invoices;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
