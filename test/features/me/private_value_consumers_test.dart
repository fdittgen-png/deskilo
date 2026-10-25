// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2552 XPRIV-01 — the personal surfaces that show a private value use
// PrivateValue: a message preview in the inbox, a contact detail in the
// saved preview of who sees me, an amount due on the Overview. While
// masked the value is in no text and no semantics node; revealed, it
// shows; and each follows the private-values choice. A preview and a
// contact detail were always shown before the choice existed, so they
// are masked only where the choice is offered; an amount stays masked
// even where it is not, as on Finances.
import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/core/privacy/private_values.dart';
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/directory/presentation/messenger/inbox_header.dart';
import 'package:deskilo/features/me/domain/visibility.dart';
import 'package:deskilo/features/me/presentation/visibility_preview.dart';
import 'package:deskilo/features/me/providers/me_providers.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/screens/my_finances_screen.dart' show invoice;
import 'me_app.dart';

const _sentinel = 'SENTINEL4711';
const _offered = PrivateValuesPolicy(enabled: true);
const _accountShows = PrivateValuesPolicy(
  enabled: true,
  account: PrivateValuesChoice.shown,
);

class _MemoryStore implements PrivateValuesStore {
  _MemoryStore([this.value]);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? value) async => this.value = value;
}

List<Override> _privacy(PrivateValuesPolicy? policy, {String? device}) => [
  privateValuesStoreProvider.overrideWithValue(_MemoryStore(device)),
  if (policy != null) privateValuesPolicyProvider.overrideWithValue(policy),
];

Finder _key(String key) => find.byKey(ValueKey(key));

/// Every semantics node that says [needle] in a label, value, hint or
/// tooltip.
SemanticsFinder _saying(String needle) => find.semantics.byPredicate((node) {
  final d = node.getSemanticsData();
  return [d.label, d.value, d.hint, d.tooltip].any((s) => s.contains(needle));
});

/// Masked: the value is in no text and no semantics node, and the reveal
/// says Hidden; revealed: it shows.
Future<void> _maskedThenRevealed(
  WidgetTester tester, {
  required String needle,
  required String reveal,
  required String hiddenLabel,
}) async {
  expect(find.textContaining(needle), findsNothing);
  expect(_saying(needle), findsNothing);
  expect(tester.getSemantics(_key(reveal)).label, contains(hiddenLabel));
  await tester.ensureVisible(_key(reveal));
  await tester.tap(_key(reveal));
  await tester.pumpAndSettle();
  expect(find.textContaining(needle), findsOneWidget);
}

InboxEntry get _entry => InboxEntry(
  source: '',
  kind: MessageContextKind.space,
  contextId: 'c1',
  workspaceId: 'ws-1',
  workspaceName: 'Pézenas',
  title: 'Thread c1',
  lastBody: 'See you at $_sentinel',
  lastAt: DateTime.utc(2026, 5, 13, 8),
);

Future<void> _pumpRow(
  WidgetTester tester, {
  PrivateValuesPolicy? policy,
  String? device,
}) async {
  await pumpApp(
    tester,
    Scaffold(
      body: InboxListRow(
        entry: _entry,
        servers: const {},
        pinned: false,
        selected: false,
        onOpen: () {},
        onMarks: () {},
      ),
    ),
    overrides: _privacy(policy, device: device),
  );
  await tester.pumpAndSettle();
}

class _ContactsMe extends FakeMeRepository {
  @override
  Future<AccountView> previewMyAccount(PreviewAudience audience) async =>
      const AccountView(
        name: 'Ana',
        email: 'ana.$_sentinel@example.org',
        whatsapp: '+33 6 $_sentinel',
      );
}

