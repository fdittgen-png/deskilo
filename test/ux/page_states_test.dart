// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4076 -- a records page's states are part of its row: empty, a failed read
// with Try again, and a refused read, each drawn through the shared state
// primitives (ReadFailureBanner, EmptyState), at one desk and one phone size.
// A failure is never drawn as an empty list, and a refusal says so in the
// words of the shared primitive. The pages: members, documents, purchases,
// invoices. Each state fails on a planted fault (the last test).
import 'package:deskilo/core/cache/read_failure.dart';
import 'package:deskilo/core/codes/pg_code.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_document.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../helpers/mock_providers.dart';
import 'experience_guards.dart';

/// The states a read can be in on a records page.
enum _State { empty, failed, refused }

Exception _error(_State state) => switch (state) {
  _State.refused => const PostgrestException(message: 'denied', code: PgCode.insufficientPrivilege),
  _ => Exception('the read failed'),
};

/// A records page and the read behind it, answering [state]. #4097 —
/// [empty] finds what the page draws for a read that held nothing: never
/// drawn for a failed or refused one.
typedef _Page = ({
  String path,
  String name,
  Override Function(_State) read,
  Finder Function() empty,
});

final List<_Page> _pages = [
  (
    path: '/members',
    name: 'members',
    read: (state) => workspaceMembersProvider.overrideWith(
      (ref) async => state == _State.empty ? const [] : throw _error(state),
    ),
    empty: () => find.text('No members yet.'),
  ),
  (
    path: '/documents',
    name: 'documents',
    read: (state) => workspaceDocumentsProvider.overrideWith(
      (ref) async => state == _State.empty
          ? const <WorkspaceDocument>[]
          : throw _error(state),
    ),
    empty: () => find.textContaining('No document yet.'),
  ),
  (
    path: '/money/purchases',
    name: 'purchases',
    read: (state) => purchasesProvider('ws-1').overrideWith(
      (ref) async => state == _State.empty
          ? const <PurchaseSummary>[]
          : throw _error(state),
    ),
    empty: () => find.text('No purchase yet.'),
  ),
  (
    path: '/invoices',
    name: 'invoices',
    read: (state) => invoicesProvider.overrideWith(
      (ref) async =>
          state == _State.empty ? const <Invoice>[] : throw _error(state),
    ),
    empty: () => find.byKey(const ValueKey('invoicing-empty')),
  ),
];

/// What a page breaks in a state: the words of the shared primitive missing,
/// a failure drawn as an empty list, or no way to read again.
Set<String> _stateProblems(_State state) {
  final problems = <String>{};
  // The two shared primitives that say a read failed: the banner of a list
  // and the failed row of a records table.
  final failed =
      find.text('This could not be loaded. Try again.').evaluate().isNotEmpty ||
      find.text('The list could not be read.').evaluate().isNotEmpty;
  final denied = find
      .text(
        'You do not have access to this. Ask a workspace administrator if you '
        'need it.',
      )
      .evaluate()
      .isNotEmpty;
  final retry = find.text('Try again').evaluate().isNotEmpty;
  switch (state) {
    case _State.empty:
      if (failed || denied) problems.add('empty drawn as a failure');
    case _State.failed:
      if (!failed) problems.add('failure without the shared words');
      if (!retry) problems.add('failure without Try again');
    case _State.refused:
      if (!denied) problems.add('refusal without the shared words');
      if (!retry) problems.add('refusal without Try again');
  }
  return problems;
}

Future<void> _show(
  WidgetTester tester,
  _Page page,
  _State state,
  Size size,
) async {
  final features = WorkspaceFeature.values.toSet();
  await pumpRoute(
    tester,
    page.path,
    size: size,
    overrides: [
      ...standardTestOverrides(
        workspace: FakeWorkspaceRepository.withWorkspace(
          featureFlags: {for (final f in features) f.name: true},
        ),
      ),
      enabledFeaturesSyncProvider.overrideWithValue(features),
      page.read(state),
    ],
  );
  // Riverpod retries a failed read: let the first answer settle.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

/// #4076 -- a state a page does not draw through the shared primitives yet:
/// `page|state|width` -> what it draws. Left out until the page is fixed
/// (the list only shrinks).
const Map<String, String> _stateFindings = {};

void main() {
  for (final page in _pages) {
    for (final size in const [Size(1440, 900), Size(390, 844)]) {
      for (final state in _State.values) {
        final key = '${page.name}|${state.name}|${size.width.toInt()}';
        testWidgets(
          '${page.path} at ${size.width.toInt()}: ${state.name} is drawn by '
          'the shared state primitives',
          skip: _stateFindings.containsKey(key),
          (tester) async {
            await _show(tester, page, state, size);
            expect(
              tester.takeException(),
              isNull,
              reason: 'the page does not throw',
            );
            expect(_stateProblems(state), isEmpty, reason: key);
            // #4097 — a failed or refused read is never an empty list; an
            // empty one draws the page's own mark. Not checked where the mark
            // is not the list's: the purchases page on a phone is a page of
            // doors, and the invoicing home's empty card waits until nothing
            // is to invoice either, which this space has.
            if (state != _State.empty) {
              expect(page.empty(), findsNothing, reason: '$key drawn as empty');
            } else if (page.name != 'invoices' &&
                (page.name != 'purchases' || size.width >= 1024)) {
              expect(page.empty(), findsWidgets, reason: '$key: its mark');
            }
          },
        );
      }
    }
  }

  test('every state finding is a state of the walk', () {
    final cases = {
      for (final page in _pages)
        for (final width in const [1440, 390])
          for (final state in _State.values)
            '${page.name}|${state.name}|$width',
    };
    expect(_stateFindings.keys.toSet().difference(cases), isEmpty);
  });

  // Each state fails on a planted fault: a failure drawn as an empty list, an
  // empty list drawn as a failure, a refusal in a plain failure's words.
  testWidgets('the state rule fails on planted faults', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Nothing here.'))),
    );
    expect(
      _stateProblems(_State.failed),
      containsAll(<String>[
        'failure without the shared words',
        'failure without Try again',
      ]),
    );
    expect(
      _stateProblems(_State.refused),
      contains('refusal without Try again'),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('This could not be loaded. Try again.')),
      ),
    );
    expect(_stateProblems(_State.empty), contains('empty drawn as a failure'));
    expect(
      _stateProblems(_State.refused),
      contains('refusal without the shared words'),
    );
    expect(classifyReadFailure(_error(_State.refused)), ReadFailure.denied);
    expect(classifyReadFailure(_error(_State.failed)), ReadFailure.other);
  });
}
