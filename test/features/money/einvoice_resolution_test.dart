// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3335 — settling an `uncertain` e-invoice submission by hand: the rules the
// form applies before it asks, and the Demo repository mirroring the server
// (only an uncertain submission settles; a second resolution changes nothing).

import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';

FakeMoneyRepository _withUncertain() {
  final money = FakeMoneyRepository();
  money.transmissions['inv-1'] = InvoiceTransmission(
    id: 't-1',
    invoiceId: 'inv-1',
    status: EInvoiceSubmissionStatus.uncertain,
    sentAt: DateTime(2026, 11, 2, 9),
  );
  return money;
}

void main() {
  group('the rules before it asks', () {
    test('a reason and the evidence are both required, the reason first', () {
      expect(
        einvoiceResolutionProblem(reason: ' ', evidence: ''),
        EInvoiceResolutionProblem.reason,
      );
      expect(
        einvoiceResolutionProblem(reason: 'portal shows it', evidence: '  '),
        EInvoiceResolutionProblem.evidence,
      );
      expect(
        einvoiceResolutionProblem(reason: 'portal shows it', evidence: 'ref 1'),
        isNull,
      );
    });
  });

  group('the Demo repository mirrors the server', () {
    Future<EInvoiceResolveResult> resolve(
      FakeMoneyRepository money,
      EInvoiceResolution resolution, {
      String reason = 'portal shows it',
      String evidence = 'ref 1',
    }) => money.resolveEInvoiceTransmission(
      workspaceId: 'ws-1',
      transmissionId: 't-1',
      resolution: resolution,
      reason: reason,
      evidence: evidence,
    );

    test('each outcome settles the uncertain submission', () async {
      for (final (resolution, status) in [
        (EInvoiceResolution.accepted, EInvoiceSubmissionStatus.accepted),
        (EInvoiceResolution.rejected, EInvoiceSubmissionStatus.rejected),
        (EInvoiceResolution.failed, EInvoiceSubmissionStatus.failed),
      ]) {
        final money = _withUncertain();
        final result = await resolve(money, resolution);
        expect(result.resolved, isTrue, reason: resolution.name);
        expect(money.transmissions['inv-1']!.status, status);
      }
    });

    test('refused without a reason or evidence: nothing changes', () async {
      final money = _withUncertain();
      final result = await resolve(money, EInvoiceResolution.accepted,
          evidence: ' ');
      expect(result.resolved, isFalse);
      expect(money.transmissions['inv-1']!.status,
          EInvoiceSubmissionStatus.uncertain);
    });

    test('a second resolution changes nothing', () async {
      final money = _withUncertain();
      await resolve(money, EInvoiceResolution.accepted);
      final again = await resolve(money, EInvoiceResolution.failed);
      expect(again.resolved, isFalse);
      expect(again.error, 'already_settled');
      expect(money.transmissions['inv-1']!.status,
          EInvoiceSubmissionStatus.accepted);
    });

    test('only an uncertain submission settles', () async {
      final money = FakeMoneyRepository();
      money.transmissions['inv-1'] = InvoiceTransmission(
        id: 't-1',
        invoiceId: 'inv-1',
        status: EInvoiceSubmissionStatus.accepted,
        sentAt: DateTime(2026, 11, 2, 9),
      );
      final result = await resolve(money, EInvoiceResolution.failed);
      expect(result.resolved, isFalse);
      expect(money.transmissions['inv-1']!.status,
          EInvoiceSubmissionStatus.accepted);
    });
  });
}
