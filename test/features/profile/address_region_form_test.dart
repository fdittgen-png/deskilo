// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3649 (3a) -- the identity form asks for the region where the address's
// country has one: a list of the country's regions, required where its post
// needs one, and nothing where the country's addresses have none. An address
// stored before its country asked for a region keeps saving until it is
// edited.
import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:deskilo/features/profile/presentation/widgets/personal_info_form.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<PersonalInfo>> _pump(
  WidgetTester tester,
  PersonalInfo initial,
) async {
  final saved = <PersonalInfo>[];
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: PersonalInfoForm(
            initial: initial,
            managed: true,
            onSave: (info) async => saved.add(info),
          ),
        ),
      ),
    ),
  );
  return saved;
}

const _newYork = PersonalInfo(
  firstName: 'Alex',
  lastName: 'Martin',
  street: '350 Fifth Avenue',
  postalCode: '10118',
  city: 'New York',
  countryCode: 'US',
);

final _region = find.byKey(const ValueKey('personal-info-region'));
final _save = find.byKey(const ValueKey('personal-info-save'));

void main() {
  testWidgets('an American address chooses its state from the list', (
    tester,
  ) async {
    final saved = await _pump(tester, _newYork.withRegion('NY'));
    expect(find.text('State'), findsOneWidget);
    expect(find.text('New York'), findsWidgets);
    await tester.tap(_save);
    await tester.pump();
    expect(saved.single.subdivision, 'NY');
  });

  testWidgets('a French address has no region field', (tester) async {
    await _pump(
      tester,
      const PersonalInfo(
        street: '1 rue de la Paix',
        city: 'Paris',
        countryCode: 'FR',
      ),
    );
    expect(_region, findsNothing);
  });

  testWidgets('an address stored without its state keeps saving as it is', (
    tester,
  ) async {
    final saved = await _pump(tester, _newYork);
    await tester.tap(_save);
    await tester.pump();
    expect(saved, hasLength(1));
    expect(
      find.text('An address in this country needs its region.'),
      findsNothing,
    );
  });

  testWidgets('once the address is edited, a state it needs is asked for', (
    tester,
  ) async {
    final saved = await _pump(tester, _newYork);
    await tester.enterText(
      find.byKey(const ValueKey('personal-info-street')),
      '20 W 34th St',
    );
    await tester.tap(_save);
    await tester.pump();
    expect(saved, isEmpty);
    expect(
      find.text('An address in this country needs its region.'),
      findsOneWidget,
    );

    await tester.tap(_region);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New York').last);
    await tester.pumpAndSettle();
    await tester.tap(_save);
    await tester.pump();
    expect(saved.single.subdivision, 'NY');
    expect(saved.single.street, '20 W 34th St');
  });
}

extension on PersonalInfo {
  PersonalInfo withRegion(String code) =>
      PersonalInfo.fromDb({...toDb(), PersonalInfo.keySubdivision: code});
}
