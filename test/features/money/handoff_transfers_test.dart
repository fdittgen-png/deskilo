// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2378 item 2 — the digital link, evidenced: the handoff report beside the
// accountant CSV quotes the Transfers list of the year, the Sage file with
// its digest and the documents it carried and the Xero delivery of the same
// month with its own digest, as the server's `accounting_transfers_v1`
// answers them. With the accounting systems off there is no Transfers list
// and the report quotes none. Expectations by hand.
import 'dart:convert';

import 'package:deskilo/features/money/domain/accountant_csv.dart';
import 'package:deskilo/features/money/domain/accountant_handoff.dart';
import 'package:deskilo/features/money/domain/accounting_connection.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/presentation/widgets/accountant_handoff_preflight.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _sageSha =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _docSha =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _xeroSha =
    '3333333333333333333333333333333333333333333333333333333333333333';

Map<String, Object?> _delivery({
  required String id,
  required String target,
  required String sha,
  String? connection,
  String? bookExport,
  String status = 'acknowledged',
  String remoteNumber = '',
}) => {
  'id': id,
  'target_id': target,
  'connection_id': connection,
  'book_export_id': bookExport,
  'document_kind': 'invoice',
  'document_id': 'inv-1',
  'document_number': 'GB-2026-0001',
  'event_date': '2026-03-14',
  'payload_sha256': sha,
  'remote_number': remoteNumber,
  'status': status,
};

/// The server's answer for 2026: the Sage file of March, which carried the
/// March invoice, and the same invoice delivered to Xero.
final _transfers = AccountingTransfers.fromJson({
  'files': [
    {
      'id': 'exp-1',
      'format_id': 'sage50',
      'period_from': '2026-03-01',
      'period_to': '2026-03-31',
      'sha256': _sageSha,
      'document_count': 1,
      'closed_period': false,
      'exported_at': '2026-04-02T08:00:00Z',
      'exported_by_member_id': 'm-owner',
      'deliveries': [
        _delivery(
          id: 'd-1',
          target: 'sage50',
          sha: _docSha,
          bookExport: 'exp-1',
          status: 'generated',
        ),
      ],
    },
  ],
  'deliveries': [
    _delivery(
      id: 'd-2',
      target: 'xero',
      sha: _xeroSha,
      connection: 'c-1',
      remoteNumber: 'INV-0042',
    ),
  ],
});

Invoice _invoice() => Invoice(
  id: 'inv-1',
  workspaceId: 'ws',
  memberId: 'm-1',
  number: 'GB-2026-0001',
  issuedAt: DateTime.utc(2026, 3, 14, 9),
  title: 'Desk March',
  lines: const [InvoiceLine(label: 'Desk', amountCents: 12000)],
  totalCents: 12000,
  currency: 'GBP',
  memberName: 'Alex Sample',
  memberAddress: '',
  workspaceName: 'W',
  workspaceAddress: '',
  issuerName: 'Owner',
  signature: '',
);

AccountantHandoff _report({AccountingTransfers? transfers}) {
  final at = DateTime.utc(2026, 4, 3);
  final invoices = [_invoice()];
  final csv = buildAccountantCsv(
    invoices: invoices,
    matches: const {},
    generatedAt: at,
    workspaceName: 'Leeds',
  );
  return buildAccountantHandoff(
    invoices: invoices,
    matches: const {},
    csv: csv,
    generatedAt: at,
    transfers: transfers,
  );
}

Map<String, Object?> _json(AccountantHandoff r) =>
    jsonDecode(r.toPrettyJson()) as Map<String, Object?>;

void main() {
  test('the report quotes the Sage file with its digest and documents', () {
    final transfers =
        _json(_report(transfers: _transfers))['transfers']! as Map;
    expect(transfers['files'], [
      {
        'format_id': 'sage50',
        'period_from': '2026-03-01',
        'period_to': '2026-03-31',
        'exported_at': '2026-04-02T08:00:00.000Z',
        'sha256': _sageSha,
        'document_count': 1,
        'documents': [
          {
            'document_kind': 'invoice',
            'document_number': 'GB-2026-0001',
            'event_date': '2026-03-14',
            'sha256': _docSha,
          },
        ],
      },
    ]);
  });

  test('the report quotes the Xero delivery of the same month', () {
    final transfers =
        _json(_report(transfers: _transfers))['transfers']! as Map;
    expect(transfers['deliveries'], [
      {
        'target_id': 'xero',
        'document_kind': 'invoice',
        'document_number': 'GB-2026-0001',
        'event_date': '2026-03-14',
        'sha256': _xeroSha,
        'status': 'acknowledged',
        'remote_number': 'INV-0042',
      },
    ]);
  });

  test('the same transfers in another order give the same report', () {
    final reversed = AccountingTransfers(
      files: _transfers.files.reversed.toList(),
      deliveries: [
        AccountingDelivery.fromJson(
          _delivery(
            id: 'd-3',
            target: 'xero',
            sha: _xeroSha,
            connection: 'c-1',
          ),
        ),
        ..._transfers.deliveries,
      ],
    );
    final forward = AccountingTransfers(
      files: _transfers.files,
      deliveries: [
        ..._transfers.deliveries,
        AccountingDelivery.fromJson(
          _delivery(
            id: 'd-3',
            target: 'xero',
            sha: _xeroSha,
            connection: 'c-1',
          ),
        ),
      ],
    );
    expect(
      _report(transfers: reversed).toPrettyJson(),
      _report(transfers: forward).toPrettyJson(),
    );
  });

  test('without a Transfers list the report quotes none', () {
    expect(_json(_report()).containsKey('transfers'), isFalse);
  });

  Future<void> openPreflight(
    WidgetTester tester,
    AccountantHandoff report,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAccountantHandoffPreflight(context, report),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the preflight says the report quotes the transfers', (
    tester,
  ) async {
    await openPreflight(tester, _report(transfers: _transfers));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.handoffTransfersQuoted('1', '1')), findsOneWidget);
  });

  testWidgets('without a Transfers list the preflight says nothing of it', (
    tester,
  ) async {
    await openPreflight(tester, _report());
    expect(find.byKey(const ValueKey('handoff-preflight')), findsOneWidget);
    expect(find.byKey(const ValueKey('handoff-transfers')), findsNothing);
  });
}
