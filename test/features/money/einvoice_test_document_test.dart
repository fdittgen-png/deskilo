// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3883 — the sandbox test document: its number is outside the invoice
// sequence and its own; the function's answers read as where the latest test
// stands and why a send did not leave.
import 'package:deskilo/features/money/domain/einvoice_test_document.dart';
import 'package:deskilo/features/money/presentation/einvoice_test_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a test number carries the test mark and the time it was built', () {
    final number = einvoiceTestNumber(DateTime(2026, 11, 13, 23, 30, 5));
    expect(number, '${einvoiceTestNumberPrefix}20261113233005');
    expect(
      einvoiceTestNumber(DateTime(2026, 11, 13, 23, 30, 6)),
      isNot(number),
      reason: 'each test has its own number',
    );
  });

  group('where the latest test stands', () {
    EInvoiceTestState of(Map<String, Object?> test) =>
        EInvoiceTestState.fromWire({'available': true, 'test': test});

    test('none, while no test was sent', () {
      final state = EInvoiceTestState.fromWire({
        'available': true,
        'test': null,
      });
      expect(state.verdict, EInvoiceTestVerdict.none);
      expect(state.canSend, isTrue);
    });

    test('awaiting, while the platform has not answered', () {
      final state = of({
        'transmission_id': 't-1',
        'phase': 'accepted',
        'document_status': 'unknown',
      });
      expect(state.verdict, EInvoiceTestVerdict.awaiting);
      expect(state.transmissionId, 't-1');
      expect(state.canSend, isFalse, reason: 'one test at a time');
      expect(
        of({'phase': 'uncertain', 'document_status': 'unknown'}).verdict,
        EInvoiceTestVerdict.awaiting,
      );
    });

    test('accepted or rejected, as the platform said', () {
      expect(
        of({'phase': 'accepted', 'document_status': 'accepted'}).verdict,
        EInvoiceTestVerdict.accepted,
      );
      expect(
        of({'phase': 'accepted', 'document_status': 'rejected'}).verdict,
        EInvoiceTestVerdict.rejected,
      );
      expect(
        of({'phase': 'failed', 'document_status': 'unknown'}).verdict,
        EInvoiceTestVerdict.rejected,
        reason: 'an upload that did not land can be sent again',
      );
    });

    test('unavailable where the channel takes no test', () {
      final state = EInvoiceTestState.fromWire({'available': false});
      expect(state.available, isFalse);
      expect(state.canSend, isFalse);
    });
  });

  test('why a send did not leave', () {
    expect(EInvoiceTestRefusal.fromWire(null), EInvoiceTestRefusal.none);
    expect(
      EInvoiceTestRefusal.fromWire('test_pending'),
      EInvoiceTestRefusal.pending,
    );
    expect(
      EInvoiceTestRefusal.fromWire('sandbox_credentials_missing'),
      EInvoiceTestRefusal.sandboxMissing,
    );
    expect(
      EInvoiceTestRefusal.fromWire('sandbox_not_documented'),
      EInvoiceTestRefusal.sandboxNotDocumented,
    );
    expect(
      EInvoiceTestRefusal.fromWire('test_unavailable'),
      EInvoiceTestRefusal.unavailable,
    );
    expect(
      EInvoiceTestRefusal.fromWire('something new'),
      EInvoiceTestRefusal.failed,
    );
  });
}
