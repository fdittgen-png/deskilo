// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3337 -- the invoice profile contract on the host path: an invoice of the
// application becomes the neutral context in one adapter, the resolver picks
// the profile by the format's own name, and a country that exists only in a
// test renders an invoice without the host knowing it.
import 'dart:convert';

import 'package:deskilo/core/jurisdiction/jurisdiction_resolver.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/application/jurisdiction/invoice_document_context_builder.dart';
import 'package:deskilo/features/money/domain/einvoice_input.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_invoice_profile.dart';

const _seller = InvoiceParty(
  name: 'Spazio Prova S.r.l.',
  street: 'Via Roma 1',
  city: 'Milano',
  postalCode: '20121',
  country: 'IT',
  subdivision: 'MI',
  vatId: 'IT01234567897',
  vatRegime: 'vat_registered',
);

const _buyer = InvoiceParty(
  name: 'Studio Nord S.r.l.',
  country: 'IT',
  vatId: 'IT09876543217',
  endpointId: 'KRRH6B9',
);

Invoice _invoice() => Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'IT-2026/0042',
  issuedAt: DateTime(2026, 9, 30),
  period: '2026-09',
  title: '2026-09',
  lines: const [
    InvoiceLine(
      kind: 'subscription',
      label: '50',
      amountCents: 24400,
      vatPercent: 22,
      vatCategory: 'S',
    ),
  ],
  vatTotals: const [
    InvoiceVatTotal(
      percent: 22,
      category: 'S',
      grossCents: 24400,
      netCents: 20000,
      vatCents: 4400,
    ),
  ],
  totalCents: 24400,
  currency: 'EUR',
  memberName: 'Studio Nord',
  memberAddress: '',
  workspaceName: 'Spazio Prova',
  workspaceAddress: '',
  issuerName: 'Flo',
  signature: 'f' * 64,
);

EInvoiceInput _input({InvoiceParty buyer = _buyer}) => EInvoiceInput(
  invoice: _invoice(),
  seller: _seller,
  buyer: buyer,
  lineText: (line) => invoiceLineText(const ReportStrings(), line), reference: ActiveTaxReference.current,
);

void main() {
  test('the invoice profile contract is versioned apart from the VAT one', () {
    expect(invoiceProfileContractVersion, '1');
    expect(jurisdictionContractVersion, '2', reason: 'additive: VAT unchanged');
    expect(
      const FakeInvoiceProfile('fakeXx').descriptor.contractVersion,
      invoiceProfileContractVersion,
    );
  });

  test('the adapter hands the profile the figures, computed once', () {
    final context = invoiceDocumentContextOf(
      _input(),
      transmitterId: 'IT01234567890',
    );
    expect(context.number, 'IT-2026/0042');
    expect(context.currency, 'EUR');
    expect(context.currencyExponent, 2);
    expect(context.creditNote, isFalse);
    expect(context.payableMinor, 24400);
    expect(context.sellerVatRegistered, isTrue);
    expect(context.seller.subdivision, 'MI');
    expect(context.buyer.endpointId, 'KRRH6B9');
    expect(context.transmitterId, 'IT01234567890');
    expect(context.lines.single.grossMinor, 24400);
    expect(context.lines.single.vatPercent, 22);
    expect(context.vatBreakdown.single.netMinor, 20000);
    expect(context.vatBreakdown.single.vatMinor, 4400);
    expect(
      () => context.lines.add(context.lines.first),
      throwsUnsupportedError,
    );
  });

  test('the context states the period, the corrected date and the EU '
      'member states, so a profile reads no reference of its own', () {
    final context = invoiceDocumentContextOf(
      _input(),
      correctedIssuedAt: DateTime(2026, 8, 31),
    );
    expect(context.period, '2026-09');
    expect(context.correctedIssuedAt, DateTime(2026, 8, 31));
    expect(context.euMemberStates, containsAll(['DE', 'FR', 'PL', 'IT']));
    expect(context.euMemberStates, isNot(contains('CH')));
    expect(() => context.euMemberStates.add('XX'), throwsUnsupportedError);
    expect(invoiceDocumentContextOf(_input()).correctedIssuedAt, isNull);
  });

  test('a country that exists only in a test renders an invoice', () {
    const installed = [FakeInvoiceProfile('fakeXx')];
    final resolution = resolveInvoiceProfile('fakeXx', installed);
    final profile = (resolution as ResolvedProfile).profile;
    final checked = profile.validate(invoiceDocumentContextOf(_input()));
    expect(checked.result.isOk, isTrue);
    final artifact = profile.build(checked.document!);
    expect(
      utf8.decode(artifact.bytes),
      'FAKE|fakeXx|IT-2026/0042|EUR|24400|22.0:S:20000:4400',
    );
    expect(artifact.provenance['capability_id'], 'invoice_profile.fakeXx');
    expect(artifact.provenance['contract_version'], '1');
  });

  test('a refused document gets stable codes and cannot be built', () {
    const profile = FakeInvoiceProfile('fakeXx');
    final context = invoiceDocumentContextOf(
      _input(buyer: _buyer.copyWith(country: '')),
    );
    final checked = profile.validate(context);
    expect(checked.document, isNull);
    expect(checked.result.codes, ['buyerCountry']);
    expect(
      () => profile.build(ValidatedInvoiceDocument(context)),
      throwsStateError,
    );
  });

  test('an unknown format is an explicit refusal, never a default', () {
    final resolution = resolveInvoiceProfile('fatturaPa', const []);
    expect((resolution as RefusedProfile).kind, RefusalKind.unknownProfile);
  });

  test('two profiles for one format are refused, not guessed', () {
    final resolution = resolveInvoiceProfile('fakeXx', const [
      FakeInvoiceProfile('fakeXx'),
      FakeInvoiceProfile('fakeXx'),
    ]);
    expect((resolution as RefusedProfile).kind, RefusalKind.conflictingProfile);
  });

  test('a profile written against another contract version is refused', () {
    final resolution = resolveInvoiceProfile('fakeXx', const [
      FakeInvoiceProfile('fakeXx', contractVersion: '0'),
    ]);
    expect((resolution as RefusedProfile).kind, RefusalKind.contractMismatch);
  });
}
