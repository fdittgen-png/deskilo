// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2086 — the public listing starts from the workspace's own information.
// An inherited field (host type, address) follows it until the owner
// overrides it, the editor says which one it is, and the owner can always
// return to the workspace information, one field or all at once (after a
// confirmation). Saving leaves a following field out, so it keeps
// following; publishing stays the explicit switch. The SQL tests own
// authorization and the anonymous projection (123_public_page_defaults).
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/application/directory_actions.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/public_page_editor.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

const _ws = 'ws-1';

Future<void> _pumpEditor(
  WidgetTester tester,
  FakeDirectoryRepository repo,
) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        auth: FakeAuthRepository.signedIn(),
        directory: repo,
      ),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PublicPageEditor(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _status(String field, String text) => find.descendant(
  of: find.byKey(ValueKey('public-page-inherit-$field')),
  matching: find.text(text),
);

Finder get _address => find.widgetWithText(TextField, 'Public address');

Map<String, dynamic> _stored(FakeDirectoryRepository repo) =>
    repo.pages[_ws]!['document'] as Map<String, dynamic>;

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.text('Save and preview the external view'));
  await tester.pumpAndSettle();
  await tester.pageBack();
  await tester.pumpAndSettle();
}

FakeDirectoryRepository _repo() => FakeDirectoryRepository()
  ..local['address'] = '1 Local Street'
  ..local['host_type'] = 'association';

void main() {
  group('PublicationActions', () {
    test('a following inherited field is left out of the save, so it keeps '
        'following; a blank override is kept', () async {
      await const PublicationActions(_Recorder()).savePage(
        _ws,
        {'host_type': 'company', 'address': ' ', 'description': 'Desks'},
        false,
        following: {'host_type', 'description'},
      );
      expect(_Recorder.last, {'address': '', 'description': 'Desks'});
    });

    test('a host type is still checked when the owner sets one', () {
      expect(
        () =>
            const PublicationActions(_Recorder())
                .savePage(_ws, {'host_type': 'castle'}, false),
        throwsArgumentError,
      );
    });

    test('a reset names inherited fields only', () {
      const actions = PublicationActions(_Recorder());
      expect(
        () => actions.resetPage(_ws, fields: {'description'}),
        throwsArgumentError,
      );
      expect(() => actions.resetPage(_ws, fields: {}), throwsArgumentError);
    });

    test('publicFollowing reads the marker, and an older server follows '
        'nothing', () {
      expect(
        publicFollowing({
          'following': {'host_type': true, 'address': false, 'email': true},
        }),
        {'host_type'},
      );
      expect(publicFollowing({'published': true}), isEmpty);
    });
  });

  testWidgets('inherit: an unsaved page shows the workspace information and '
      'says where it comes from', (tester) async {
    await _pumpEditor(tester, _repo());
    expect(
      tester.widget<TextField>(_address).controller!.text,
      '1 Local Street',
    );
    expect(_status('address', 'From workspace information'), findsOneWidget);
    expect(_status('host_type', 'From workspace information'), findsOneWidget);
    expect(find.text('Association'), findsOneWidget);
    expect(find.text('Use workspace information'), findsNothing);
  });

  testWidgets('a field the owner did not touch is saved as following, so a '
      'later local edit reaches the page', (tester) async {
    final repo = _repo();
    await _pumpEditor(tester, repo);
    await tester.enterText(
      find.widgetWithText(TextField, 'Description'),
      'Open desks',
    );
    await _save(tester);
    expect(_stored(repo).containsKey('address'), isFalse);
    expect(_stored(repo).containsKey('host_type'), isFalse);
    repo.local['address'] = '2 New Street';
    expect((await repo.ownPage(_ws))['document']['address'], '2 New Street');
  });

  testWidgets('override: editing an inherited field marks it customised and '
      'saves it as the owner\'s value', (tester) async {
    final repo = _repo();
    await _pumpEditor(tester, repo);
    await tester.enterText(_address, 'Desk 9, Public Row');
    await tester.pump();
    expect(_status('address', 'Customised'), findsOneWidget);
    expect(_status('host_type', 'From workspace information'), findsOneWidget);
    await _save(tester);
    expect(_stored(repo)['address'], 'Desk 9, Public Row');
    repo.local['address'] = '2 New Street';
    expect(
      (await repo.ownPage(_ws))['document']['address'],
      'Desk 9, Public Row',
    );
  });

  testWidgets('reset one: "Use workspace information" returns that field '
      'only, and keeps an unsaved edit elsewhere', (tester) async {
    final repo = _repo();
    await repo.savePage(_ws, {
      'host_type': 'person',
      'address': 'Desk 9, Public Row',
    }, true);
    await _pumpEditor(tester, repo);
    expect(_status('address', 'Customised'), findsOneWidget);
    expect(_status('host_type', 'Customised'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Description'),
      'Unsaved text',
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('public-page-inherit-address')),
        matching: find.text('Use workspace information'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(_address).controller!.text,
      '1 Local Street',
    );
    expect(_status('address', 'From workspace information'), findsOneWidget);
    expect(_status('host_type', 'Customised'), findsOneWidget);
    expect(_stored(repo).containsKey('address'), isFalse);
    expect(_stored(repo)['host_type'], 'person');
    expect(find.text('Unsaved text'), findsOneWidget);
    expect(repo.pages[_ws]!['published'], isTrue, reason: 'never withdrawn');
  });

  testWidgets('reset all asks first; cancelling changes nothing, confirming '
      'returns every inherited field', (tester) async {
    final repo = _repo();
    await repo.savePage(_ws, {
      'host_type': 'person',
      'address': 'Desk 9, Public Row',
      'description': 'Kept',
    }, false);
    await _pumpEditor(tester, repo);
    await tester.tap(find.byKey(const ValueKey('public-page-reset-all')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(_stored(repo)['address'], 'Desk 9, Public Row');

    await tester.tap(find.byKey(const ValueKey('public-page-reset-all')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('public-page-reset-all-confirm')),
    );
    await tester.pumpAndSettle();
    expect(_stored(repo).keys, ['description']);
    expect(_status('address', 'From workspace information'), findsOneWidget);
    expect(_status('host_type', 'From workspace information'), findsOneWidget);
    expect(find.text('Association'), findsOneWidget);
    expect(
      tester.widget<TextField>(_address).controller!.text,
      '1 Local Street',
    );
    expect(repo.pages[_ws]!['published'], isFalse, reason: 'never published');
  });
}

/// Records what the actions hand the repository.
class _Recorder implements PublicationRepository {
  const _Recorder();
  static Map<String, String>? last;
  @override
  Future<Map<String, dynamic>> ownPage(String workspace) async => {};
  @override
  Future<Map<String, dynamic>> resetPage(
    String workspace, {
    Set<String>? fields,
  }) async => {};
  @override
  Future<Map<String, dynamic>> savePage(
    String workspace,
    Map<String, String> document,
    bool published,
  ) async {
    last = document;
    return {};
  }
}
