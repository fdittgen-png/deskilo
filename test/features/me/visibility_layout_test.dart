// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2558 — the privacy card's saved preview, its wide layout and a personal
// home without the checked writer. The preview is labelled "Saved preview"
// and shows only what the home confirmed: a change waiting for its widening
// question, a failed save or a refused one leaves it as it was, and a
// confirmed save refreshes it. On a wide window the editor and the preview
// sit side by side (60:40); otherwise the preview follows the editor. A
// home without `set_visibility_if_unchanged_network_v1` (PGRST202 / 42883)
// is named as such, writes nothing and falls back to no other writer.
import 'package:deskilo/features/me/data/visibility_rpc.dart';
import 'package:deskilo/features/me/domain/visibility_write.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

Future<void> _account(
  WidgetTester tester,
  FakeMeRepository me, {
  Size size = const Size(800, 1600),
}) async {
  final router = await pumpMeApp(
    tester,
    workspace: FakeWorkspaceRepository(workspaces: []),
    me: me,
    size: size,
    extraOverrides: [personalShellEnabledProvider.overrideWithValue(true)],
  );
  await goTo(tester, router, '/me/account');
}

/// Contact details to the one chosen space ws-1, up to the widening
/// question (left open).
Future<void> _pickAtelier(WidgetTester tester, FakeMeRepository me) async {
  await tapIn(
    tester,
    'me-account-list',
    _key('visibility-field-contact_channels'),
  );
  await _tap(tester, 'visibility-audience-chosen_spaces');
  await _tap(tester, 'visibility-space-${me.refOf('ws-1')}');
  await _tap(tester, 'visibility-save');
}

/// The saved preview (as somebody in my spaces) shows my e-mail address.
bool _previewShowsEmail() =>
    _key('visibility-preview-email').evaluate().isNotEmpty;

void main() {
  late FakeMeRepository me;
  setUp(() {
    me = FakeMeRepository(
      accounts: {
        'user-1': FakeAccount(
          name: 'Test User',
          email: 'test@example.com',
          spaces: {'ws-1'},
        ),
      },
      spaceLabels: {'ws-1': 'Atelier'},
    );
  });

  group('the saved preview', () {
    testWidgets('is labelled, keeps the saved state while a change waits, '
        'and refreshes after the confirmed save', (tester) async {
      await _account(tester, me);
      expect(_key('visibility-preview-saved'), findsOneWidget);
      expect(find.text('Saved preview'), findsOneWidget);
      expect(_previewShowsEmail(), isFalse, reason: 'contact is "nobody"');

      await _pickAtelier(tester, me);
      // The widening question is open: the draft is not in the preview.
      expect(_key('visibility-widen-confirm'), findsOneWidget);
      expect(_previewShowsEmail(), isFalse);

      await _tap(tester, 'visibility-widen-confirm');
      expect(me.visibilityWrites, 1);
      expect(_previewShowsEmail(), isTrue,
          reason: 'the confirmed save re-reads the preview');
    });

    testWidgets('a failed save leaves the preview as it was', (tester) async {
      await _account(tester, me);
      me.failure = Exception('the home refused the write');
      await _pickAtelier(tester, me);
      await _tap(tester, 'visibility-widen-confirm');
      expect(
        find.text('Could not save who sees this. Please try again.'),
        findsOneWidget,
      );
      expect(me.visibilityWrites, 0);
      expect(_previewShowsEmail(), isFalse);
    });
  });

  group('the wide layout', () {
    testWidgets('a wide window puts the saved preview beside the editor', (
      tester,
    ) async {
      await _account(tester, me, size: const Size(1440, 1600));
      expect(_key('visibility-wide'), findsOneWidget);
      final editor = tester.getRect(_key('visibility-field-contact_channels'));
      final preview = tester.getRect(_key('visibility-preview'));
      expect(preview.left, greaterThanOrEqualTo(editor.right));
      // 60:40.
      final row = tester.getRect(_key('visibility-wide'));
      expect(editor.width / row.width, closeTo(0.6, 0.01));
      // The other rows keep their reading width.
      expect(tester.getRect(_key('me-sign-out')).width, lessThanOrEqualTo(760));
    });

    testWidgets('a narrow window stacks the preview under the editor', (
      tester,
    ) async {
      await _account(tester, me, size: const Size(390, 1600));
      expect(_key('visibility-wide'), findsNothing);
      final editor = tester.getRect(_key('visibility-field-contact_channels'));
      final preview = tester.getRect(_key('visibility-preview'));
      expect(preview.top, greaterThan(editor.bottom));
    });
  });

  group('a personal home without the checked writer', () {
    testWidgets('says so, writes nothing and tries no other writer; once '
        'updated the same change saves', (tester) async {
      await _account(tester, me);
      me.failure = const VisibilityUnsupported();
      await _pickAtelier(tester, me);
      await _tap(tester, 'visibility-widen-confirm');
      expect(
        find.text(
          'Your personal home cannot save this setting yet: the people who '
          'run it need to update it. Nothing was changed.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Could not save who sees this. Please try again.'),
        findsNothing,
        reason: 'not reported as a failed save',
      );
      expect(_key('visibility-conflict'), findsNothing);
      expect(me.visibilityWrites, 0);
      expect(_previewShowsEmail(), isFalse);

      // Recovery: the home is updated, the same change goes through.
      me.failure = null;
      await tester.pump(const Duration(seconds: 5));
      await _pickAtelier(tester, me);
      await _tap(tester, 'visibility-widen-confirm');
      expect(me.visibilityWrites, 1);
      expect(_previewShowsEmail(), isTrue);
    });

    test('PGRST202 and 42883 are unsupported, PT409 a conflict, any other '
        'refusal stays the server\'s', () {
      PostgrestException refusal(String code, [String message = 'x']) =>
          PostgrestException(message: message, code: code);
      expect(visibilityWriteRefusal(refusal('PGRST202')),
          isA<VisibilityUnsupported>());
      expect(visibilityWriteRefusal(refusal('42883')),
          isA<VisibilityUnsupported>());
      expect(visibilityWriteRefusal(refusal('PT409')),
          isA<VisibilityConflict>());
      expect(visibilityWriteRefusal(refusal('P0001', 'visibility_conflict')),
          isA<VisibilityConflict>());
      expect(visibilityWriteRefusal(refusal('42501', 'permission denied')),
          isNull);
      expect(visibilityWriteRefusal(refusal('P0001', 'stale_fact')), isNull);
    });
  });
}
