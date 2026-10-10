// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2343 — linking a server to the global directory says where the server
// stands before anything is written, links only what can be linked, and,
// when the account has no session on the reference server, says so and
// offers to connect it instead of failing in general terms. The Home
// menu of a space names the server it lives on.
import 'package:deskilo/core/backend/backend_config.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installation_providers.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/demo/data/connected_installations.dart';
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/core/ui/server_label.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/connection_dialog.dart';
import 'package:deskilo/features/directory/presentation/directory_link_dialog.dart';
import 'package:deskilo/features/directory/providers/directory_providers.dart';
import 'package:deskilo/features/me/presentation/space_row_controls.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _server = BackendEndpoint(
  'https://own.example',
  'sb_publishable_own_key',
);

/// The directory, refusing a link the way the real one does without a
/// session on the reference server.
class _NoAccount extends FakeDirectoryRepository {
  @override
  Future<void> register(String origin, String key) async =>
      throw ConnectionFailure(
        BackendConfig.referenceUrl,
        ConnectionFailureReason.notConnected,
      );
}

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _pump(WidgetTester tester, FakeDirectoryRepository repo) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        directoryParticipantRepositoryProvider.overrideWith((ref) => repo),
        publicDiscoveryRepositoryProvider.overrideWith((ref) => repo),
        connectedInstallationsProvider.overrideWith(
          (ref) => FakeConnectedInstallations(),
        ),
        enabledFeaturesSyncProvider.overrideWithValue(const {}),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DirectoryLinkDialog(initial: _server)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

VoidCallback? _onPressed(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(_key(key)).onPressed;

void main() {
  testWidgets('a server is checked first, linked once it can be, and then '
      'said to be linked', (tester) async {
    final repo = FakeDirectoryRepository();
    await _pump(tester, repo);
    expect(
      _onPressed(tester, 'directory-link-save'),
      isNull,
      reason: 'nothing is linked before its standing is known',
    );
    await _tap(tester, 'directory-link-check');
    expect(_key('directory-link-state-linkable'), findsOneWidget);
    await _tap(tester, 'directory-link-save');
    expect(repo.linked, [_server.url]);
    expect(_key('directory-link-state-linked'), findsOneWidget);
    expect(_onPressed(tester, 'directory-link-save'), isNull);
  });

  testWidgets('a server that cannot be linked yet is said so, and offers no '
      'link', (tester) async {
    final repo = FakeDirectoryRepository()
      ..unlinked = DirectoryLinkState.unreachable;
    await _pump(tester, repo);
    await _tap(tester, 'directory-link-check');
    expect(_key('directory-link-state-unreachable'), findsOneWidget);
    expect(_onPressed(tester, 'directory-link-save'), isNull);
  });

  testWidgets('an edit forgets what was known about the previous server', (
    tester,
  ) async {
    await _pump(tester, FakeDirectoryRepository());
    await _tap(tester, 'directory-link-check');
    await tester.enterText(
      _key('directory-link-url'),
      'https://another.example',
    );
    await tester.pump();
    expect(_key('directory-link-state-linkable'), findsNothing);
    expect(_onPressed(tester, 'directory-link-save'), isNull);
  });

  testWidgets('without an account on the reference server, the dialog says '
      'so and offers to connect it', (tester) async {
    await _pump(tester, _NoAccount());
    await _tap(tester, 'directory-link-check');
    await _tap(tester, 'directory-link-save');
    expect(
      find.text(
        'A link is recorded on the reference server: connect your account '
        'there first.',
      ),
      findsOneWidget,
    );
    await _tap(tester, 'directory-link-connect');
    final dialog = tester.widget<ConnectionDialog>(
      find.byType(ConnectionDialog),
    );
    expect(dialog.origin, BackendConfig.referenceUrl);
    expect(dialog.publicKey, BackendConfig.referenceKey);
  });

  group('the server a space lives on', () {
    test('the reference server is named; any other by its host', () {
      final l10n = AppLocalizationsEn();
      expect(
        serverLabel(l10n, BackendConfig.referenceUrl),
        'reference server (${Uri.parse(BackendConfig.referenceUrl).host})',
      );
      expect(serverLabel(l10n, 'https://own.example'), 'own.example');
    });

    testWidgets('the space menu says it first, and it cannot be chosen', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SpaceRowControls(
              rowKey: 'r',
              name: 'Atelier',
              favorite: false,
              rating: null,
              onFavorite: () {},
              onRate: (_) {},
              hostedOn: 'own.example',
            ),
          ),
        ),
      );
      await tester.tap(_key('space-menu-r'));
      await tester.pumpAndSettle();
      expect(find.text('Server: own.example'), findsOneWidget);
      expect(
        tester.widget<PopupMenuItem<String>>(_key('space-menu-r-host')).enabled,
        isFalse,
      );
    });
  });
}
