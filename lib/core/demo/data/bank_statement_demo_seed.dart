// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../../features/money/domain/bank/bank_file.dart';
import '../../../features/money/domain/bank/bank_match.dart';
import '../../../features/money/domain/bank/bank_records.dart';
import '../../../features/money/domain/bank/bank_statement.dart';
import 'bank_reconciliation_fixture.dart';
import 'bank_statement_repository.dart';
import 'money_repository.dart';

/// The demo's account at its bank (a valid Swiss IBAN of the demo).
const _demoAccount = 'CH9300762011623852957';

/// The demo space's last statement: two open invoices paid with the
/// references printed on them (the QR reference and the RF creditor
/// reference), one transfer whose payer gave neither, and the bank's
/// monthly fee going out.
FakeBankStatementRepository seedDemoBankStatements(
  FakeMoneyRepository money,
  DateTime today,
) {
  final repo = FakeBankStatementRepository(money: money, today: today);
  final open = openInvoices(
    money.invoices.where((i) => i.workspaceId == 'ws-1'),
    money.invoiceMatchesStore,
  )..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
  final day = DateTime.utc(today.year, today.month, today.day);
  final currency = open.isEmpty ? 'EUR' : open.first.currency;
  BankLine line(
    int n,
    int cents, {
    String reference = '',
    String text = '',
    String payer = '',
  }) => BankLine(
    position: n,
    bookingDate: day,
    valueDate: day,
    amountCents: cents,
    currency: currency,
    transactionId: 'DEMO-$n',
    counterpartyName: payer,
    reference: reference,
    remittance: text,
  );
  // A QR reference keeps only the number's digits, so two numbers that
  // differ by their letters share one; the demo pays an invoice whose
  // reference is its own.
  String? qrr(OpenInvoice i) => i.frozenQrr ?? qrrReferenceOf(i.number);
  final byQr = open
      .where(
        (i) =>
            qrr(i) != null && open.where((o) => qrr(o) == qrr(i)).length == 1,
      )
      .firstOrNull;
  final byRf = open
      .where((i) => i != byQr && scorReferenceOf(i.number) != null)
      .firstOrNull;
  final lines = <BankLine>[
    if (byQr != null)
      line(1, byQr.dueCents, reference: qrr(byQr)!, payer: byQr.memberName),
    if (byRf != null)
      line(
        2,
        byRf.dueCents,
        reference: scorReferenceOf(byRf.number)!,
        payer: byRf.memberName,
      ),
    line(3, 4200, text: 'Thanks for the coffee corner', payer: 'Studio Lumen'),
    line(4, -1500, text: 'Reimbursement REIMB-1', payer: 'Studio Lumen'),
  ];
  // A reimbursement reported as made, which the movement out reconciles.
  repo.reportedPayments.add((
    payment: OutgoingCandidate(
      id: 'demo-outgoing-1',
      amountCents: 1500,
      paidOn: day,
      reference: 'REIMB-1',
      payee: 'Studio Lumen',
    ),
    currency: currency,
  ));
  final statement = BankStatement(
    format: BankFileFormat.camt054,
    account: _demoAccount,
    currency: currency,
    statementId: 'DEMO-NTFCTN-1',
    lines: lines,
  );
  // The seed is the import of one file, by the same rules as any other.
  repo.seedStatement(
    statement,
    sha256.convert(utf8.encode('demo-statement')).toString(),
    'demo-camt054.xml',
  );
  // Synthetic report source; these balances are fixture facts.
  final reportBytes = utf8.encode(demoReconciliationStatementXml);
  final reportDigest = sha256.convert(reportBytes).toString();
  final reportStatement = parseBankFile(
    reportBytes,
    format: BankFileFormat.camt053,
    limits: const BankFileLimits(maxBytes: 100000, maxLines: 100),
  );
  repo.originals['ws-1/$reportDigest'] = Uint8List.fromList(reportBytes);
  repo.seedStatement(reportStatement, reportDigest, 'demo-report-camt053.xml');
  return repo;
}
