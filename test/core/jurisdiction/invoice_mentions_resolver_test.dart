// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 -- the national invoice mentions behind a contract, through the
// installed add-ons: a country with an add-on states its lines, a country
// without one states none (never another country's), two claimants and a wrong
// contract version are explicit refusals, and the country is the registry's
// spelling.
import 'package:deskilo/core/jurisdiction/installed_invoice_mentions.dart';
import 'package:deskilo/core/jurisdiction/jurisdiction_resolver.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_it/deskilo_jurisdiction_it.dart';
import 'package:flutter_test/flutter_test.dart';

const _context = InvoiceMentionContext(
  sellerVatRegistered: true,
  currency: 'EUR',
  untaxedMinor: 9000,
  correction: false,
);

/// An add-on written against another version of the contract.
class _OtherVersion extends InvoiceMentionsContribution {
  const _OtherVersion();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'other.invoice_mentions',
    implementationVersion: '1',
    contractVersion: '0',
    formatVersion: 'x',
    capabilityId: 'invoice_mentions.IT',
  );

  @override
  List<String> mentions(InvoiceMentionContext context) => const ['x'];
}

void main() {
  test('every installed add-on declares the current contract and a country', () {
    final ids = <String>{};
    for (final c in installedInvoiceMentions) {
      final d = c.descriptor;
      expect(d.contractVersion, invoiceMentionsContractVersion, reason: d.moduleId);
      expect(d.implementationVersion, isNotEmpty);
      expect(d.capabilityId, startsWith('invoice_mentions.'));
      expect(ids.add(d.capabilityId), isTrue, reason: 'one add-on per country');
    }
    expect(ids, {
      'invoice_mentions.CA',
      'invoice_mentions.ES',
      'invoice_mentions.FR',
      'invoice_mentions.IT',
    });
  });

  test('a country with an add-on states its lines', () {
    final resolution = resolveInvoiceMentions(
      const LegalContext(countryCode: 'it'),
      installedInvoiceMentions,
    );
    expect(resolution, isA<ResolvedMentions>());
    expect(
      (resolution as ResolvedMentions).contribution.mentions(_context).single,
      contains('642/1972'),
    );
  });

  test('a country with no add-on states none, and never another country\'s', () {
    for (final code in ['DE', 'CH', '', null, '  ']) {
      expect(
        resolveInvoiceMentions(
          LegalContext(countryCode: code),
          installedInvoiceMentions,
        ),
        isA<NoMentions>(),
        reason: '$code',
      );
    }
  });

  test('two add-ons for one country are refused, not guessed', () {
    final resolution = resolveInvoiceMentions(
      const LegalContext(countryCode: 'IT'),
      const [ItInvoiceMentions(), ItInvoiceMentions()],
    );
    expect(resolution, isA<RefusedMentions>());
    expect(
      (resolution as RefusedMentions).kind,
      RefusalKind.conflictingMentions,
    );
  });

  test('an add-on written against another contract version is refused', () {
    final resolution = resolveInvoiceMentions(
      const LegalContext(countryCode: 'IT'),
      const [_OtherVersion()],
    );
    expect(resolution, isA<RefusedMentions>());
    expect((resolution as RefusedMentions).kind, RefusalKind.contractMismatch);
  });
}
