// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2385 — the accounting, audit and e-invoice files are legally
// consequential, so moving their money, date, percent and CSV-cell
// helpers into lib/core must not change one byte of what they write.
// `accounting_standards_test` and the e-invoice checks hold the
// semantics; these goldens hold the bytes.
//
// The goldens under goldens/exports/ were written by the builders as
// they stood BEFORE the helpers moved, from this very fixture. The
// fixture carries the awkward cases on purpose: quotes, a line break and
// a semicolon in a title, a comma in a name, a fractional rate (5.5 and
// 2.1), a credit note and a voided document. Regenerate ONLY when a file
// is meant to change:
//
//   flutter test test/features/money/export_bytes_golden_test.dart \
//       --dart-define=WRITE_GOLDEN=true
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/money/domain/accountant_csv.dart';
import 'package:deskilo/features/money/domain/archive_bundle.dart';
import 'package:deskilo/features/money/domain/audit_trail.dart';
import 'package:deskilo/features/money/domain/datev.dart';
import 'package:deskilo/features/money/domain/einvoice_input.dart';
import 'package:deskilo/features/money/domain/fec.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_cii.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/invoice_ubl.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/saf_t.dart';
import 'package:deskilo/features/money/domain/sage.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/vat_report.dart';
import 'package:flutter_test/flutter_test.dart';

const _write = bool.fromEnvironment('WRITE_GOLDEN');
const _dir = 'test/features/money/goldens/exports';

Invoice _invoice({
  required String id,
  required String number,
  required DateTime issuedAt,
  required String title,
  required String memberName,
  required List<InvoiceLine> lines,
  required List<InvoiceVatTotal> vat,
  DateTime? voidedAt,
  String replacesNumber = '',
}) => Invoice(
  id: id,
  workspaceId: 'ws-1',
  memberId: 'm-$id',
  number: number,
  issuedAt: issuedAt,
  period: '2026-03',
  title: title,
  lines: lines,
  totalCents: lines.fold(0, (sum, line) => sum + line.amountCents),
  currency: 'EUR',
  memberName: memberName,
  memberAddress: '1 Rue Test, 34120 Pézenas',
  workspaceName: 'Pézenas "Lab"',
  workspaceAddress: '2 Place du Marché',
  issuerName: 'Owner, Ops',
  signature: '',
  voidedAt: voidedAt,
  voidedByName: voidedAt == null ? '' : 'Auditor',
  replacesNumber: replacesNumber,
  vatTotals: vat,
);

final _invoices = [
  _invoice(
    id: 'i1',
    number: 'INV-2026-0001',
    issuedAt: DateTime.utc(2026, 3, 4, 10),
    title: 'Coworking "March"\nsecond line; part',
    memberName: 'Müller, Ana "AM"',
    lines: const [
      InvoiceLine(label: 'Desk', amountCents: 12000, vatPercent: 20),
      InvoiceLine(
        kind: 'service',
        label: 'Coffee',
        quantity: 5,
        amountCents: 1055,
        vatPercent: 5.5,
      ),
    ],
    vat: const [
      InvoiceVatTotal(
        percent: 20,
        category: 'S',
        grossCents: 12000,
        netCents: 10000,
        vatCents: 2000,
      ),
      InvoiceVatTotal(
        percent: 5.5,
        category: 'S',
        grossCents: 1055,
        netCents: 1000,
        vatCents: 55,
      ),
    ],
  ),
  _invoice(
    id: 'i2',
    number: 'INV-2026-0002',
    issuedAt: DateTime.utc(2026, 3, 20, 15, 30),
    title: 'Credit note',
    memberName: 'Müller, Ana "AM"',
    replacesNumber: 'INV-2026-0001',
    lines: const [
      InvoiceLine(label: 'Desk', amountCents: -3000, vatPercent: 20),
    ],
    vat: const [
      InvoiceVatTotal(
        percent: 20,
        category: 'S',
        grossCents: -3000,
        netCents: -2500,
        vatCents: -500,
      ),
    ],
  ),
  _invoice(
    id: 'i3',
    number: 'INV-2026-0003',
    issuedAt: DateTime.utc(2026, 3, 28, 8, 5),
    title: 'Press',
    memberName: 'Bob',
    voidedAt: DateTime.utc(2026, 3, 29, 9),
    lines: const [
      InvoiceLine(label: 'Paper', amountCents: 5000, vatPercent: 2.1),
    ],
    vat: const [
      InvoiceVatTotal(
        percent: 2.1,
        category: 'S',
        grossCents: 5000,
        netCents: 4897,
        vatCents: 103,
      ),
    ],
  ),
];

