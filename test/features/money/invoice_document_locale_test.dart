// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3850 — the locale an invoice renders in: the language and the seller's
// country the server froze at issue; an invoice issued before 0753 (or a
// draft) takes the business's document language, never the reader's.
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/presentation/invoice_document_locale.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _invoice = Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'F-1',
  issuedAt: DateTime(2026, 11, 13),
  title: '2026-11',
  lines: const [],
  totalCents: 1000,
  currency: 'CHF',
  memberName: 'Ana',
  memberAddress: '',
  workspaceName: 'Space',
  workspaceAddress: '',
  issuerName: 'Flo',
  signature: 's',
);

void main() {
  test('a frozen invoice renders in its language and its seller country\'s '
      'conventions, whatever the business has chosen since', () {
    expect(
      invoiceDocumentLocaleOf(
        _invoice.copyWith(documentLanguage: 'fr', formatLocale: 'fr_CH'),
        country: 'CH',
        locale: 'de',
        reference: ActiveTaxReference.current,
      ),
      (language: 'fr', formatLocale: 'fr_CH'),
    );
  });

  test('an invoice issued before 0753 renders in the business\'s document '
      'language', () {
    expect(
      invoiceDocumentLocaleOf(
        _invoice,
        country: 'CH',
        locale: 'it',
        reference: ActiveTaxReference.current,
      ),
      (language: 'it', formatLocale: 'it_CH'),
    );
    expect(
      invoiceDocumentLocaleOf(
        _invoice,
        country: 'FR',
        reference: ActiveTaxReference.current,
      ),
      (language: 'fr', formatLocale: 'fr_FR'),
    );
    // A country whose languages the app does not ship: English, read with a
    // day-first order.
    expect(
      invoiceDocumentLocaleOf(
        _invoice,
        country: 'PL',
        reference: ActiveTaxReference.current,
      ),
      (language: 'en', formatLocale: 'en_GB'),
    );
  });

  test(
    'a stored language the app does not ship falls back to the business\'s',
    () {
      expect(
        invoiceDocumentLocaleOf(
          _invoice.copyWith(documentLanguage: 'pt', formatLocale: 'pt_PT'),
          country: 'FR',
          reference: ActiveTaxReference.current,
        ),
        (language: 'fr', formatLocale: 'fr_FR'),
      );
    },
  );
}
