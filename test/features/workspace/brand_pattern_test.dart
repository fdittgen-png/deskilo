// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — a space's colour pattern and its logo: the owner picks a
// pattern, the space is told apart by it on Me and on its chip, and its
// logo shows while it opens — each by the space's OWN branding flag.
import 'dart:typed_data';

import 'package:deskilo/features/workspace/domain/workspace_branding.dart';
import 'package:deskilo/features/workspace/presentation/screens/colours_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../me/me_app.dart';

Future<FakeWorkspaceRepository> _pumpColours(
  WidgetTester tester, {
  Map<String, dynamic> branding = const {},
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository.withWorkspace(
    featureFlags: const {'workspaceBranding': true},
  );
  workspace.workspaces[0] = workspace.workspaces[0].copyWith(
    branding: branding,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ColoursScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return workspace;
}

/// ws-2 wears a colour, a pattern and a logo; [branded] says whether its
/// own branding flag is on.
FakeWorkspaceRepository _brandedSecond({required bool branded}) {
  final repo = twoSpaces();
  final i = repo.workspaces.indexWhere((w) => w.id == 'ws-2');
  repo.workspaces[i] = repo.workspaces[i].copyWith(
    featureFlags: {'workspaceBranding': branded},
    branding: const {'seed_color': '#0F766E', 'pattern': 'stripes'},
  );
  repo.emblems['ws-2'] = Uint8List.fromList(const [1, 2, 3, 4]);
  return repo;
}

void main() {
  group('the stored pattern', () {
    test('reads the curated values and nothing else', () {
      expect(BrandPattern.fromWire('dots'), BrandPattern.dots);
      expect(BrandPattern.fromWire('plaid'), isNull);
      expect(BrandPattern.fromWire(3), isNull);
      expect(
        WorkspaceBranding.fromJson(const {'pattern': 'waves'}).pattern,
        BrandPattern.waves,
      );
      expect(WorkspaceBranding.fromJson(const {}).pattern, isNull);
      expect(
        WorkspaceBranding.fromJson(const {'pattern': 'grid'}).isEmpty,
        isFalse,
      );
    });
  });

  testWidgets('the owner picks a pattern; Plain removes it', (tester) async {
    final workspace = await _pumpColours(
      tester,
      branding: const {'seed_color': '#1F3A5F'},
    );
    final dots = find.byKey(const ValueKey('colours-pattern-dots'));
    await tester.ensureVisible(dots);
    await tester.tap(dots);
    await tester.pumpAndSettle();
    expect(workspace.brandings['ws-1'], {
      'seed_color': '#1F3A5F',
      'pattern': 'dots',
    });

    final plain = find.byKey(const ValueKey('colours-pattern-solid'));
    await tester.ensureVisible(plain);
    await tester.tap(plain);
    await tester.pumpAndSettle();
    expect(workspace.brandings['ws-1'], {
      'seed_color': '#1F3A5F',
    }, reason: 'a plain fill is no pattern at all, never a stored "solid"');
  });

  testWidgets('on Me, a branded space wears its band, and its logo shows '
      'while it opens', (tester) async {
    final router = await pumpMeApp(
      tester,
      workspace: _brandedSecond(branded: true),
    );
    await goTo(tester, router, '/me');
    expect(find.byKey(const ValueKey('me-space-brand')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('me-space-ws-2')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byKey(const ValueKey('space-entry-curtain')), findsOneWidget);
    expect(find.byKey(const ValueKey('space-entry-fill')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('space-entry-logo')),
      findsOneWidget,
      reason: 'the logo is held on the covered screen',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('space-entry-curtain')), findsNothing);
    expect(router.state.uri.path, '/reserve');
    expect(find.byKey(const ValueKey('space-chip-brand')), findsOneWidget);
  });

  testWidgets('a space whose branding is off shows neither band nor logo', (
    tester,
  ) async {
    final router = await pumpMeApp(
      tester,
      workspace: _brandedSecond(branded: false),
    );
    await goTo(tester, router, '/me');
    expect(find.byKey(const ValueKey('me-space-brand')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('me-space-ws-2')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('space-entry-logo')), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('space-chip-brand')), findsNothing);
  });
}
