// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3649 (3b) -- a site keeps the region of its address: it reads it, prints
// it where its country's layout places it, and its dialog asks for it as the
// identity form does -- required once the address is edited where the
// country needs one, while a site stored before keeps saving.
import 'package:deskilo/features/workspace/domain/site.dart';
import 'package:deskilo/features/workspace/presentation/widgets/site_edit_dialog.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _brera = Site(
  id: 's1',
  workspaceId: 'ws-1',
  name: 'Brera',
  street: 'Via Brera 7',
  postalCode: '20121',
  city: 'Milano',
  countryCode: 'IT',
);

Future<List<SiteEditResult?>> _open(WidgetTester tester, Site site) async {
  final results = <SiteEditResult?>[];
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.add(
            await showDialog<SiteEditResult>(
              context: context,
              builder: (_) => SiteEditDialog(
                site: site,
                workspaceId: 'ws-1',
                workspaceCountry: 'IT',
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

final _save = find.byKey(const ValueKey('site-save'));
const _missing = 'An address in this country needs its region.';

void main() {
  test('a site reads its region and prints it where its country places it', () {
    final s = Site.fromRow({
      'id': 's1',
      'street': 'Via Brera 7',
      'postal_code': '20121',
      'city': 'Milano',
      'country_code': 'IT',
      'subdivision': 'MI',
    });
    expect(s.subdivision, 'MI');
    expect(s.postalBlock, 'Via Brera 7\n20121 MILANO MI');
  });

  testWidgets('a site stored without its province keeps saving as it is', (
    tester,
  ) async {
    final results = await _open(tester, _brera);
    expect(find.text('Province'), findsOneWidget);
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(results.single?.draft.subdivision, '');
  });

  testWidgets('once its address is edited, the province is asked for', (
    tester,
  ) async {
    final results = await _open(tester, _brera);
    await tester.enterText(
      find.byKey(const ValueKey('site-street')),
      'Via Brera 9',
    );
    await tester.tap(_save);
    await tester.pump();
    expect(results, isEmpty);
    expect(find.text(_missing), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('site-region')));
    await tester.pumpAndSettle();
    // The first province by name, so the open list shows it.
    await tester.tap(find.text('Agrigento').last);
    await tester.pumpAndSettle();
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(results.single?.draft.subdivision, 'AG');
    expect(results.single?.draft.street, 'Via Brera 9');
  });

  // #4501 (WS-01) -- the country is picked from the catalogue and checked when it is saved; a stored one stays until changed
  testWidgets('a country outside the catalogue is refused when saved, a stored one is kept', (tester) async {
    final results = await _open(tester, _brera.copyWith(countryCode: 'ZZ'));
    expect(find.byKey(const ValueKey('site-country')), findsOneWidget);
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(results.single?.draft.countryCode, 'ZZ', reason: 'unchanged: it saves as it was');

    final again = await _open(tester, _brera);
    await tester.enterText(find.byKey(const ValueKey('site-country')), 'QQ');
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(again, isEmpty);
    expect(find.text('This is not in the list: pick one'), findsOneWidget);
  });
}
