// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3554 — a business's page: what it offers decides its one filled action,
// never its kind; the kind only chooses the words. Its services are listed
// by category, and where it takes inquiries a service opens one that names
// it — by name only — sent to a business the send button names. Never more
// than two buttons, exactly one filled.
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/public_services_section.dart';
import 'package:deskilo/features/directory/presentation/public_workspace_view.dart';
import 'package:deskilo/features/directory/presentation/space_offers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

const _origin = 'https://demo.invalid';

const _massage = {
  'name': 'Relaxing massage',
  'category': 'Massages',
  'duration_minutes': 60,
  'price_minor': 6500,
  'currency': 'EUR',
  'tax_treatment': 'none',
};
const _back = {
  'name': 'Back massage',
  'category': 'Massages',
  'duration_minutes': 30,
  'price_minor': 4000,
  'currency': 'EUR',
  'tax_treatment': 'none',
};
const _voucher = {
  'name': 'Gift voucher',
  'price_minor': 5000,
  'currency': 'EUR',
  'tax_treatment': 'none',
};
const _reflexology = {
  'name': 'Foot reflexology',
  'category': 'Reflexology',
  'duration_minutes': 45,
  'price_minor': 5500,
  'currency': 'EUR',
  'tax_treatment': 'none',
};

PublicWorkspace _business({
  List<String> kinds = const ['practice'],
  List<Map<String, Object?>> services = const [],
  bool? takesInquiries,
  String email = '',
  String phone = '',
}) => PublicWorkspace('ws-practice', _origin, 'key', {
  'name': 'Cabinet Garrigue',
  'host_type': 'person',
  'kinds': kinds,
  'services': services,
  'takes_inquiries': ?takesInquiries,
  'email': email,
  'phone': phone,
});

