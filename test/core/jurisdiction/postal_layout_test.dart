// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3649 -- an address is written the way its country writes it: the lines
// below the street come from the country's postal layout, a domestic letter
// leaves the country out and one abroad names it in the reader's language.
// France and Germany print exactly what they printed before.
// #3649 (3a) -- Spain and Ireland print the region's name, the others its code.
import 'package:deskilo/core/jurisdiction/installed_postal_layouts.dart';
import 'package:deskilo/core/jurisdiction/jurisdiction_resolver.dart';
import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_fr/deskilo_jurisdiction_fr.dart';
import 'package:flutter_test/flutter_test.dart';

class _OtherVersion extends PostalLayoutContribution {
  const _OtherVersion();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'other.postal_layout',
    implementationVersion: '1',
    contractVersion: '0',
    formatVersion: '1',
    capabilityId: 'postal_layout.FR',
  );

  @override
  PostalLayout get layout => defaultPostalLayout;
}

PersonalInfo _at(
  String country,
  String street,
  String postalCode,
  String city, [
  String region = '',
]) => PersonalInfo(
  firstName: 'Alex',
  lastName: 'Martin',
  street: street,
  postalCode: postalCode,
  city: city,
  subdivision: region,
  countryCode: country,
);

/// One address per country, and how its own post writes it at home.
final Map<String, (PersonalInfo, String)> _addresses = {
  'FR': (
    _at('FR', '1 rue de la Paix', '75002', 'Paris'),
    '1 rue de la Paix\n75002 PARIS',
  ),
  'DE': (
    _at('DE', 'Unter den Linden 1', '10117', 'Berlin'),
    'Unter den Linden 1\n10117 BERLIN',
  ),
  'CH': (
    _at('CH', 'Bahnhofstrasse 1', '8001', 'Zürich', 'ZH'),
    'Bahnhofstrasse 1\n8001 Zürich',
  ),
  'IT': (
    _at('IT', 'Via Roma 2', '20121', 'Milano', 'MI'),
    'Via Roma 2\n20121 MILANO MI',
  ),
  'ES': (
    _at('ES', 'Calle Mayor 1', '28013', 'Madrid', 'M'),
    'Calle Mayor 1\n28013 Madrid\nMadrid',
  ),
  'GB': (
    _at('GB', '10 Downing Street', 'sw1a 2aa', 'London'),
    '10 Downing Street\nLONDON\nSW1A 2AA',
  ),
  'IE': (
    _at('IE', '1 Main Street', 'd02 x285', 'Dublin', 'D'),
    '1 Main Street\nDublin\nDublin\nD02 X285',
  ),
  'PL': (
    _at('PL', 'ul. Marszałkowska 1', '00-624', 'Warszawa'),
    'ul. Marszałkowska 1\n00-624 Warszawa',
  ),
  'US': (
    _at('US', '1600 Pennsylvania Ave NW', '20500', 'Washington', 'DC'),
    '1600 Pennsylvania Ave NW\nWASHINGTON DC 20500',
  ),
  'RO': (
    _at('RO', 'Strada Lipscani 1', '030031', 'București', 'B'),
    'Strada Lipscani 1\n030031 București\nBucurești',
  ),
  'CA': (
    _at('CA', '24 Sussex Dr', 'k1m 1m4', 'Ottawa', 'ON'),
    '24 Sussex Dr\nOTTAWA ON K1M 1M4',
  ),
};

void main() {
  test(
    'every installed layout declares the current contract and one country',
    () {
      final ids = <String>{};
      for (final c in installedPostalLayouts) {
        final d = c.descriptor;
        expect(
          d.contractVersion,
          postalLayoutContractVersion,
          reason: d.moduleId,
        );
        expect(d.capabilityId, startsWith('postal_layout.'));
        expect(
          ids.add(d.capabilityId),
          isTrue,
          reason: 'one layout per country',
        );
      }
      expect(ids, {for (final c in _addresses.keys) 'postal_layout.$c'});
    },
  );

  group('a domestic letter is written as its country writes it', () {
    for (final MapEntry(key: country, value: (info, block))
        in _addresses.entries) {
      test(country, () {
        expect(info.postalBlock(workspaceCountry: country), block);
      });
    }
  });

  test('a letter abroad names the country in the reader\'s language', () {
    final (us, home) = _addresses['US']!;
    expect(
      us.postalBlock(
        workspaceCountry: 'FR',
        countryName: (code) => code == 'US' ? 'États-Unis' : code,
      ),
      '$home\nÉTATS-UNIS',
    );
    // Without the app's names, the code: what the stored rendering prints.
    expect(us.postalBlock(workspaceCountry: 'FR'), '$home\nUS');
  });

  test('an address that names no country is written as the workspace\'s', () {
    final info = _at('', 'Via Roma 2', '20121', 'Milano', 'MI');
    expect(
      info.postalBlock(workspaceCountry: 'IT'),
      'Via Roma 2\n20121 MILANO MI',
    );
  });

  test(
    'a country with no layout of its own keeps the default and its region',
    () {
      final info = _at('AT', 'Ring 1', '1010', 'Wien', '9');
      expect(info.postalBlock(workspaceCountry: 'AT'), 'Ring 1\n1010 WIEN 9');
      expect(postalLayoutOf('ZZ'), same(defaultPostalLayout));
      expect(postalLayoutOf(''), same(defaultPostalLayout));
    },
  );

  test(
    'on one line an address is written as given, in its country\'s order',
    () {
      expect(
        postalLayoutOf('US').render(
          postalCode: '20500',
          city: 'Washington',
          region: 'DC',
          capitals: false,
        ),
        ['Washington DC 20500'],
      );
      expect(
        postalLayoutOf('FR')
            .render(postalCode: '34120', city: 'Pézenas', capitals: false),
        ['34120 Pézenas'],
      );
    },
  );

  test(
    'a region is a code its country has, required where its post needs one',
    () {
      final us = postalLayoutOf('US');
      expect(us.regionRefusal(' ny '), isNull);
      expect(us.regionRefusal(''), RegionRefusal.missing);
      expect(us.regionRefusal('ZZ'), RegionRefusal.unknown);
      expect(us.regionRefusal('New York'), RegionRefusal.notACode);
      expect(postalLayoutOf('ES').regionRefusal(''), isNull);
      expect(postalLayoutOf('FR').regionRefusal(''), isNull);
      // A country with no list of its own takes any code.
      expect(postalLayoutOf('AT').regionRefusal('9'), isNull);
      expect(regionCode(' mi '), 'MI');
    },
  );

  test(
    'two layouts for one country, or a wrong contract version, are errors',
    () {
      expect(
        () => resolvePostalLayout(const LegalContext(countryCode: 'FR'), const [
          FrPostalLayout(),
          FrPostalLayout(),
        ]),
        throwsStateError,
      );
      expect(
        () => resolvePostalLayout(const LegalContext(countryCode: 'FR'), const [
          _OtherVersion(),
        ]),
        throwsStateError,
      );
    },
  );
}
