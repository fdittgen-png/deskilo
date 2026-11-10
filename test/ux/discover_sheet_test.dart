// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step C -- the screenshot sheet of Discover: its start state, a list
// of places, a directory that did not answer, and a search with no result,
// light and dark at phone width. Without ME_SHEET=1 the test does nothing;
// run it like me_sheet_test.dart, with ME_SHEET=1 in the environment.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/core/theme/personal_theme.dart';
import 'package:deskilo/features/directory/domain/discovery_paging.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/directory_screen.dart';
import 'package:deskilo/features/directory/presentation/public_workspace_view.dart';
import 'package:deskilo/features/directory/providers/discovery_listing_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';

/// The Material icon font of the Flutter SDK running the test, found by
/// walking up from the tester executable; null when it is not there (the
/// sheet then shows empty squares for icons).
File? _materialIcons() {
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    final f = File('${dir.path}/material_fonts/MaterialIcons-Regular.otf');
    if (f.existsSync()) return f;
    final g = File(
      '${dir.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (g.existsSync()) return g;
    dir = dir.parent;
  }
  return null;
}

Future<void> _loadRoboto() async {
  final icons = _materialIcons();
  if (icons != null) {
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await iconLoader.load();
  }
  final loader = FontLoader('Roboto')
    ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
  await loader.load();
}

PublicWorkspace _card(String id, String name, [Map<String, dynamic>? more]) =>
    PublicWorkspace(id, 'https://a.example', 'k', {'name': name, ...?more});

final _atelier = _card('1', 'Atelier Nord', {
  'description': 'A quiet studio with six desks and a meeting room.',
  'email': 'hello@ateliernord.example',
  'phone': '+33 4 67 00 00 00',
  'address': '12 rue Haute, 34120 Pézenas',
  'host_type': 'company',
});
final _studio = _card('2', 'Studio Sud', {
  'address': '4 place Neuve, 75002 Paris',
  'host_type': 'association',
});

/// Two places loaded and one directory that did not answer.
class _PartlyAnswered extends DiscoveryListing {
  @override
  Future<DiscoveryResults> build(String query) async => DiscoveryResults(
    sources: [
      SourceListing(
        const DirectorySource('https://a.example', 'k'),
        status: SourceStatus.ready,
        cards: [_atelier, _studio],
      ),
    ],
    refused: const ['https://dead.example'],
  );
}

void main() {
  final enabled = Platform.environment['ME_SHEET'] == '1';
  testWidgets('render Discover to build/discover_sheet', (tester) async {
    await _loadRoboto();
    final out = Directory('build/discover_sheet')..createSync(recursive: true);
    final states = <String, FakeDirectoryRepository Function()>{
      'start': FakeDirectoryRepository.new,
      'results': () =>
          FakeDirectoryRepository()..cards.addAll([_atelier, _studio]),
      'one-directory-failed': () =>
          FakeDirectoryRepository()..cards.addAll([_atelier, _studio]),
      'all-failed': () => FakeDirectoryRepository()..fail = true,
      'no-match': () => FakeDirectoryRepository()..cards.add(_atelier),
    };
    for (final state in states.entries) {
      for (final dark in [false, true]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        // A fresh scope per picture: the providers of the last one are gone.
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              ...standardTestOverrides(
                auth: FakeAuthRepository.signedIn(),
                directory: state.value(),
              ),
              if (state.key == 'one-directory-failed')
                discoveryListingProvider.overrideWith2(
                  (_) => _PartlyAnswered(),
                ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData(colorSchemeSeed: Colors.deepPurple),
              darkTheme: ThemeData(
                colorSchemeSeed: Colors.deepPurple,
                brightness: Brightness.dark,
              ),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: const DirectoryScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (state.key == 'no-match') {
          await tester.enterText(
            find.byKey(const ValueKey('directory-portal-search-2')),
            'zzzz',
          );
          await tester.tap(
            find.byKey(const ValueKey('directory-portal-search')),
          );
          await tester.pumpAndSettle();
        }
        final target = tester.firstRenderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
        final image = await tester.runAsync(target.toImage);
        final bytes = await tester.runAsync(
          () => image!.toByteData(format: ui.ImageByteFormat.png),
        );
        File(
          '${out.path}/discover--${state.key}--${dark ? 'dark' : 'light'}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    debugPrint('discover sheet: ${out.path}');
  }, skip: !enabled);

  testWidgets('render a space page to build/discover_sheet', (tester) async {
    await _loadRoboto();
    final out = Directory('build/discover_sheet')..createSync(recursive: true);
    for (final dark in [false, true]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: standardTestOverrides(
            auth: FakeAuthRepository.signedIn(),
            directory: FakeDirectoryRepository()..cards.add(_atelier),
          ),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: personalThemeFrom(ThemeData()),
            darkTheme: personalThemeFrom(
              ThemeData(brightness: Brightness.dark),
            ),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: PublicWorkspaceView(workspace: _atelier, personal: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final target = tester.firstRenderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      final image = await tester.runAsync(target.toImage);
      final bytes = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.png),
      );
      File('${out.path}/space--${dark ? 'dark' : 'light'}.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }, skip: !enabled);
}
