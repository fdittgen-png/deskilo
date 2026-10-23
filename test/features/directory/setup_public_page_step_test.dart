// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2871 — the public page step of the setup guide. The switch and the
// fields arrive as the stored page holds them; the preview is the space as
// the directory lists it and what its page says, and follows the typing
// before anything is saved. Saving publishes through the page editor's own
// write: the edited words and the switch are stored, a field this step
// does not show goes back as it was, and the address, which follows the
// workspace information, keeps following it. An unpublished page says that
// nobody outside sees it. One column on a phone.
import 'package:deskilo/app/routes/setup_run_pages.dart';
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 2400);

FakeDirectoryRepository _directory() => FakeDirectoryRepository()
  ..ownName = 'Test Space'
  ..local['address'] = '1 Market Street'
  ..pages['ws-1'] = {
    'published': false,
    'document': <String, dynamic>{
      'host_type': 'company',
      'description': 'Desks by the sea',
      'email': 'hello@example.org',
      'plans': 'Day pass, month',
    },
  };

Future<void> _pump(WidgetTester tester, FakeDirectoryRepository dir) async {
  await pumpApp(
    tester,
    const SetupStepScreen(stepId: 'public_page', runPages: setupRunPages),
    size: _phone,
    overrides: standardTestOverrides(directory: dir),
  );
  await tester.pumpAndSettle();
}

String _field(WidgetTester tester, String field) => tester
    .widget<TextField>(
      find.descendant(
        of: find.byKey(ValueKey('setup-public-page-$field')),
        matching: find.byType(TextField),
      ),
    )
    .controller!
    .text;

Finder _inPreview(Finder f) => find.descendant(
  of: find.byKey(const ValueKey('setup-step-preview')),
  matching: f,
);

void main() {
  testWidgets('prefilled from the stored page; the preview is the directory '
      'card and the page, and says it is not published', (tester) async {
    await _pump(tester, _directory());
    expect(_field(tester, 'description'), 'Desks by the sea');
    expect(_field(tester, 'email'), 'hello@example.org');
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('setup-public-page-published')),
          )
          .value,
      isFalse,
    );
    expect(
      find.byKey(const ValueKey('setup-public-page-unpublished')),
      findsOneWidget,
    );
    expect(_inPreview(find.text('Test Space')), findsOneWidget);
    expect(_inPreview(find.text('1 Market Street')), findsOneWidget);
    expect(_inPreview(find.text('Company')), findsOneWidget);
    expect(_inPreview(find.text('Desks by the sea')), findsOneWidget);
  });

  testWidgets('the preview follows the typing; saving publishes the words, '
      'keeps the rest and leaves the address following', (tester) async {
    final dir = _directory();
    await _pump(tester, dir);
    await tester.enterText(
      find.byKey(const ValueKey('setup-public-page-description')),
      'Quiet desks, fast wifi',
    );
    await tester.tap(find.byKey(const ValueKey('setup-public-page-published')));
    await tester.pump();
    expect(_inPreview(find.text('Quiet desks, fast wifi')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('setup-public-page-unpublished')),
      findsNothing,
    );
    expect(dir.pages['ws-1']!['published'], isFalse, reason: 'not saved yet');

    await tester.tap(find.byKey(const ValueKey('setup-public-page-save')));
    await tester.pumpAndSettle();
    final stored = dir.pages['ws-1']!;
    final doc = stored['document'] as Map<String, dynamic>;
    expect(stored['published'], isTrue);
    expect(doc['description'], 'Quiet desks, fast wifi');
    expect(doc['email'], 'hello@example.org');
    expect(doc['plans'], 'Day pass, month');
    expect(doc['host_type'], 'company');
    expect(doc.containsKey('address'), isFalse, reason: 'still following');
  });

  testWidgets('one column on a phone', (tester) async {
    await _pump(tester, _directory());
    expect(find.byKey(const ValueKey('setup-step-one-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
