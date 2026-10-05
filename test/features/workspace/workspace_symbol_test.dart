// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A workspace's symbol: one or two letters on a colour, round, unique as a
// pair. A taken pair is refused with the advice to change colour or use a
// photo.
import 'package:deskilo/features/workspace/domain/workspace_branding.dart';
import 'package:deskilo/features/workspace/presentation/screens/colours_screen.dart';
import 'package:deskilo/features/workspace/presentation/widgets/workspace_avatar.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Widget _app(FakeWorkspaceRepository repo, Widget home) => ProviderScope(
      overrides: standardTestOverrides(workspace: repo),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

FakeWorkspaceRepository _repo() {
  final repo = FakeWorkspaceRepository.withWorkspace(
    featureFlags: const {'workspaceBranding': true},
  );
  repo.workspaces.add(
    repo.workspaces.first.copyWith(
      id: 'ws-2',
      name: 'Other',
      branding: const {
        BrandingKeys.symbolText: 'AB',
        BrandingKeys.symbolColor: '#C2410C',
      },
    ),
  );
  return repo;
}

void main() {
  testWidgets('a workspace with a symbol and no photo shows its letters on '
      'its colour', (tester) async {
    final repo = _repo();
    final ws = repo.workspaces.last;
    await tester.pumpWidget(_app(repo, Scaffold(body: WorkspaceAvatar(workspace: ws))));
    await tester.pumpAndSettle();
    expect(find.text('AB'), findsOneWidget);
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundColor, const Color(0xFFC2410C));
  });

  testWidgets('the same letters on a taken colour are refused with the photo '
      'advice; another colour is accepted', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _repo();
    await tester.pumpWidget(_app(repo, const ColoursScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('symbol-letters')), 'ab');
    await tester.tap(find.byKey(const ValueKey('symbol-colour-#C2410C')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('symbol-save')));
    await tester.tap(find.byKey(const ValueKey('symbol-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('already uses these letters'), findsOneWidget);
    expect(WorkspaceSymbol.of(repo.workspaces.first.branding), isNull);

    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.tap(find.byKey(const ValueKey('symbol-colour-#0369A1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('symbol-save')));
    await tester.pumpAndSettle();
    final mine = WorkspaceSymbol.of(repo.workspaces.first.branding);
    expect(mine?.text, 'AB');
    expect(mine?.colourHex, '#0369A1');
  });

  test('a stored symbol needs letters and a readable colour', () {
    expect(WorkspaceSymbol.of(const {}), isNull);
    expect(
      WorkspaceSymbol.of(const {BrandingKeys.symbolText: 'X'}),
      isNull,
    );
    expect(
      WorkspaceSymbol.of(const {
        BrandingKeys.symbolText: 'X',
        BrandingKeys.symbolColor: '#0F766E',
      })?.text,
      'X',
    );
  });
}
