// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3335 — an e-invoice submission can be unsettled: prepared, in flight, or
// uncertain after a lost answer. The client reads the server's `phase` when
// it sends one, never calls an unknown phase a failure that invites a resend,
// and a deployed OLDER client (pinned below) still decodes the same rows
// without reading them as accepted.

import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

/// The previous supported client's decoder, copied from
/// `lib/features/money/domain/einvoice_gateway.dart` at c352b2cf3: an unknown
/// `status` is a failure. It reads the legacy `status` column only.
String oldClientStatus(Map<String, dynamic> row) {
  const known = ['accepted', 'rejected', 'failed'];
  return known.firstWhere((s) => s == row['status'], orElse: () => 'failed');
}

Map<String, dynamic> row({
  required String status,
  String? phase,
  String detail = '',
}) => {
  'invoice_id': 'inv',
  'status': status,
  'phase': ?phase,
  'sent_at': '2026-11-06T10:00:00Z',
  'detail': detail,
};

void main() {
  test('the phase is read when the server sends one', () {
    const table = {
      'prepared': EInvoiceSubmissionStatus.inProgress,
      'sent': EInvoiceSubmissionStatus.inProgress,
      'uncertain': EInvoiceSubmissionStatus.uncertain,
      'accepted': EInvoiceSubmissionStatus.accepted,
      'rejected': EInvoiceSubmissionStatus.rejected,
      'failed': EInvoiceSubmissionStatus.failed,
    };
    table.forEach((phase, expected) {
      expect(
        InvoiceTransmission.fromRow(row(status: 'failed', phase: phase)).status,
        expected,
        reason: phase,
      );
    });
  });

  test('an older server sends the legacy status only', () {
    expect(
      InvoiceTransmission.fromRow(row(status: 'accepted')).status,
      EInvoiceSubmissionStatus.accepted,
    );
    expect(
      InvoiceTransmission.fromRow(row(status: 'rejected')).status,
      EInvoiceSubmissionStatus.rejected,
    );
    expect(
      InvoiceTransmission.fromRow(row(status: 'failed')).status,
      EInvoiceSubmissionStatus.failed,
    );
  });

  test('a phase this client does not know is uncertain, not a failure that invites a resend', () {
    final read = InvoiceTransmission.fromRow(
      row(status: 'failed', phase: 'quarantined'),
    );
    expect(read.status, EInvoiceSubmissionStatus.uncertain);
    expect(read.isUnresolved, isTrue);
    expect(read.accepted, isFalse);
  });

  test('only a settled failure is retryable; unresolved phases are not', () {
    expect(EInvoiceSubmissionStatus.failed.isUnresolved, isFalse);
    expect(EInvoiceSubmissionStatus.inProgress.isUnresolved, isTrue);
    expect(EInvoiceSubmissionStatus.uncertain.isUnresolved, isTrue);
  });

  test('O13: the pinned previous client reads an unresolved row as a failure that says not to resend, never as accepted', () {
    const detail = 'In progress or unresolved - do not resend';
    for (final phase in ['prepared', 'sent', 'uncertain']) {
      // what the 0689 trigger leaves in the legacy column for these phases
      final wire = row(status: 'failed', phase: phase, detail: detail);
      expect(oldClientStatus(wire), 'failed', reason: phase);
      expect(wire['detail'], contains('do not resend'));
      // the new client reads the same row as unresolved
      expect(
        InvoiceTransmission.fromRow(wire).isUnresolved,
        isTrue,
        reason: phase,
      );
    }
  });

  test('a submission answer carries its phase to the new client and its status to the old one', () {
    expect(
      EInvoiceSubmissionStatus.fromWire(phase: 'uncertain', status: 'failed'),
      EInvoiceSubmissionStatus.uncertain,
    );
    expect(
      EInvoiceSubmissionStatus.fromWire(status: 'failed'),
      EInvoiceSubmissionStatus.failed,
    );
    expect(
      EInvoiceSubmissionStatus.fromWire(),
      EInvoiceSubmissionStatus.failed,
    );
  });
}
