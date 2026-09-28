// SPDX-License-Identifier: AGPL-3.0-or-later
// #1791: real UI affordances publish/search a page, opt into an account inbox
// and edit employment independently of permissions. SQL tests own authorization.
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/directory_screen.dart';
import 'package:deskilo/features/directory/presentation/account_messenger_screen.dart';
import 'package:deskilo/features/directory/presentation/member_employment_tile.dart';
import 'package:deskilo/features/directory/presentation/public_page_editor.dart';
import 'package:deskilo/l10n/app_localizations.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:deskilo/features/auth/presentation/screens/auth_screen.dart';
import 'package:deskilo/features/directory/presentation/directory_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<void> showPortal(
  WidgetTester tester,
  Widget child, {
  FakeDirectoryRepository? directory,
  FakeAccountContactRepository? contacts,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        auth: FakeAuthRepository.signedIn(),
        directory: directory,
        contacts: contacts,
      ),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _BlankTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=',
        ),
      );
}

void main() {
  testWidgets(
    'signed-out visitor can open public discovery from the existing sign-in form',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/auth',
        routes: [
          GoRoute(path: '/auth', builder: (_, state) => const AuthScreen()),
          GoRoute(
            path: '/discover',
            builder: (_, state) => const DirectoryScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: standardTestOverrides(auth: FakeAuthRepository()),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final entry = find.byKey(const ValueKey('auth-discover'));
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(DirectoryScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'map marker selects its public workspace without a network request',
    (tester) async {
      const workspace = PublicWorkspace('ws', 'https://host.example', '', {
        'name': 'Map office',
        'latitude': '48.86',
        'longitude': '2.35',
      });
      PublicWorkspace? selected;
      await showPortal(
        tester,
        Scaffold(
          body: DirectoryMap(
            workspaces: const [workspace],
            selected: null,
            onSelect: (value) => selected = value,
            tileProvider: _BlankTiles(),
          ),
        ),
      );
      await tester.tap(find.text('Map office'));
      await tester.pump();
      expect(selected, same(workspace));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('owner publishes and previews the same public page at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeDirectoryRepository();
    await showPortal(tester, const PublicPageEditor(), directory: repo);
    await tester.tap(find.byType(SwitchListTile));
    await tester.enterText(
      find.widgetWithText(TextField, 'Description'),
      'A welcoming office',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    final save = find.text('Save and preview the external view');
    await tester.scrollUntilVisible(
      save,
      400,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repo.pages.values.single['published'], isTrue);
    expect(find.text('A welcoming office'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'search and open public workspace shows owner and published details',
    (tester) async {
      final repo = FakeDirectoryRepository()
        ..cards.add(
          const PublicWorkspace(
            'space',
            'https://host.example',
            'sb_publishable_test',
            {
              'name': 'Quiet office',
              'address': '10 Main Street',
              'host_type': 'person',
              'contacts': [
                {'name': 'Alice', 'owner': true, 'available': false},
              ],
            },
          ),
        );
      await showPortal(tester, const DirectoryScreen(), directory: repo);
      await tester.enterText(find.byType(TextField), 'Quiet');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quiet office'));
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Private host'), findsOneWidget);
    },
  );
  testWidgets(
    'account messenger opt-in and private reply use account repository',
    (tester) async {
      final repo = FakeAccountContactRepository()
        ..people.add({'id': 'person', 'name': 'Alice'});
      await showPortal(tester, const AccountMessengerScreen(), contacts: repo);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(repo.available, isTrue);
      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Alice'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Hello from my account');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(repo.sent, [(recipient: 'person', body: 'Hello from my account')]);
      expect(find.text('Hello from my account'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('employment switch writes employment only', (tester) async {
    final repo = FakeAccountContactRepository();
    await showPortal(
      tester,
      const Scaffold(
        body: MemberEmploymentTile(member: 'admin', editable: true),
      ),
      contacts: repo,
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(repo.employed['admin'], isTrue);
  });
}