Future<void> _pumpContacts(
  WidgetTester tester, {
  PrivateValuesPolicy? policy,
  String? device,
}) async {
  await pumpApp(
    tester,
    const Scaffold(body: SingleChildScrollView(child: VisibilityPreview())),
    overrides: [
      ...standardTestOverrides(me: _ContactsMe()),
      myVisibilityProvider.overrideWith((ref) async => MyVisibility.defaults),
      ..._privacy(policy, device: device),
    ],
    size: const Size(600, 1200),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpOverview(
  WidgetTester tester, {
  PrivateValuesPolicy? policy,
  String? device,
}) async {
  final documents = FakeAccountActivityRepository()
    ..financeOverview = FinanceOverview(
      invoices: [invoice('eur', ws: 'One', total: 471100, due: DateTime(2999))],
    );
  final router = await pumpMeApp(
    tester,
    workspace: twoSpaces(),
    accountActivity: documents,
    size: const Size(420, 2600),
    extraOverrides: [
      personalShellEnabledProvider.overrideWithValue(true),
      ..._privacy(policy, device: device),
    ],
  );
  await goTo(tester, router, '/me');
}

void main() {
  group('the inbox preview', () {
    testWidgets('offered and no choice yet: masked, absent from text and '
        'semantics; the reveal shows it', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpRow(tester, policy: _offered);
      expect(_key('inbox-entry-c1'), findsOneWidget);
      expect(find.textContaining('In Pézenas'), findsOneWidget);
      expect(_key('inbox-preview-c1'), findsNothing);
      await _maskedThenRevealed(
        tester,
        needle: _sentinel,
        reveal: 'inbox-preview-reveal-c1',
        hiddenLabel: 'Hidden',
      );
      expect(_key('inbox-preview-c1'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('the choice to show is followed: plain, no reveal', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        policy: _offered,
        device: PrivateValuesChoice.shown,
      );
      expect(_key('inbox-preview-c1'), findsOneWidget);
      expect(_key('inbox-preview-reveal-c1'), findsNothing);
      await _pumpRow(tester, policy: _accountShows);
      expect(_key('inbox-preview-c1'), findsOneWidget);
    });

    testWidgets('not offered (personal shell off): the preview reads as '
        'before', (tester) async {
      await _pumpRow(tester);
      expect(find.textContaining(_sentinel), findsOneWidget);
      expect(_key('inbox-preview-reveal-c1'), findsNothing);
    });
  });

  group('the contact details of the saved preview', () {
    testWidgets('offered and no choice yet: e-mail and WhatsApp masked, '
        'absent from text and semantics; each reveal shows its own', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpContacts(tester, policy: _offered);
      expect(find.text('Ana'), findsOneWidget, reason: 'a name is not masked');
      await _maskedThenRevealed(
        tester,
        needle: 'ana.$_sentinel',
        reveal: 'visibility-preview-email-reveal',
        hiddenLabel: 'Hidden',
      );
      expect(find.textContaining('+33 6'), findsNothing);
      await _maskedThenRevealed(
        tester,
        needle: '+33 6 $_sentinel',
        reveal: 'visibility-preview-whatsapp-reveal',
        hiddenLabel: 'Hidden',
      );
      expect(_key('visibility-preview-email'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('the account chose to show: plain', (tester) async {
      await _pumpContacts(tester, policy: _accountShows);
      expect(find.text('ana.$_sentinel@example.org'), findsOneWidget);
      expect(_key('visibility-preview-email-reveal'), findsNothing);
    });

    testWidgets('not offered: read as before', (tester) async {
      await _pumpContacts(tester);
      expect(find.text('+33 6 $_sentinel'), findsOneWidget);
    });
  });

  group('the Overview amount due', () {
    testWidgets('masked by default with its currency; absent from text and '
        'semantics; the reveal shows it', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpOverview(tester, policy: _offered);
      expect(_key('me-overview-document|ws-One|eur'), findsOneWidget);
      expect(find.text('EUR ••••'), findsOneWidget);
      expect(find.text('to pay · INV-eur'), findsOneWidget);
      await _maskedThenRevealed(
        tester,
        needle: '4,711',
        reveal: 'me-overview-amount-document|ws-One|eur',
        hiddenLabel: 'Amount hidden',
      );
      semantics.dispose();
    });

    testWidgets('the choice to show is followed', (tester) async {
      await _pumpOverview(
        tester,
        policy: _offered,
        device: PrivateValuesChoice.shown,
      );
      expect(find.textContaining('4,711'), findsOneWidget);
      expect(_key('me-overview-amount-document|ws-One|eur'), findsNothing);
    });
  });
}
