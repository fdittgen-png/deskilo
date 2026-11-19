// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Cards and public pages compare the facts the business publishes, keep
// unknown accessibility honest and keep the existing named actions usable.
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/directory_row.dart';
import 'package:deskilo/features/directory/presentation/public_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

PublicWorkspace _place({Map<String, dynamic> facts = const {}}) =>
    PublicWorkspace('office', 'https://host.example', '', {
      'name': 'Atelier Nord',
      'description': 'A quiet studio above the market.',
      'address': '12 rue Haute, 34120 Pézenas',
      'host_type': 'company',
      'kinds': ['coworking'],
      ...facts,
    });

const _facts = <String, dynamic>{
  'amenities': ['wifi', 'meeting_room'],
  'accessibility': ['step_free_entrance'],
  'opening_hours': {
    'weekdays': [1, 2, 3, 4, 5],
    'start_minutes': 480,
    'end_minutes': 1080,
    'timezone': 'Europe/Paris',
  },
  'takes_inquiries': true,
  'plans': 'Please contact the host before bringing equipment.',
};

Future<void> _pump(WidgetTester tester, Widget child) async {
  await pumpApp(
    tester,
    Scaffold(body: SingleChildScrollView(child: child)),
    size: const Size(390, 1200),
    overrides: standardTestOverrides(),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a comparison card names facilities, accessibility and regular hours',
    (tester) async {
      var views = 0;
      await _pump(
        tester,
        DirectoryRow(
          workspace: _place(facts: _facts),
          selected: false,
          onView: () => views++,
          onLocate: () {},
        ),
      );
      expect(find.textContaining('Wi-Fi'), findsOneWidget);
      expect(find.textContaining('Step-free entrance'), findsOneWidget);
      expect(find.textContaining('Europe/Paris'), findsOneWidget);
      expect(find.text('Accepts inquiries'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'View'));
      expect(views, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a public page groups published facts and keeps owner prose', (
    tester,
  ) async {
    await pumpApp(
      tester,
      PublicWorkspaceView(workspace: _place(facts: _facts), preview: true),
      size: const Size(768, 1500),
      overrides: standardTestOverrides(),
    );
    await tester.pumpAndSettle();
    for (final section in [
      'overview',
      'amenities',
      'accessibility',
      'hours',
      'information',
    ]) {
      expect(find.byKey(ValueKey('public-profile-$section')), findsOneWidget);
    }
    expect(find.text('Wi-Fi, Meeting room'), findsOneWidget);
    expect(find.text('Step-free entrance'), findsOneWidget);
    expect(find.text(_facts['plans'] as String), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing or malformed accessibility is unknown, never inaccessible',
    (tester) async {
      for (final facts in <Map<String, dynamic>>[
        {},
        {
          'accessibility': ['unknown-id'],
        },
        {'accessibility': <String>[]},
      ]) {
        await pumpApp(
          tester,
          PublicWorkspaceView(workspace: _place(facts: facts), preview: true),
          size: const Size(390, 1500),
          overrides: standardTestOverrides(),
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('public-profile-accessibility')),
            matching: find.text('Not published'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Not accessible'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('an unsafe or absent public picture uses a neutral initial', (
    tester,
  ) async {
    await _pump(
      tester,
      DirectoryRow(
        workspace: _place(
          facts: {'image_url': 'http://host.example/photo.jpg'},
        ),
        selected: false,
        onView: () {},
        onLocate: () {},
      ),
    );
    expect(
      find.byKey(
        const ValueKey('directory-picture-https://host.example/office-initial'),
      ),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('a failed HTTPS picture keeps a neutral initial and View', (
    tester,
  ) async {
    var viewed = false;
    await _pump(
      tester,
      DirectoryRow(
        workspace: _place(
          facts: {'image_url': 'https://host.example/photo.jpg'},
        ),
        selected: false,
        onView: () => viewed = true,
        onLocate: () {},
      ),
    );
    // Widget-test HTTP rejects the image request; the card remains usable.
    expect(
      find.byKey(
        const ValueKey('directory-picture-https://host.example/office-initial'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'View'));
    expect(viewed, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'a failed source labels retained information and retry refreshes that source',
    (tester) async {
      final card = _place(facts: _facts);
      final repository = FakeDirectoryRepository()
        ..cards.add(card)
        ..fail = true;
      await pumpApp(
        tester,
        PublicWorkspaceView(workspace: card),
        size: const Size(768, 1500),
        overrides: standardTestOverrides(directory: repository),
      );
      await tester.pumpAndSettle();
      expect(find.text('A quiet studio above the market.'), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('portal-request-membership')))
            .dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('public-profile-overview')))
              .dy,
        ),
      );
      final retry = find.byKey(const ValueKey('public-profile-retry'));
      expect(retry, findsOneWidget);
      repository.fail = false;
      repository.cards
        ..clear()
        ..add(
          _place(
            facts: {..._facts, 'description': 'Updated public information.'},
          ),
        );
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('Updated public information.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('public-profile-refresh-notice')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