Future<void> _pump(
  WidgetTester tester,
  PublicWorkspace business, {
  FakeMessengerRepository? messenger,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: standardTestOverrides(
        messenger: messenger ?? FakeMessengerRepository(),
        directory: FakeDirectoryRepository()..cards.add(business),
      ),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) {
            ref.watch(authStateProvider);
            return PublicWorkspaceView(workspace: business);
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The page's action buttons, in order.
List<ButtonStyleButton> _buttons(WidgetTester tester) => tester
    .widgetList<ButtonStyleButton>(
      find.descendant(
        of: find.byType(SpaceOffers),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    )
    .toList();

/// Never more than two buttons, exactly one filled.
void _expectOneFilled(WidgetTester tester) {
  final buttons = _buttons(tester);
  expect(buttons.length, lessThanOrEqualTo(2));
  expect(buttons.whereType<FilledButton>(), hasLength(1));
}

const _join = ValueKey('portal-request-membership');
const _write = ValueKey('write-to-hosts');

void main() {
  testWidgets('(b) a business that takes no inquiries shows one true action: '
      'Ask to join, no message, its services as plain text', (tester) async {
    await _pump(
      tester,
      _business(
        services: [_massage],
        takesInquiries: false,
        email: 'cabinet@garrigue.example',
      ),
    );
    expect(tester.widget(find.byKey(_join)), isA<FilledButton>());
    expect(find.byKey(_write), findsNothing);
    expect(find.byKey(const ValueKey('portal-copy-email')), findsOneWidget);
    _expectOneFilled(tester);
    final row = find.byKey(const ValueKey('public-workspace-service-0'));
    expect(find.descendant(of: row, matching: find.text('Ask')), findsNothing);
    expect(
      tester
          .widget<ListTile>(
            find.descendant(of: row, matching: find.byType(ListTile)),
          )
          .onTap,
      isNull,
    );
  });

  testWidgets('(c) a practice that takes inquiries and publishes services is '
      'reached by "Get in touch" first; Ask to join is outlined', (
    tester,
  ) async {
    await _pump(tester, _business(services: [_massage], takesInquiries: true));
    final buttons = _buttons(tester);
    expect(buttons.first.key, _write);
    expect(buttons.first, isA<FilledButton>());
    expect(
      find.descendant(
        of: find.byKey(_write),
        matching: find.text('Get in touch'),
      ),
      findsOneWidget,
    );
    expect(tester.widget(find.byKey(_join)), isA<OutlinedButton>());
    _expectOneFilled(tester);
    expect(find.byKey(const ValueKey('portal-copy-email')), findsNothing);
  });

  testWidgets('(c) at a coworking space the same inquiry keeps its words', (
    tester,
  ) async {
    await _pump(
      tester,
      _business(
        kinds: const ['coworking'],
        services: [_massage],
        takesInquiries: true,
      ),
    );
    expect(tester.widget(find.byKey(_write)), isA<FilledButton>());
    expect(
      find.descendant(
        of: find.byKey(_write),
        matching: find.text('Send a message'),
      ),
      findsOneWidget,
    );
    _expectOneFilled(tester);
  });

  testWidgets('(d) a business that takes inquiries but publishes no service '
      'is joined first; the message is outlined', (tester) async {
    await _pump(tester, _business(takesInquiries: true));
    final buttons = _buttons(tester);
    expect(buttons.map((b) => b.key), [_join, _write]);
    expect(buttons.first, isA<FilledButton>());
    expect(buttons.last, isA<OutlinedButton>());
    _expectOneFilled(tester);
  });

  testWidgets('(d) an older installation that does not say keeps the page as '
      'it was: join filled, the message outlined, its services askable', (
    tester,
  ) async {
    await _pump(tester, _business(kinds: const [], services: [_massage]));
    final buttons = _buttons(tester);
    expect(buttons.map((b) => b.key), [_join, _write]);
    expect(buttons.first, isA<FilledButton>());
    expect(
      find.descendant(
        of: find.byKey(_write),
        matching: find.text('Send a message'),
      ),
      findsOneWidget,
    );
    _expectOneFilled(tester);
    expect(find.text('Ask'), findsOneWidget);
  });

  testWidgets('the services are grouped by category in the business\'s order, '
      'those without one last, each with duration, named price and tax word', (
    tester,
  ) async {
    await _pump(
      tester,
      _business(
        services: [_massage, _voucher, _reflexology, _back],
        takesInquiries: true,
      ),
    );
    final section = find.byType(PublicServicesSection);
    final texts = tester
        .widgetList<Text>(
          find.descendant(of: section, matching: find.byType(Text)),
        )
        .map((t) => t.data)
        .where((t) => t != 'Ask')
        .toList();
    expect(texts, [
      'Services',
      'Massages',
      'Relaxing massage',
      '60 min · €65.00 · no tax',
      'Back massage',
      '30 min · €40.00 · no tax',
      'Reflexology',
      'Foot reflexology',
      '45 min · €55.00 · no tax',
      'Other',
      'Gift voucher',
      '€50.00 · no tax',
    ]);
  });

  testWidgets('a service that opens an inquiry is a control: at least 48 dp, '
      'an "Ask" affordance, named by what it does', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _business(services: [_massage], takesInquiries: true));
    final row = find.byKey(const ValueKey('public-workspace-service-0'));
    expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    expect(
      find.descendant(of: row, matching: find.text('Ask')),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(row),
      matchesSemantics(
        label: 'Ask about Relaxing massage',
        hint: '60 min · €65.00 · no tax',
        isButton: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('tapping a service opens the inquiry naming the service only, '
      'editable, sent to the business the button names', (tester) async {
    final messenger = FakeMessengerRepository()
      ..roster['ws-practice'] = const [
        HostRosterEntry(name: 'Claire', role: 'owner'),
      ];
    await _pump(
      tester,
      _business(services: [_massage], takesInquiries: true),
      messenger: messenger,
    );
    await tester.tap(find.byKey(const ValueKey('public-workspace-service-0')));
    await tester.pumpAndSettle();
    final body = find.byKey(const ValueKey('inquiry-body'));
    final first = tester.widget<TextField>(body).controller!.text;
    expect(first, 'Hello, I would like to know more about “Relaxing massage”.');
    expect(first, isNot(contains('65')), reason: 'never its price');
    expect(first, isNot(contains('min')), reason: 'never its duration');
    expect(find.text('Claire'), findsOneWidget, reason: 'who reads it');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('inquiry-send')),
        matching: find.text('Send to Cabinet Garrigue'),
      ),
      findsOneWidget,
    );
    await tester.enterText(body, 'Is there a slot on Saturday for a massage?');
    await tester.tap(find.byKey(const ValueKey('inquiry-send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('context-thread')), findsOneWidget);
    expect(
      find.text('Is there a slot on Saturday for a massage?'),
      findsOneWidget,
    );
  });

  testWidgets('nobody answers: the sheet gives the published e-mail and '
      'phone instead of a field to write in', (tester) async {
    await _pump(
      tester,
      _business(
        services: [_massage],
        takesInquiries: true,
        email: 'cabinet@garrigue.example',
        phone: '+33 4 67 00 00 00',
      ),
    );
    await tester.tap(find.byKey(_write));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inquiry-no-hosts')), findsOneWidget);
    expect(find.byKey(const ValueKey('inquiry-body')), findsNothing);
    expect(find.text('cabinet@garrigue.example'), findsWidgets);
    expect(find.text('+33 4 67 00 00 00'), findsWidgets);
    expect(find.byKey(const ValueKey('inquiry-no-way')), findsNothing);
  });

  testWidgets('nobody answers and nothing is published: the sheet says the '
      'business cannot be written to from here; Ask to join stays', (
    tester,
  ) async {
    await _pump(tester, _business(services: [_massage], takesInquiries: true));
    await tester.tap(find.byKey(_write));
    await tester.pumpAndSettle();
    expect(
      find.text('This business cannot be written to from here.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('inquiry-body')), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(_join), findsOneWidget);
  });

  test('a category written with spaces is one group', () {
    final groups = publicServiceGroups([
      PublicService.read(_massage)!,
      PublicService.read({..._back, 'category': ' Massages '})!,
      PublicService.read({..._voucher, 'category': ' '})!,
    ]);
    expect(groups.map((g) => g.category), ['Massages', null]);
    expect(groups.first.services.map((e) => e.$1), [0, 1]);
  });
}