final _matches = {
  'i1': InvoiceMatch(
    invoiceId: 'i1',
    paidCents: 13055,
    resolution: 'exact',
    matchedAt: DateTime.utc(2026, 4, 2, 11),
  ),
};

const _seller = InvoiceParty(
  name: 'Space SAS',
  street: '2 Place du Marché',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
  vatId: 'FR12812345678',
  legalId: '812345678',
  vatRegime: 'vat_registered',
);

const _buyer = InvoiceParty(
  name: 'Müller, Ana "AM"',
  street: '1 Rue Test',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
);

String _lineText(InvoiceLine line) =>
    invoiceLineText(const ReportStrings(), line);

Map<String, String Function()> _files() => {
  'fec.txt': () => buildFecFile(FecRequest(
    invoices: _invoices,
    matches: _matches,
    company: _seller,
    accounts: const FecAccounts(),
    lineText: _lineText,
  )),
  'datev.csv': () => buildDatevFile(
    invoices: _invoices,
    matches: _matches,
    accounts: const DatevAccounts(),
    from: DateTime.utc(2026),
    to: DateTime.utc(2026, 12, 31),
    generatedAt: DateTime.utc(2026, 5, 1, 9, 7, 3),
    consultantNumber: '1234567',
    clientNumber: '54321',
  ),
  'sage.csv': () => buildSageFile(
    invoices: _invoices,
    matches: _matches,
    accounts: const SageAccounts(),
    customerRef: (invoice) => invoice.memberName,
  ),
  'accountant.csv': () => buildAccountantCsv(
    invoices: _invoices,
    matches: _matches,
    generatedAt: DateTime.utc(2026, 5, 1, 9),
    workspaceName: 'Pézenas "Lab"',
  ),
  'audit_trail.csv': () => buildAuditTrailCsv(
    events: buildAuditEvents(invoices: _invoices, matches: _matches),
    generatedAt: DateTime.utc(2026, 5, 1, 9),
    workspaceName: 'Pézenas Lab',
  ),
  'saf_t.xml': () => buildSafTFile(SafTRequest(
    invoices: _invoices,
    matches: _matches,
    company: _seller,
    currency: 'EUR',
    softwareVersion: '1.0.0',
    createdAt: DateTime.utc(2026, 5, 1, 9),
    lineText: _lineText,
  )),
  'invoice_ubl.xml': () => buildInvoiceUbl(EInvoiceInput(invoice: _invoices.first,
    seller: _seller,
    buyer: _buyer,
    lineText: _lineText,
    iban: 'FR7630006000011234567890189')),
  'invoice_cii.xml': () => buildInvoiceCii(EInvoiceInput(invoice: _invoices.first,
    seller: _seller,
    buyer: _buyer,
    lineText: _lineText,
    iban: 'FR7630006000011234567890189',
    dueDate: DateTime.utc(2026, 4, 3))),
  'vat_report.csv': () => vatReportCsv(
    buildVatReport(
      _invoices,
      start: DateTime.utc(2026, 3),
      end: DateTime.utc(2026, 4),
      zeroCategory: 'O',
    ),
    currency: 'EUR',
  ),
  'invoice_register.csv': () =>
      buildInvoiceRegisterCsv(_invoices, integrity: const {'i1': 'ok'}),
};

void main() {
  setUp(() => WorkspaceTime.install('Europe/Paris'));
  tearDown(WorkspaceTime.reset);

  for (final MapEntry(key: name, value: build) in _files().entries) {
    test('$name is byte-identical to its golden', () {
      final file = File('$_dir/$name');
      // Bytes, not a decoded string: a decoder drops DATEV's BOM.
      final bytes = utf8.encode(build());
      if (_write) {
        file
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes);
      }
      expect(bytes, file.readAsBytesSync());
    });
  }
}
