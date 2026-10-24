// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2558 — the privacy editor of the personal home: it reads my saved
// settings with no workspace at all, says so when it cannot read them
// (never the defaults dressed as saved), reads them again on request, and
// never drops a saved chosen space the list no longer names.
import 'dart:io';

import 'package:deskilo/features/me/domain/visibility.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

Future<GoRouter> _account(
  WidgetTester tester,
  FakeMeRepository me, {
  FakeWorkspaceRepository? workspace,
}) async {
  final router = await pumpMeApp(
    tester,
    workspace: workspace ?? FakeWorkspaceRepository(workspaces: []),
    me: me,
    extraOverrides: [personalShellEnabledProvider.overrideWithValue(true)],
  );
  await goTo(tester, router, '/me/account');
  await openMoreSharing(tester);
  return router;
}

Future<void> _open(WidgetTester tester, VisibilityField field) =>
    tapIn(tester, 'me-account-list', _key('visibility-field-${field.wire}'));

Future<void> _save(WidgetTester tester) async {
  await tester.tap(_key('visibility-save'));
  await tester.pumpAndSettle();
  final confirm = _key('visibility-widen-confirm');
  if (confirm.evaluate().isNotEmpty) {
    await tester.tap(confirm);
    await tester.pumpAndSettle();
  }
}

void main() {
  late FakeMeRepository me;
  setUp(() {
    me = FakeMeRepository(
      accounts: {
        'user-1': FakeAccount(name: 'Test User', email: 'test@example.com'),
      },
    );
  });

  testWidgets('with no space at all the saved settings are read and changed '
      'on the personal home', (tester) async {
    me.accounts['user-1']!.visibility = MyVisibility.defaults.withField(
      VisibilityField.about,
      const FieldAudience(VisibilityAudience.mySpaces),
    );
    await _account(tester, me);

    expect(_key('visibility-unavailable'), findsNothing);
    expect(
      find.descendant(
        of: _key('visibility-field-about'),
        matching: find.text('Members of my spaces'),
      ),
      findsOneWidget,
      reason: 'the saved value, not the default "nobody"',
    );

    await _open(tester, VisibilityField.identity);
    await tester.tap(_key('visibility-audience-signed_in'));
    await tester.pumpAndSettle();
    await _save(tester);
    expect(
      me.accounts['user-1']!.visibility.of(VisibilityField.identity).audience,
      VisibilityAudience.signedIn,
    );

    // "Chosen spaces" with no space says so and cannot be saved.
    await _open(tester, VisibilityField.presence);
    await tester.tap(_key('visibility-audience-chosen_spaces'));
    await tester.pumpAndSettle();
    expect(_key('visibility-no-spaces'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(_key('visibility-save')).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refused read names the failure, offers no field to change, '
      'and a retry shows the saved settings', (tester) async {
    me
      ..readFailure = const PostgrestException(message: 'unavailable')
      ..accounts['user-1']!.visibility = MyVisibility.defaults.withField(
        VisibilityField.about,
        const FieldAudience(VisibilityAudience.mySpaces),
      );
    await _account(tester, me);

    await tester.scrollUntilVisible(
      _key('visibility-unavailable'),
      200,
      scrollable: find
          .descendant(
            of: _key('me-account-list'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(_key('visibility-unavailable'), findsOneWidget);
    expect(
      find.text(
        'Who sees what of you cannot be read right now. '
        'Nothing was changed.',
      ),
      findsOneWidget,
    );
    expect(
      _key('visibility-field-about'),
      findsNothing,
      reason: 'no default is shown as if it were saved',
    );
    expect(_key('visibility-about-edit'), findsNothing);
    expect(_key('visibility-preview'), findsNothing);
    expect(
      me.visibilityReads,
      1,
      reason: 'an answer of the personal home is not asked again by itself',
    );

    me.readFailure = null;
    await tester.tap(
      find.descendant(
        of: _key('visibility-unavailable'),
        matching: find.text('Try again'),
      ),
    );
    await tester.pumpAndSettle();
    expect(_key('visibility-unavailable'), findsNothing);
    await openMoreSharing(tester);
    expect(
      find.descendant(
        of: _key('visibility-field-about'),
        matching: find.text('Members of my spaces'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a saved chosen space the list no longer names stays chosen '
      'until it is unticked', (tester) async {
    final gone = me.refOf('ws-gone');
    final here = me.refOf('ws-1');
    me.spaceLabels['ws-1'] = 'Test Space';
    me.accounts['user-1']!.visibility = MyVisibility.defaults.withField(
      VisibilityField.contactChannels,
      FieldAudience(VisibilityAudience.chosenSpaces, {gone}),
    );
    await _account(
      tester,
      me,
      workspace: FakeWorkspaceRepository.withWorkspace(),
    );

    await _open(tester, VisibilityField.contactChannels);
    expect(
      find.descendant(
        of: _key('visibility-space-$gone'),
        matching: find.text('A space that is no longer listed'),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<CheckboxListTile>(_key('visibility-space-$gone')).value,
      isTrue,
    );
    // Saving unchanged writes nothing and drops nothing.
    await _save(tester);
    expect(
      me.accounts['user-1']!.visibility
          .of(VisibilityField.contactChannels)
          .workspaces,
      {gone},
    );

    await _open(tester, VisibilityField.contactChannels);
    await tester.tap(_key('visibility-space-$gone'));
    await tester.tap(_key('visibility-space-$here'));
    await tester.pumpAndSettle();
    await _save(tester);
    expect(
      me.accounts['user-1']!.visibility
          .of(VisibilityField.contactChannels)
          .workspaces,
      {here},
    );
  });

  test('the privacy surfaces read no selected workspace', () {
    for (final path in [
      'lib/features/me/presentation/me_account_tab.dart',
      'lib/features/me/presentation/visibility_card.dart',
      'lib/features/me/presentation/visibility_flow.dart',
      'lib/features/me/presentation/visibility_preview.dart',
      'lib/features/me/presentation/public_profile_tile.dart',
      'lib/features/me/presentation/blocked_people_card.dart',
      'lib/features/me/presentation/linked_visibility_card.dart',
      'lib/features/me/providers/audience_spaces_provider.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('currentWorkspace')), reason: path);
      if (path.contains('/presentation/')) {
        expect(
          source,
          isNot(contains('workspace_providers.dart')),
          reason: '$path reads its spaces through the Me layer',
        );
      }
    }
  });
}
