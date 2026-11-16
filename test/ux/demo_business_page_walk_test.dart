// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3554 PR 2 — the Demo walked to a business's page. Cabinet Garrigue takes
// inquiries and publishes services: Discover → Practices → its page, where
// "Get in touch" is the one filled action and a service opens an inquiry
// that names it, by name only, sent to the business the button names. La
// Fabrique des Halles takes no inquiries: its page offers to join and its
// e-mail to copy, and no message nobody would read.
import 'package:deskilo/core/demo/data/connected_installations.dart';
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/screens/demo_journeys.dart';
import '../helpers/screens/desk_calendar.dart' show goTo;

Future<void> _pumps(WidgetTester tester, [int times = 10]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// The taps a walk costs (the app's shell opens Discover, as the tap
/// budget counts it, #1247).
var _taps = 0;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  _taps++;
  await tester.tap(finder);
}

Future<void> _openListed(WidgetTester tester, String id) async {
  final view = find.byKey(
    ValueKey('directory-view-$kDemoServerOrigin/$id'),
    skipOffstage: false,
  );
  await tester.ensureVisible(view);
  await _tap(tester, view);
  await _pumps(tester);
}

/// The page's buttons that are filled.
int _filled() =>
    find.byWidgetPredicate((w) => w is FilledButton).evaluate().length;

void main() {
  testWidgets('a practice: Practices, its page, a service, and the inquiry '
      'names the service', (tester) async {
    final journey = await pumpDemo(
      tester,
      openHub: false,
      size: const Size(1440, 1600),
    );
    await goTo(tester, '/discover');
    _taps = 0;
    await _tap(tester, find.byKey(const ValueKey('directory-kind-practice')));
    await _pumps(tester);
    await _openListed(tester, 'demo-practice-garrigue');

    expect(find.text('Cabinet Garrigue'), findsWidgets);
    final contact = find.byKey(const ValueKey('write-to-hosts'));
    expect(tester.widget(contact), isA<FilledButton>());
    expect(
      find.descendant(of: contact, matching: find.text('Get in touch')),
      findsOneWidget,
    );
    expect(_filled(), 1, reason: 'one filled action');
    expect(find.text('Relaxing massage'), findsOneWidget);
    expect(
      find.text('Five massages'),
      findsOneWidget,
      reason:
          'the page '
          'lists every service the card left out',
    );

    final service = find.byKey(const ValueKey('public-workspace-service-0'));
    await tester.ensureVisible(service);
    await _tap(tester, service);
    await _pumps(tester, 5);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('inquiry-sheet')),
        matching: find.text('Inès Garrigue'),
      ),
      findsOneWidget,
      reason: 'who reads it',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('inquiry-send')),
        matching: find.text('Send to Cabinet Garrigue'),
      ),
      findsOneWidget,
    );
    await _tap(tester, find.byKey(const ValueKey('inquiry-send')));
    await _pumps(tester);

    final sent = journey.fixture.messenger.inboxRows.where(
      (row) => row['workspace_id'] == 'demo-practice-garrigue',
    );
    expect(sent, hasLength(1), reason: 'the inquiry lands in the fixture');
    expect(sent.single['context_kind'], MessageContextKind.inquiryOut.wire);
    expect(
      _taps + 1,
      lessThanOrEqualTo(5),
      reason:
          'a new person to a practice\'s service enquiry sent: Discover, '
          'Practices, the practice, the service, Send — budget 5 (#3554)',
    );
    expect(
      sent.single['last_body'],
      'Hello, I would like to know more about “Relaxing massage”.',
    );
    // The thread's capture shield asks the platform with a 5 s deadline,
    // on the way in and on the way out.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a business that takes no inquiries: join, its e-mail, no '
      'message', (tester) async {
    await pumpDemo(tester, openHub: false, size: const Size(1440, 1600));
    await goTo(tester, '/discover');
    await _openListed(tester, 'demo-halles');

    expect(find.text('La Fabrique des Halles'), findsWidgets);
    expect(
      tester.widget(find.byKey(const ValueKey('portal-request-membership'))),
      isA<FilledButton>(),
    );
    expect(_filled(), 1);
    expect(find.byKey(const ValueKey('write-to-hosts')), findsNothing);
    expect(find.byKey(const ValueKey('portal-copy-email')), findsOneWidget);
  });
}
