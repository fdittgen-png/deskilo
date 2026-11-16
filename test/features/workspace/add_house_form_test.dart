// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4005 — Add a house abroad: the country first, the currency, the time
// zone and the documents' language proposed from it and still editable;
// what travels, what arrives to be priced and what does not, said before
// the button; one opened form is one request; a refusal is said.
import 'package:deskilo/core/country/country_catalog.dart';
import 'package:deskilo/core/demo/data/fake_organisation_repository.dart';
import 'package:deskilo/features/workspace/domain/organisation.dart';
import 'package:deskilo/features/workspace/presentation/widgets/add_house_form.dart';
import 'package:deskilo/features/workspace/presentation/widgets/house_birth_view.dart';
import 'package:deskilo/features/workspace/providers/organisation_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

OrganisationHouse _head(HouseRole role) => OrganisationHouse(
  workspaceId: 'head',
  name: 'Atelier du Marché',
  countryCode: 'FR',
  currencyCode: 'EUR',
  role: role,
);

Organisation _organisation(HouseRole role) => Organisation(
  id: 'org',
  name: 'Atelier group',
  headWorkspaceId: 'head',
  houses: [_head(role)],
);

Future<(FakeOrganisationRepository, List<HouseRequest>, ValueGetter<String?>)>
_open(WidgetTester tester, {HouseRole role = HouseRole.owner}) async {
  final requests = <HouseRequest>[];
  final repository = FakeOrganisationRepository(
    organisations: [_organisation(role)],
    createBusiness: (r) async {
      requests.add(r);
      return HouseBirth(
        workspaceId: 'house-${r.requestId}',
        headWorkspaceId: 'head',
        plans: 0,
        services: 0,
        packages: 0,
        validationPolicies: 0,
        features: 0,
        amountsKept: false,
        coOwnersAdded: 0,
        pricesPending: true,
      );
    },
  );
  String? created;
  await pumpApp(
    tester,
    Scaffold(
      body: Consumer(
        builder: (context, ref, _) => FilledButton(
          key: const ValueKey('open'),
          onPressed: () async => created = await AddHouseForm.open(
            context,
            ref,
            _organisation(role),
          ),
          child: const Text('open'),
        ),
      ),
    ),
    size: const Size(420, 1400),
    overrides: [organisationRepositoryProvider.overrideWithValue(repository)],
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
  return (repository, requests, () => created);
}

void main() {
  test('the documents\' language follows the country where it can', () {
    expect(proposedHouseLanguage('IT'), 'it');
    expect(proposedHouseLanguage('CH'), 'de');
    expect(
      proposedHouseLanguage('NL'),
      'en',
      reason: 'not a document language',
    );
  });

  test('a change of country moves what still holds the proposal and keeps '
      'what the person chose', () {
    final at = CountryCatalog.byCode('AT');
    final gb = CountryCatalog.byCode('GB');
    final followed = houseProposalAfter(
      at,
      gb,
      currency: at.currencyCode,
      timezone: at.defaultTimezone,
      language: proposedHouseLanguage('AT'),
    );
    expect(followed, (
      currency: gb.currencyCode,
      timezone: gb.defaultTimezone,
      language: 'en',
    ));
    final kept = houseProposalAfter(
      at,
      gb,
      currency: 'CHF',
      timezone: 'Europe/Zurich',
      language: 'it',
    );
    expect(kept, (currency: 'CHF', timezone: 'Europe/Zurich', language: 'it'));
  });

  testWidgets('what travels is said before the button, and the house is made '
      'in the country proposed', (tester) async {
    final (repository, requests, created) = await _open(tester);
    expect(find.text(_en.houseAddCarried), findsOneWidget);
    expect(find.text(_en.houseAddToPrice), findsOneWidget);
    expect(find.text(_en.houseAddNotCarried), findsOneWidget);
    final first = CountryCatalog.countries.first;

    await tester.enterText(
      find.byKey(const ValueKey('house-add-name')),
      'Atelier Wien',
    );
    await tester.tap(find.byKey(const ValueKey('house-add-submit')));
    await tester.pumpAndSettle();

    expect(requests.single.country, first.code);
    expect(requests.single.currency, first.currencyCode);
    expect(requests.single.timezone, first.defaultTimezone);
    expect(requests.single.language, proposedHouseLanguage(first.code));
    expect(created(), 'house-${requests.single.requestId}');
    final o = (await repository.myOrganisations()).single;
    expect(o.houseOf(created()!)?.name, 'Atelier Wien');
  });

  testWidgets('only the head\'s owner makes a house, and the refusal is said', (
    tester,
  ) async {
    final (_, requests, created) = await _open(tester, role: HouseRole.member);
    await tester.enterText(
      find.byKey(const ValueKey('house-add-name')),
      'Atelier London',
    );
    await tester.tap(find.byKey(const ValueKey('house-add-submit')));
    await tester.pumpAndSettle();
    expect(find.text(_en.organisationRefusedNotOwner), findsOneWidget);
    expect(requests, isEmpty);
    expect(created(), isNull);
  });

  testWidgets('the birth record says what came and what did not', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Scaffold(
        body: HouseBirthView(
          head: 'Atelier du Marché',
          birth: HouseBirth(
            workspaceId: 'ldn',
            headWorkspaceId: 'head',
            plans: 4,
            services: 6,
            packages: 1,
            validationPolicies: 2,
            features: 30,
            amountsKept: false,
            coOwnersAdded: 1,
            pricesPending: true,
            createdAt: DateTime(2026, 11, 15),
          ),
        ),
      ),
    );
    expect(
      find.text(
        _en.houseBirthToPrice(
          '${_en.houseBirthPlans(4)}, ${_en.houseBirthServices(6)}, '
          '${_en.houseBirthPackages(1)}',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(_en.houseBirthCoOwners(1)), findsOneWidget);
    expect(find.text(_en.houseBirthNotCarried), findsOneWidget);
    expect(find.textContaining('Atelier du Marché'), findsOneWidget);
  });

  testWidgets('a house born without plans names none (#4042)', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: HouseBirthView(
          head: 'Atelier du Marché',
          birth: HouseBirth(
            workspaceId: 'krk',
            headWorkspaceId: 'head',
            plans: 0,
            services: 6,
            packages: 1,
            validationPolicies: 2,
            features: 30,
            amountsKept: false,
            coOwnersAdded: 1,
            pricesPending: true,
            createdAt: DateTime(2026, 11, 15),
          ),
        ),
      ),
    );
    expect(
      find.text(
        _en.houseBirthToPrice(
          '${_en.houseBirthServices(6)}, ${_en.houseBirthPackages(1)}',
        ),
      ),
      findsOneWidget,
    );
    expect(find.textContaining(_en.houseBirthPlans(0)), findsNothing);
  });
}
