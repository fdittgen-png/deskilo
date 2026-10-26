// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2571 -- the reset deletes the books only when their retention allows it.
// When the server refuses (DKE01), the owner reads, in their language, that
// nothing was deleted and why: until when, under which rule, or which hold.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/mock_providers.dart';
import '../../helpers/screens/workspace_settings_screen.dart' show pumpWorkspaceSettings;

class _RetainedBooks extends FakeWorkspaceRepository {
  _RetainedBooks(this.assessment) : super.withWorkspace();

  final Map<String, Object?> assessment;

  @override
  Future<void> resetWorkspace(String workspaceId) async {
    resetWorkspaceCalls.add(workspaceId);
    throw PostgrestException(
      message: 'retention: the books of this space are kept ...',
      code: 'DKE01',
      details: jsonEncode(assessment),
    );
  }
}

Future<void> _reset(WidgetTester tester, FakeWorkspaceRepository repository) async {
  await pumpWorkspaceSettings(tester, repository: repository);
  final resetTile = find.byKey(const Key('workspaceSettingsReset'));
  await tester.ensureVisible(resetTile);
  await tester.tap(resetTile);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('workspaceResetConfirmField')), 'I AGREE');
  await tester.pump();
  await tester.tap(find.byKey(const Key('workspaceResetConfirm')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a reset inside the clock says nothing was deleted, until when '
      'and under which rule', (tester) async {
    final repository = _RetainedBooks({
      'disposition': 'retain',
      'retain_until': '2036-12-31',
      'indefinite': false,
      'rule': {'source': 'Abgabenordnung §147'},
      'holds': <Object?>[],
      'reasons': ['unconfirmed'],
    });
    await _reset(tester, repository);
    expect(repository.resetWorkspaceCalls, ['ws-1']);
    expect(
      find.text('Nothing was deleted: the books must still be kept. '
          'Kept until Dec 31, 2036 under Abgabenordnung §147'),
      findsOneWidget,
    );
    expect(find.text('Workspace reset.'), findsNothing);
  });

  testWidgets('a reset under a hold names the hold', (tester) async {
    await _reset(
      tester,
      _RetainedBooks({
        'disposition': 'retain',
        'retain_until': '2021-06-01',
        'indefinite': true,
        'rule': null,
        'holds': [
          {'reason': 'tax audit 2026'},
        ],
        'reasons': <Object?>[],
      }),
    );
    expect(
      find.text('Nothing was deleted: the books must still be kept. '
          'Kept under a legal hold: tax audit 2026'),
      findsOneWidget,
    );
  });
}
