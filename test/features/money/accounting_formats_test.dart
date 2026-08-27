// SPDX-License-Identifier: 0BSD
//
// #669 — the accounting and Steuerberater exports.
//
// These files are legally consequential: a wrong one is a false
// statement to a tax authority and gets unbound by hand. So most of what
// is pinned below is not "does it produce output" but **what does it
// claim, and does the claim survive contact with a reader**.
//
// The first group exists because of a real bug: DATEV shipped in #673 as
// a domain file with NO call site and no test. It produced perfect files
// that nobody could ask for. A format that is not reachable is not
// shipped, and that is now a test rather than a hope.
import 'dart:io';

import 'package:deskilo/features/money/domain/accountant_csv.dart';
import 'package:deskilo/features/money/domain/accounting_format.dart';
import 'package:deskilo/features/money/domain/audit_trail.dart';
import 'package:deskilo/features/money/domain/datev.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/sage.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice inv({
  String id = 'i1',
  String number = 'INV-1',
  DateTime? issuedAt,
  int totalCents = 12000,
  List<InvoiceVatTotal> vat = const [],
  DateTime? voidedAt,
  String voidedByName = '',
  String memberName = 'Alex Sample',
}) =>
    Invoice(
      id: id,
      workspaceId: 'ws',
      memberId: 'm-1',
      number: number,
      issuedAt: issuedAt ?? DateTime(2026, 3, 14),
      title: 'Coworking March',
      lines: [
        InvoiceLine(label: 'Desk', amountCents: totalCents, vatPercent: 20),
      ],
      totalCents: totalCents,
      currency: 'EUR',
      memberName: memberName,
      memberAddress: '',
      workspaceName: 'Pézenas',
      workspaceAddress: '',
      issuerName: 'Owner',
      signature: '',
      voidedAt: voidedAt,
      voidedByName: voidedByName,
      vatTotals: vat,
    );

final _vat20 = [
  const InvoiceVatTotal(
    percent: 20,
    category: 'S',
    grossCents: 12000,
    netCents: 10000,
    vatCents: 2000,
  ),
];

InvoiceMatch match({
  int paidCents = 12000,
  String status = 'confirmed',
  DateTime? at,
}) =>
    InvoiceMatch(
      invoiceId: 'i1',
      paidCents: paidCents,
      resolution: 'paid',
      status: status,
      matchedAt: at ?? DateTime(2026, 4, 2),
    );

