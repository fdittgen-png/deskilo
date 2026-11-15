// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — Settings › Organisation: a business in no organisation becomes
// the head of one; an owner adds another of their businesses and takes a
// house out; the head leaves last, and the refusal is said; each house says
// its country, its currency and the reader's own role.
import 'package:deskilo/core/demo/data/fake_organisation_repository.dart';
import 'package:deskilo/features/workspace/domain/organisation.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/presentation/widgets/organisation_sheet.dart';
import 'package:deskilo/features/workspace/providers/organisation_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

Workspace _space(String id, String name, String country, String currency) =>
    Workspace(
      id: id,
      name: name,
      countryCode: country,
      currencyCode: currency,
      timezone: 'Europe/Paris',
      inviteCode: 'X',
      environment: 'prod',
    );

final _head = _space('head', 'Atelier du Marché', 'FR', 'EUR');
final _london = _space('ldn', 'Atelier London', 'GB', 'GBP');

OrganisationHouse _house(Workspace w) => OrganisationHouse(
  workspaceId: w.id,
  name: w.name,
  countryCode: w.countryCode,
  currencyCode: w.currencyCode,
  role: HouseRole.owner,
);

Future<FakeOrganisationRepository> _open(
  WidgetTester tester, {
  FakeOrganisationRepository? given,
  Workspace? opened,
}) async {
  final repository =
      given ??
      FakeOrganisationRepository(businesses: [_house(_head), _house(_london)]);
  await pumpApp(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => FilledButton(
          key: const ValueKey('open'),
          onPressed: () => OrganisationSheet.open(context, opened ?? _head),
          child: const Text('open'),
        ),
      ),
    ),
    size: const Size(390, 1200),
    overrides: [
      organisationRepositoryProvider.overrideWithValue(repository),
      myWorkspacesProvider.overrideWith((ref) async => [_head, _london]),
    ],
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _name(WidgetTester tester, String name) async {
  await tester.enterText(
    find.byKey(const ValueKey('organisation-name-field')),
    name,
  );
  await tester.tap(find.byKey(const ValueKey('organisation-name-save')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a business becomes the head, adds a house abroad, and the '
      'head leaves last', (tester) async {
    final repository = await _open(tester);
    expect(find.text(_en.organisationNone), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('organisation-create')));
    await tester.pumpAndSettle();
    await _name(tester, 'Atelier group');
    expect((await repository.myOrganisations()).single.headWorkspaceId, 'head');
    expect(find.text('Atelier group'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('organisation-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('organisation-candidate-ldn')));
    await tester.pumpAndSettle();
    expect(
      find.text('United Kingdom · GBP · ${_en.organisationYourRole('owner')}'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('organisation-remove-head')));
    await tester.pumpAndSettle();
    expect(find.text(_en.organisationRefusedHeadLeavesLast), findsOneWidget);
    expect((await repository.myOrganisations()).single.houses, hasLength(2));

    await tester.tap(find.byKey(const ValueKey('organisation-remove-ldn')));
    await tester.pumpAndSettle();
    expect(
      [
        for (final h in (await repository.myOrganisations()).single.houses)
          h.workspaceId,
      ],
      ['head'],
    );
  });

  testWidgets('an organisation needs a name, and nothing is made without '
      'one', (tester) async {
    final repository = await _open(tester);
    await tester.tap(find.byKey(const ValueKey('organisation-create')));
    await tester.pumpAndSettle();
    await _name(tester, '   ');
    expect(find.text(_en.organisationRefusedNoName), findsOneWidget);
    expect(await repository.myOrganisations(), isEmpty);
  });

  testWidgets('the head\'s owner makes another house the head', (tester) async {
    final repository = await _open(tester);
    await tester.tap(find.byKey(const ValueKey('organisation-create')));
    await tester.pumpAndSettle();
    await _name(tester, 'Atelier group');
    await tester.tap(find.byKey(const ValueKey('organisation-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('organisation-candidate-ldn')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('organisation-head-ldn')));
    await tester.pumpAndSettle();
    expect((await repository.myOrganisations()).single.headWorkspaceId, 'ldn');
  });

  testWidgets('a house\'s owner who does not own the head may only leave', (
    tester,
  ) async {
    final organisation = Organisation(
      id: 'org',
      name: 'Atelier group',
      headWorkspaceId: 'head',
      houses: [
        OrganisationHouse(
          workspaceId: 'head',
          name: _head.name,
          countryCode: 'FR',
          currencyCode: 'EUR',
          role: HouseRole.member,
        ),
        _house(_london),
      ],
    );
    final repository = await _open(
      tester,
      given: FakeOrganisationRepository(organisations: [organisation]),
      opened: _london,
    );
    expect(find.byKey(const ValueKey('organisation-rename')), findsNothing);
    expect(find.byKey(const ValueKey('organisation-add')), findsNothing);
    expect(find.byKey(const ValueKey('organisation-remove-ldn')), findsNothing);
    expect(find.byKey(const ValueKey('organisation-leave-head')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('organisation-leave-ldn')));
    await tester.pumpAndSettle();
    expect((await repository.myOrganisations()).single.houseOf('ldn'), isNull);
  });
}
