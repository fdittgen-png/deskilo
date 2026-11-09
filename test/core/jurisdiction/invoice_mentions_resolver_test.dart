// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 -- the national invoice mentions behind a contract, through the
// installed add-ons: a country with an add-on states its lines, a country
// without one states none (never another country's), two claimants and a wrong
// contract version are explicit refusals, and the country is the registry's
// spelling.
import 'package:deskilo/core/jurisdiction/installed_invoice_mentions.dart';
import 'package:deskilo/core/jurisdiction/jurisdiction_resolver.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart'
    show LegalProfile;
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
  test(
    'every installed add-on declares the current contract and a country',
    () {
      final ids = <String>{};
      for (final c in installedInvoiceMentions) {
        final d = c.descriptor;
        expect(
          d.contractVersion,
          invoiceMentionsContractVersion,
          reason: d.moduleId,
        );
        expect(d.implementationVersion, isNotEmpty);
        expect(d.capabilityId, startsWith('invoice_mentions.'));
        expect(
          ids.add(d.capabilityId),
          isTrue,
          reason: 'one add-on per country',
        );
      }
      expect(ids, {
        'invoice_mentions.CA',
        'invoice_mentions.CH',
        'invoice_mentions.DE',
        'invoice_mentions.ES',
        'invoice_mentions.FR',
        'invoice_mentions.GB',
        'invoice_mentions.IT',
        'invoice_mentions.US',
      });
    },
  );

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

  test(
    'a country with no add-on states none, and never another country\'s',
    () {
      for (final code in ['AT', 'PL', '', null, '  ']) {
        expect(
          resolveInvoiceMentions(
            LegalContext(countryCode: code),
            installedInvoiceMentions,
          ),
          isA<NoMentions>(),
          reason: '$code',
        );
      }
    },
  );

  test('a country whose law adds no line still declares its clause family', () {
    String family(String code) {
      final r = resolveInvoiceMentions(
        LegalContext(countryCode: code),
        installedInvoiceMentions,
      );
      return (r as ResolvedMentions).contribution.profileFamily;
    }

    expect(
      {
        for (final c in ['FR', 'DE', 'GB', 'CH', 'CA', 'US']) c: family(c),
      },
      {'FR': 'fr', 'DE': 'de', 'GB': 'gb', 'CH': 'ch', 'CA': 'ca', 'US': 'us'},
    );
    // ES and IT add lines but have no clause family of their own
    expect(family('ES'), isEmpty);
    expect(family('IT'), isEmpty);
    // only the French law makes clauses automatic
    for (final c in installedInvoiceMentions) {
      expect(
        c.automaticClauses,
        c.descriptor.capabilityId == 'invoice_mentions.FR'
            ? {'latePenalty', 'recoveryIndemnity', 'escompte'}
            : isEmpty,
        reason: c.descriptor.capabilityId,
      );
    }
  });

  test('a seller\'s registration numbers print as the country of its add-on shows them', () {
    InvoiceMentionsContribution of(String code) => (resolveInvoiceMentions(
      LegalContext(countryCode: code),
      installedInvoiceMentions,
    ) as ResolvedMentions).contribution;
    // Switzerland: a valid UID (raw, dotted or with its suffix) is grouped,
    // an invalid one is left as written
    expect(of('CH').formatSellerVatId('CHE123456788'), 'CHE-123.456.788');
    expect(
      of('CH').formatSellerVatId('CHE-123.456.788 MWST'),
      'CHE-123.456.788 MWST',
    );
    expect(of('CH').formatSellerVatId('CHE-123.456.789'), 'CHE-123.456.789');
    expect(of('CH').formatSellerLegalId('812345678'), '812345678');
    // Canada: the GST/HST number and the Quebec number
    expect(of('CA').formatSellerVatId('123456789RT0001'), '123456789 RT0001');
    expect(
      of('CA').formatSellerLegalId('1234567890TQ0001'),
      '1234567890 TQ0001',
    );
    expect(of('CA').formatSellerVatId('junk'), 'junk');
    // every other add-on prints a number as it was written
    for (final c in ['FR', 'DE', 'GB', 'US', 'ES', 'IT']) {
      expect(
        of(c).formatSellerVatId('CHE123456788'),
        'CHE123456788',
        reason: c,
      );
      expect(
        of(c).formatSellerLegalId('1234567890TQ0001'),
        '1234567890TQ0001',
        reason: c,
      );
    }
  });

  test('every installed clause family names both of its legal profiles', () {
    final profiles = LegalProfile.values.asNameMap();
    for (final c in installedInvoiceMentions) {
      final family = c.profileFamily;
      if (family.isEmpty) continue;
      for (final capacity in ['Business', 'Consumer']) {
        expect(
          profiles.containsKey('$family$capacity'),
          isTrue,
          reason: '${c.descriptor.capabilityId}: $family$capacity',
        );
      }
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
