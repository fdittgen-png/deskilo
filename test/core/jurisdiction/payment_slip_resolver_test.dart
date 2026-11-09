// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 -- the payment slip of a country's invoices behind its own contract:
// Switzerland's QR bill. Its existence is the gate (a seller from another
// country is given none, and never Switzerland's), and it declares the country
// of an address that names none and how another country's address is prefixed.
// A wrong composition is a programming error.
import 'package:deskilo/core/jurisdiction/installed_payment_slips.dart';
import 'package:deskilo/core/jurisdiction/jurisdiction_resolver.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_ch/deskilo_jurisdiction_ch.dart';
import 'package:flutter_test/flutter_test.dart';

class _OtherVersion extends PaymentSlipContribution {
  const _OtherVersion();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'other.payment_slip',
    implementationVersion: '1',
    contractVersion: '0',
    formatVersion: 'x',
    capabilityId: 'payment_slip.CH',
  );

  @override
  String get homeCountry => 'XX';

  @override
  Set<String> get accountCountries => const {};

  @override
  String addressCountryPrefix(String country) => '';
}

void main() {
  test(
    'every installed add-on declares the current contract and one country',
    () {
      final ids = <String>{};
      for (final c in installedPaymentSlips) {
        final d = c.descriptor;
        expect(
          d.contractVersion,
          paymentSlipContractVersion,
          reason: d.moduleId,
        );
        expect(d.capabilityId, startsWith('payment_slip.'));
        expect(
          ids.add(d.capabilityId),
          isTrue,
          reason: 'one add-on per country',
        );
      }
      expect(ids, {'payment_slip.CH'});
    },
  );

  test('Switzerland has a slip, in its own words', () {
    final ch = paymentSlipOf('CH')!;
    expect(paymentSlipOf(' ch '), same(ch));
    expect(ch.homeCountry, 'CH');
    expect(ch.accountCountries, {'CH', 'LI'});
    expect(ch.addressCountryPrefix('CH'), '');
    expect(ch.addressCountryPrefix('DE'), 'DE-');
    expect(ch.addressCountryPrefix('LI'), 'LI-');
  });

  test('a country with no slip is given none, and never another\'s', () {
    for (final c in ['DE', 'FR', 'LI', 'GB', '', '  ', 'XX']) {
      expect(paymentSlipOf(c), isNull, reason: c);
    }
  });

  test(
    'two add-ons for one country, or a wrong contract version, are errors',
    () {
      expect(
        () => resolvePaymentSlip(const LegalContext(countryCode: 'CH'), const [
          ChPaymentSlip(),
          ChPaymentSlip(),
        ]),
        throwsStateError,
      );
      expect(
        () => resolvePaymentSlip(const LegalContext(countryCode: 'CH'), const [
          _OtherVersion(),
        ]),
        throwsStateError,
      );
    },
  );
}