void main() {
  group('every format is REACHABLE — the #673 lesson', () {
    // DATEV was built, committed, and called by nothing. It is easy to
    // repeat: a domain file compiles and its tests pass whether or not
    // anything invokes it.
    final export =
        File('lib/features/money/presentation/accounting_export.dart')
            .readAsStringSync();

    test('the export switch handles every registry format', () {
      for (final format in accountingFormats) {
        expect(export, contains("case '${format.id}':"),
            reason: '${format.id} is in the registry but nothing exports '
                'it — that is how DATEV shipped as dead code');
      }
    });

    test('every format has a builder wired to it', () {
      for (final entry in {
        'fec': 'buildFecFile',
        'saft': 'buildSafTFile',
        'saft_pt': 'buildSafTFile',
        'datev': 'buildDatevFile',
        'sage50': 'buildSageFile',
        'accountant_csv': 'buildAccountantCsv',
        'audit_trail': 'buildAuditTrailCsv',
      }.entries) {
        expect(export, contains(entry.value),
            reason: '${entry.key} names no builder');
      }
    });

    test('the sheet renders a row per format, keyed by its id', () {
      final sheet = File('lib/features/money/presentation/widgets/'
              'accounting_export_sheet.dart')
          .readAsStringSync();
      expect(sheet, contains("ValueKey('accounting-export-\${format.id}')"),
          reason: 'keying off the registry is what keeps the sheet and '
              'the switch from drifting apart');
    });
  });

  group('a country is offered what it can actually use', () {
    test('France gets the FEC, Germany does not', () {
      expect(formatsFor('FR').map((f) => f.id), contains('fec'));
      expect(formatsFor('DE').map((f) => f.id), isNot(contains('fec')));
    });

    test('Germany and Austria get DATEV; Switzerland does NOT', () {
      // DATEV is a German-market product. A Swiss fiduciary does not run
      // it, and offering it there is a dead end dressed as a feature.
      expect(formatsFor('DE').map((f) => f.id), contains('datev'));
      expect(formatsFor('AT').map((f) => f.id), contains('datev'));
      expect(formatsFor('CH').map((f) => f.id), isNot(contains('datev')));
    });

    test('Portugal gets its own SAF-T', () {
      expect(formatsFor('PT').map((f) => f.id), contains('saft_pt'));
      expect(formatsFor('FR').map((f) => f.id), isNot(contains('saft_pt')));
    });

    test('every supported country gets at least one usable export', () {
      // The ten with no mandate would otherwise reach an empty sheet.
      for (final country in [
        'FR', 'DE', 'BE', 'ES', 'IT', 'LU', 'CH', 'AT',
        'NL', 'PT', 'GB', 'NO', 'US', 'CA',
      ]) {
        expect(formatsFor(country), isNotEmpty, reason: country);
        expect(formatsFor(country).map((f) => f.id),
            contains('accountant_csv'),
            reason: '$country must always have the honest fallback');
      }
    });

    test('the regulatory file comes FIRST where there is one', () {
      // Someone under audit is looking for one specific file.
      expect(formatsFor('FR').first.id, 'fec');
      expect(formatsFor('PT').first.id, 'saft_pt');
    });
  });

  group('no format claims more than it can support', () {
    test('only files an authority actually asks for are regulatory', () {
      final regulatory = [
        for (final f in accountingFormats)
          if (f.claim == FormatClaim.regulatory) f.id,
      ];
      expect(regulatory, unorderedEquals(['fec', 'saft_pt']),
          reason: 'widening this set needs the authority\'s own spec — '
              'DATEV and Sage are read by a PERSON who posts them, which '
              'is why they can be produced without a ledger at all');
    });

    test('Portugal declares the certification gap', () {
      // The spec is met and the software is not certified. Both are
      // true, and an owner who reads only the first has been misled by
      // omission.
      expect(safTPtFormat.uncertifiedSoftware, isTrue);
      final sheet = File('lib/features/money/presentation/widgets/'
              'accounting_export_sheet.dart')
          .readAsStringSync();
      expect(sheet, contains('uncertifiedSoftware'));
      expect(sheet, contains("ValueKey('accounting-export-uncertified')"));
    });

    test('the generic SAF-T calls itself a subset, not a filing', () {
      expect(safTFormat.claim, FormatClaim.subset);
    });

    test('the audit trail is never named an audit FILE', () {
      // A national audit file is a regulated artefact with a schema and
      // a validator. Calling this one would be the overclaim the whole
      // registry exists to prevent.
      final source =
          File('lib/features/money/domain/audit_trail.dart').readAsStringSync();
      expect(auditTrailFormat.claim, isNot(FormatClaim.regulatory));
      final csv = buildAuditTrailCsv(
        events: const [],
        generatedAt: DateTime(2026, 5, 1),
        workspaceName: 'Pézenas',
      );
      expect(csv, contains('not a regulated audit file'));
      expect(source, contains('CALLED A TRAIL, NEVER AN "AUDIT FILE"'));
    });
  });

  group('DATEV gets the traps right', () {
    String build({DateTime? issuedAt}) => buildDatevFile(
          invoices: [inv(issuedAt: issuedAt, vat: _vat20)],
          matches: {'i1': match()},
          accounts: const DatevAccounts(),
          from: DateTime(2026, 1, 1),
          to: DateTime(2026, 12, 31),
          generatedAt: DateTime(2026, 5, 1, 9),
          consultantNumber: '1234567',
          clientNumber: '54321',
        );

    test('Belegdatum is DDMM — a full date lands in the wrong period', () {
      // The year comes from the header's fiscal-year start. This is the
      // failure that is SILENT, which is why it is pinned.
      expect(build(issuedAt: DateTime(2026, 3, 14)), contains(';1403;'));
      expect(build(issuedAt: DateTime(2026, 3, 14)),
          isNot(contains('2026-03-14')));
    });

    test('amounts are positive and the direction is the S/H flag', () {
      final file = build();
      expect(file, contains('120,00;"S"'),
          reason: 'comma decimal, positive, direction in the flag');
      expect(file, isNot(contains('-120,00')));
    });

    test('Festschreibung is 0 — locking books is the accountant\'s call',
        () {
      // Field 20 of the header.
      final header = build().split('\r\n').first.split(';');
      expect(header[20], '0');
    });

    test('a voided invoice is not booked', () {
      final file = buildDatevFile(
        invoices: [inv(voidedAt: DateTime(2026, 3, 20), vat: _vat20)],
        matches: const {},
        accounts: const DatevAccounts(),
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        generatedAt: DateTime(2026, 5, 1),
        consultantNumber: '1',
        clientNumber: '2',
      );
      expect(file, isNot(contains('INV-1')));
    });

    test('a PENDING settlement is not booked', () {
      // Booking it would put money in the ledger the workspace has not
      // agreed it received (0067).
      final file = buildDatevFile(
        invoices: [inv(vat: _vat20)],
        matches: {'i1': match(status: 'pending')},
        accounts: const DatevAccounts(),
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        generatedAt: DateTime(2026, 5, 1),
        consultantNumber: '1',
        clientNumber: '2',
      );
      expect('Zahlung'.allMatches(file).length, 0);
    });
  });

  group('Sage gets the traps right', () {
    String build({List<InvoiceVatTotal> vat = const []}) => buildSageFile(
          invoices: [inv(vat: vat)],
          matches: {'i1': match()},
          accounts: const SageAccounts(),
          customerRef: (i) => i.memberId,
        );

    test('an invoice is SI and its receipt is SR', () {
      // Getting SI/SC or SI/SR backwards does not error — it moves the
      // debtor balance the wrong way, silently.
      final rows = build(vat: _vat20).trim().split('\r\n');
      expect(rows[1], startsWith('SI,'));
      expect(rows[2], startsWith('SR,'));
    });

    test('net and tax are SEPARATE — Sage derives neither', () {
      // Handing it the gross as Net would overstate turnover by the tax
      // on every line.
      final row = build(vat: _vat20).trim().split('\r\n')[1];
      expect(row, contains('100.00'));
      expect(row, contains('20.00'));
      expect(row, isNot(contains('120.00')));
    });

    test('dates are DD/MM/YYYY — Sage is a UK product', () {
      // An ISO date imports as a different day for the first twelve of
      // every month.
      expect(build(vat: _vat20), contains('14/03/2026'));
    });

    test('a receipt carries NO tax, or the VAT return doubles it', () {
      final receipt = build(vat: _vat20).trim().split('\r\n')[2];
      expect(receipt, contains(SageAccounts.noTaxCode));
      expect(receipt.split(',').last, '0.00');
    });

    test('an untaxed invoice is out of scope (T9), not zero-rated (T0)', () {
      // A zero-RATED supply still belongs on the VAT return; an
      // out-of-scope one does not.
      expect(build(), contains(SageAccounts.noTaxCode));
      expect(build(), isNot(contains(',T0,')));
    });
  });

  group('the honest CSV keeps what the mapped formats must drop', () {
    String build({Invoice? invoice, InvoiceMatch? m}) => buildAccountantCsv(
          invoices: [invoice ?? inv(vat: _vat20)],
          matches: m == null ? const {} : {'i1': m},
          generatedAt: DateTime(2026, 5, 1),
          workspaceName: 'Pézenas',
        );

    test('it says in its own header that it is not a journal', () {
      expect(build(), contains('NOT a journal'));
    });

    test('a voided invoice STAYS — a missing number is what gets asked '
        'about', () {
      final csv = build(
        invoice: inv(
          voidedAt: DateTime(2026, 3, 20),
          voidedByName: 'Owner',
          vat: _vat20,
        ),
      );
      expect(csv, contains('INV-1'));
      expect(csv, contains('voided'));
      expect(csv, contains('Owner'));
    });

    test('a PENDING settlement is shown, not filtered', () {
      // There is no ledger here to protect, and hiding it would leave an
      // invoice looking unpaid while someone is mid-validation.
      expect(build(m: match(status: 'pending')), contains('pending'));
    });
  });

  group('the audit trail is a trail', () {
    test('a void is its OWN event, on its own date', () {
      // Folding it into the invoice row would put a cancellation on the
      // issue date and lose the gap between them — the interesting part.
      final events = buildAuditEvents(
        invoices: [
          inv(voidedAt: DateTime(2026, 3, 20), voidedByName: 'Owner'),
        ],
        matches: const {},
      );
      expect(events.map((e) => e.kind), containsAll(['invoice', 'void']));
      final voided = events.firstWhere((e) => e.kind == 'void');
      expect(voided.at, DateTime(2026, 3, 20));
      expect(voided.actor, 'Owner');
      expect(voided.amountCents, isNegative,
          reason: 'it takes back exactly what the invoice charged');
    });

    test('events come out chronological', () {
      final events = buildAuditEvents(
        invoices: [
          inv(issuedAt: DateTime(2026, 3, 14)),
          inv(id: 'i2', number: 'INV-2', issuedAt: DateTime(2026, 1, 9)),
        ],
        matches: {'i1': match(at: DateTime(2026, 4, 2))},
      );
      final dates = events.map((e) => e.at).toList();
      expect(dates, orderedEquals([...dates]..sort()));
      expect(events.first.reference, 'INV-2');
    });

    test('a settlement never precedes the invoice it settles', () {
      final events = buildAuditEvents(
        invoices: [inv()],
        matches: {'i1': match(at: DateTime(2026, 4, 2))},
      );
      final invoiceAt = events.firstWhere((e) => e.kind == 'invoice').at;
      final paidAt = events.firstWhere((e) => e.kind == 'payment').at;
      expect(paidAt.isAfter(invoiceAt), isTrue);
    });

    test('a name with a comma cannot shift the columns', () {
      final csv = buildAuditTrailCsv(
        events: buildAuditEvents(
          invoices: [inv(memberName: 'Sample, Alex')],
          matches: const {},
        ),
        generatedAt: DateTime(2026, 5, 1),
        workspaceName: 'Pézenas',
      );
      expect(csv, contains('"Sample, Alex"'));
    });
  });
}
