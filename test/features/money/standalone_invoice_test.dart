// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4165 (A2) -- the standalone invoice as the application holds it: the
// server's answers decoded exactly, and an issue sent ONCE whose lost answer
// is looked up by the attempt's own request id in the attempt's own workspace.
import 'package:deskilo/core/failure/app_failure.dart';
import 'package:deskilo/features/money/application/issue_standalone_invoice.dart';
import 'package:deskilo/features/money/domain/previewed_document.dart';
import 'package:deskilo/features/money/domain/standalone_invoice.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';

class _Commands implements StandaloneInvoiceCommands {
  final List<String> sent = [];
  Object? failWith;

  @override
  Future<StandaloneIssued> issue({
    required String workspaceId,
    required String draftId,
    required int revision,
    required String requestId,
  }) async {
    sent.add('$workspaceId|$draftId|$revision|$requestId');
    final e = failWith;
    if (e != null) Error.throwWithStackTrace(e, StackTrace.current);
    return const StandaloneIssued(invoiceId: 'inv-1', number: 'F-0001', replayed: false);
  }

  @override
  Future<StandaloneSaved> saveDraft({required String workspaceId, required StandaloneDraft draft}) =>
      throw UnimplementedError();

  @override
  Future<PreviewedDocument> preview({
    required String workspaceId,
    required String draftId,
    required int revision,
  }) => throw UnimplementedError();
}

const _attempt = StandaloneIssueAttempt(
  workspaceId: 'ws-1',
  draftId: 'd-1',
  revision: 3,
  requestId: 'req-1',
);

