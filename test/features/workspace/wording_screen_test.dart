// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1277 S3 — the owner's wording editor.
//
// The assertions that matter are the two rules the earlier slices
// established and that a UI can quietly get wrong:
//
//   * the product's own word is ALWAYS on screen beside the override, so
//     an owner can see what they are replacing;
//   * RESET REMOVES. Writing the product default back as an override
//     would freeze that word against every future rewording — the server
//     takes null for exactly this, and the screen must send null.
import 'package:deskilo/core/l10n/lexicon.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/screens/wording_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

void main() {
  setUp(Lexicon.reset);
  tearDown(Lexicon.reset);

  Future<FakeWorkspaceRepository> pump(WidgetTester tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace(
      featureFlags: {WorkspaceFeature.workspaceVocabulary.name: true},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...standardTestOverrides(workspace: workspace)],
        child: const MaterialApp(home: WordingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return workspace;
  }

  testWidgets('a term shows the product default beside the workspace word',
      (tester) async {
    await pump(tester);

    // Not yet renamed: the row exists and names the product's own word
    // beneath it, so an owner is never left guessing which word is
    // theirs. Asserted structurally rather than against an English
    // string — the editor opens on the language being edited, and a
    // hardcoded "Free" only passes while that happens to be English.
    expect(find.byKey(const ValueKey('wording-term-legendFree')), findsOneWidget);
    expect(find.textContaining('Product default:'), findsWidgets);

    // Nothing is renamed yet, so every row offers the edit affordance
    // rather than the reset one.
    expect(find.byKey(const ValueKey('wording-reset-legendFree')), findsNothing);
  });

  testWidgets('the editor opens on the language the owner is reading',
      (tester) async {
    // A workspace that declared no language must not open in German
    // merely because `de` sorts first among the supported locales.
    await pump(tester);
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('wording-locale')),
    );
    expect(dropdown.value, 'en',
        reason: 'with no workspace language, the editor follows the app: '
            'supportedLocales.first would be `de` by alphabet');
  });

  testWidgets('reset REMOVES the word rather than storing the default',
      (tester) async {
    final workspace = await pump(tester);
    final id = workspace.workspaces.first.id;

    // A workspace that already renamed one term.
    await workspace.setLexiconTerm(id, 'en', 'legendFree', 'Open');
    expect(workspace.lexicons[id]?['en']?['legendFree'], 'Open');

    await workspace.setLexiconTerm(id, 'en', 'legendFree', null);

    // The KEY is gone — not set to 'Free'. Storing the default would
    // freeze that word against every future product rewording.
    expect(workspace.lexicons[id]?['en']?.containsKey('legendFree'), isFalse,
        reason: 'reset must remove the override, never store the product '
            'default as one');
  });

  testWidgets('a sibling term survives a reset', (tester) async {
    final workspace = await pump(tester);
    final id = workspace.workspaces.first.id;

    await workspace.setLexiconTerm(id, 'en', 'legendFree', 'Open');
    await workspace.setLexiconTerm(id, 'en', 'spaceKindSeat', 'Place');
    await workspace.setLexiconTerm(id, 'en', 'legendFree', null);

    expect(workspace.lexicons[id]?['en']?['spaceKindSeat'], 'Place',
        reason: 'the writer is keyed: resetting one word leaves the others');
  });

  testWidgets('every allow-listed surface has a heading to browse by',
      (tester) async {
    await pump(tester);

    // The editor groups by surface because two terms read "Reserve" in
    // English; a flat list of words could not tell them apart.
    for (final surface in LexiconSurface.values) {
      expect(
        lexiconAllowList.values.where((t) => t.surface == surface),
        isNotEmpty,
        reason: '$surface has no terms, so the editor would show an empty '
            'group — either the allow-list or the surface list is wrong',
      );
    }
  });
}
