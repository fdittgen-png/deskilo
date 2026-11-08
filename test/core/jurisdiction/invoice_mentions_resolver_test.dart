// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 -- the national invoice mentions behind a contract: a country that
// exists only in a test states its lines through the resolver; a country with
// no add-on states none (never another country's); two claimants and a wrong
// contract version are explicit refusals; the country is the registry's
// spelling.
import 'package:deskilo/core/jurisdiction/jurisdiction_resolver.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_invoice_mentions.dart';

const _context = InvoiceMentionContext(
  sellerVatRegistered: true,
  currency: 'EUR',
  untaxedMinor: 9000,
  correction: true,
  rectifies: 'F-7',
);

void main() {
  test('the mentions contract is versioned apart from the other two', () {
    expect(invoiceMentionsContractVersion, '1');
    expect(
      const FakeInvoiceMentions('XX').descriptor.contractVersion,
      invoiceMentionsContractVersion,
    );
  });

  test('a country that exists only in a test states its lines', () {
    final resolution = resolveInvoiceMentions(
      const LegalContext(countryCode: 'xx'),
      const [FakeInvoiceMentions('XX'), FakeInvoiceMentions('YY')],
    );
    expect(resolution, isA<ResolvedMentions>());
    expect((resolution as ResolvedMentions).contribution.mentions(_context), [
      'FAKE 9000',
      'FAKE correction of F-7',
    ]);
  });

  test('a country with no add-on states none, and never another country\'s', () {
    for (final code in ['DE', '', null, '  ']) {
      expect(
        resolveInvoiceMentions(
          LegalContext(countryCode: code),
          const [FakeInvoiceMentions('XX')],
        ),
        isA<NoMentions>(),
        reason: '$code',
      );
    }
  });

  test('two add-ons for one country are refused, not guessed', () {
    final resolution = resolveInvoiceMentions(
      const LegalContext(countryCode: 'XX'),
      const [FakeInvoiceMentions('XX'), FakeInvoiceMentions('XX')],
    );
    expect(resolution, isA<RefusedMentions>());
    expect(
      (resolution as RefusedMentions).kind,
      RefusalKind.conflictingMentions,
    );
  });

  test('an add-on written against another contract version is refused', () {
    final resolution = resolveInvoiceMentions(
      const LegalContext(countryCode: 'XX'),
      const [FakeInvoiceMentions('XX', contractVersion: '0')],
    );
    expect(resolution, isA<RefusedMentions>());
    expect((resolution as RefusedMentions).kind, RefusalKind.contractMismatch);
  });

  test('UK is GB, as everywhere else in the registry', () {
    expect(
      resolveInvoiceMentions(
        const LegalContext(countryCode: 'UK'),
        const [FakeInvoiceMentions('GB')],
      ),
      isA<ResolvedMentions>(),
    );
  });
}