void main() {
  late FakeMoneyRepository repo;
  late _Commands commands;
  late StandaloneIssuance issuance;

  setUp(() {
    repo = FakeMoneyRepository();
    commands = _Commands();
    issuance = StandaloneIssuance(commands, repo);
  });

  group('issuing once', () {
    test('the confirmed revision is sent under its request id, and the invoice is the answer', () async {
      final out = await issuance.issue(_attempt);
      expect(out, isA<CommandDone<StandaloneIssued>>());
      final issued = (out as CommandDone<StandaloneIssued>).value;
      expect(issued.invoiceId, 'inv-1');
      expect(issued.number, 'F-0001');
      expect(commands.sent, ['ws-1|d-1|3|req-1']);
    });

    test('a refusal in the server\'s words is a refusal, sent once', () async {
      commands.failWith = StateError('refused');
      final out = await issuance.issue(_attempt);
      expect(out, isA<CommandRefused<StandaloneIssued>>());
      expect(commands.sent, hasLength(1));
    });

    test('a lost answer is unknown, never refused, and nothing is resent', () async {
      commands.failWith = const JsonShapeException('rpc', 'invoice_id', 'String', 'null');
      final out = await issuance.issue(_attempt);
      expect(out, isA<CommandUnreached<StandaloneIssued>>());
      expect(commands.sent, hasLength(1));
    });
  });

  group('looking for the answer', () {
    Future<CommandUnreached<StandaloneIssued>> lost() async {
      commands.failWith = const JsonShapeException('rpc', 'invoice_id', 'String', 'null');
      return (await issuance.issue(_attempt)) as CommandUnreached<StandaloneIssued>;
    }

    test('no receipt is only "not observed": the attempt stays unknown', () async {
      final unknown = await lost();
      expect(await issuance.look(_attempt, unknown), same(unknown));
      expect(commands.sent, hasLength(1), reason: 'looking never writes');
    });

    test('the receipt of THAT request, in the attempt\'s own workspace, is the invoice', () async {
      final unknown = await lost();
      repo.invoiceReceipts['ws-1|req-1'] = 'inv-9';
      final out = await issuance.look(_attempt, unknown);
      expect(out, isA<CommandDone<StandaloneIssued>>());
      final issued = (out as CommandDone<StandaloneIssued>).value;
      expect(issued.invoiceId, 'inv-9');
      expect(issued.number, isNull, reason: 'a receipt does not carry the number; none is made up');
      expect(issued.replayed, isTrue);
    });

    test('another workspace\'s receipt for the same request id is not this attempt\'s', () async {
      final unknown = await lost();
      repo.invoiceReceipts['ws-2|req-1'] = 'inv-other';
      expect(await issuance.look(_attempt, unknown), same(unknown));
    });
  });

  group('what the server answers is read exactly', () {
    test('a saved draft keeps its identity, revision and each line\'s own identity', () {
      final saved = StandaloneSaved.fromJson({
        'draft_id': 'd-1',
        'revision': 2,
        'lines': [
          {
            'line_id': 'l-1',
            'description': 'Consulting',
            'quantity': '1.5',
            'unit': {'code': 'hour', 'label': 'h', 'un_ece_code': 'HUR'},
            'unit_price': '80',
            'basis': 'net',
            'base_quantity': '1',
            'supply': 'general',
          },
        ],
      });
      expect([saved.draftId, saved.revision], ['d-1', 2]);
      expect(saved.lines.single.lineId, 'l-1');
      expect(saved.lines.single.quantity, '1.5');
      expect(saved.lines.single.unEceCode, 'HUR');
    });

    test('a line goes back to the server as text, with its identity', () {
      const line = StandaloneLine(
        lineId: 'l-1',
        description: 'Lesson',
        quantity: '0.750000',
        unitCode: 'kg',
        unitLabel: 'kg',
        unitPrice: '12.50',
        grossPrice: true,
        vatRateId: 'rate-1',
      );
      expect(line.toWire(), {
        'line_id': 'l-1',
        'description': 'Lesson',
        'quantity': '0.750000',
        'unit': {'code': 'kg', 'label': 'kg', 'un_ece_code': ''},
        'unit_price': '12.50',
        'basis': 'gross',
        'base_quantity': '1',
        'supply': 'general',
        'vat_rate_id': 'rate-1',
      });
      expect(StandaloneLine.fromJson(JsonReader.of(line.toWire())).toWire(), line.toWire());
    });

    test('a preview names what is missing, and is never partial', () {
      final p = PreviewedDocument.fromJson({
        'missing': ['line_1_quantity', 'due_on'],
        'preview': null,
      });
      expect(p.missing, ['line_1_quantity', 'due_on']);
      expect(p.ready, isFalse);
      expect(p.lines, isEmpty);
    });

    test('a preview that can be issued carries the server\'s lines, exact quantities and totals', () {
      final p = PreviewedDocument.fromJson({
        'missing': <Object?>[],
        'preview': {
          'total_cents': 14400,
          'currency': 'EUR',
          'lines': [
            {
              'kind': 'service',
              'label': 'Consulting',
              'quantity': 1,
              'amount_cents': 14400,
              'vat_percent': 20,
              'commercial': {
                'version': 1,
                'line_id': 'l-1',
                'quantity': '1.5',
                'unit': {'code': 'hour', 'un_ece_code': 'HUR', 'label': 'h'},
                'unit_price': {'amount': '80', 'currency': 'EUR', 'basis': 'net', 'base_quantity': '1'},
                'supply': 'general',
                'tax_facts': <String, Object?>{},
                'amounts': {'currency': 'EUR', 'net_minor': '12000', 'tax_minor': '2400', 'gross_minor': '14400'},
              },
            },
          ],
          'vat_totals': [
            {'percent': 20, 'category': 'S', 'gross_cents': 14400, 'net_cents': 12000, 'vat_cents': 2400},
          ],
        },
      });
      expect(p.ready, isTrue);
      expect(p.totalCents, 14400);
      expect(p.vatTotals.single.netCents, 12000);
      expect(p.lines.single.quantityText, '1.5');
      expect(p.lines.single.exactFacts?.amounts.netMinor, 12000);
    });
  });
}
