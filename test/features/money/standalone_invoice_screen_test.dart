// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4165 (A2) -- the composer of a standalone invoice, driven as a person does
// at a phone and at a desk window, on the Demo's own composition: choose the
// customer, enter 1.5 hours, check the invoice the server would freeze, issue
// it and land on the stored invoice; an unreadable quantity is refused with
// its name and nothing is issued; the screen explains itself when the feature
// is off.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
import 'package:deskilo/core/time/business_day_providers.dart';
import 'package:deskilo/core/time/calendar_days.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/core/ui/date_field.dart';
import 'package:deskilo/features/money/presentation/standalone/standalone_invoice_screen.dart';
import 'package:deskilo/features/money/providers/standalone_invoice_providers.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

/// The Demo keeps timers running, so the screen never idles: a few frames are
/// all a tap or a typed value needs.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late DemoFixture fixture;
  late ProviderContainer container;

  Future<void> open(WidgetTester tester, Size size, {bool featureOn = true, List<Override> extra = const []}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // built and awaited in the real zone: the demo's providers run on real
    // timers that the test's fake clock never fires
    await tester.runAsync(() async {
      fixture = DemoFixture.build();
      container = ProviderContainer(overrides: [...demoOverrides(fixture), dayBoundarySchedulerProvider.overrideWithValue(const PinnedDayBoundaries()), ...extra])
        ..listen(currentWorkspaceProvider, (_, _) {});
      await container.read(currentWorkspaceProvider.future);
      if (!featureOn) {
        container.read(activeWorkspaceIdProvider.notifier).activate(demoSecondSpaceId);
      }
      await container.read(currentWorkspaceProvider.future);
      await container.read(workspaceMembersProvider.future);
      await container.read(memberNamesProvider.future);
    });
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const StandaloneInvoiceScreen()),
        GoRoute(path: '/invoices/:id', builder: (_, s) => Text('invoice ${s.pathParameters['id']}')),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await settle(tester);
    // the first screen of a session waits for its workspace
    for (var i = 0; featureOn && i < 60 && find.byKey(const ValueKey('standalone-customer')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The customer is chosen through the field's own callback: the menu is the
  /// framework's, and what is tested here is what the screen does with a choice.
  Future<void> chooseCustomer(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('standalone-customer')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    final members = container.read(workspaceMembersProvider).value ?? const [];
    final id = members.firstWhere((m) => m.status == MemberStatus.active && !m.isKiosk).id;
    tester
        .widget<DropdownButtonFormField<String>>(find.byKey(const ValueKey('standalone-customer')))
        .onChanged!(id);
    await settle(tester);
  }

  /// A long form builds its lower rows lazily: scroll to the one asked for.
  Future<Finder> reveal(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
    await settle(tester);
    return f;
  }

  Future<void> fillLine(WidgetTester tester, {required String quantity}) async {
    await tester.enterText(await reveal(tester, 'standalone-line-0-description'), 'Consulting');
    await tester.enterText(await reveal(tester, 'standalone-line-0-quantity'), quantity);
    await tester.enterText(await reveal(tester, 'standalone-line-0-price'), '80');
    await settle(tester);
  }

  Future<void> tapVisible(WidgetTester tester, String key) async {
    await tester.tap(await reveal(tester, key));
    await settle(tester);
  }

  for (final (name, size) in [('a phone', const Size(390, 844)), ('a desk window', const Size(1440, 900))]) {
    testWidgets('on $name: 1.5 hours is checked, issued and opened', (tester) async {
      await open(tester, size);
      final issue = tester.widget<FilledButton>(await reveal(tester, 'standalone-issue'));
      expect(issue.onPressed, isNull, reason: 'nothing to issue before an invoice was checked');
      await chooseCustomer(tester);
      await fillLine(tester, quantity: '1.5');
      await tapVisible(tester, 'standalone-check');
      expect(await reveal(tester, 'standalone-preview'), findsOneWidget);
      expect(find.textContaining('1.5'), findsWidgets, reason: 'the exact quantity the server froze');
      await tapVisible(tester, 'standalone-issue');
      expect(find.textContaining('invoice inv-'), findsOneWidget, reason: 'the stored invoice is opened');
    });
  }

  testWidgets('an unreadable quantity is refused by name and nothing is issued', (tester) async {
    await open(tester, const Size(390, 844));
    await chooseCustomer(tester);
    await fillLine(tester, quantity: '0.0000001');
    await tapVisible(tester, 'standalone-check');
    expect(await reveal(tester, 'standalone-missing'), findsOneWidget);
    expect(find.textContaining('Line 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('standalone-preview')), findsNothing);
    final issue = tester.widget<FilledButton>(await reveal(tester, 'standalone-issue'));
    expect(issue.onPressed, isNull);
  });

  testWidgets('an edit after the check withdraws the preview: the checked revision is the issued one', (tester) async {
    await open(tester, const Size(390, 844));
    await chooseCustomer(tester);
    await fillLine(tester, quantity: '1');
    await tapVisible(tester, 'standalone-check');
    expect(await reveal(tester, 'standalone-preview'), findsOneWidget);
    await tester.enterText(await reveal(tester, 'standalone-line-0-quantity'), '2');
    await settle(tester);
    expect(find.byKey(const ValueKey('standalone-preview')), findsNothing);
    expect(tester.widget<FilledButton>(await reveal(tester, 'standalone-issue')).onPressed, isNull);
  });

  testWidgets('the composer offers the business\'s day as the service date and the payment term after it', (tester) async {
    await open(tester, const Size(390, 844), extra: [invoiceDueDaysProvider.overrideWithValue(21)]);
    // The business's calendar day of the Demo's clock, not the device's: the two differ near midnight.
    final zone = container.read(currentWorkspaceProvider).value!.timezone;
    final day = businessDateOf(container.read(clockProvider).now(), zone);
    expect(tester.widget<AppDateField>(await reveal(tester, 'standalone-service-date')).value, day);
    expect(tester.widget<AppDateField>(await reveal(tester, 'standalone-due-date')).value, addCalendarDays(day, 21));
  });

  testWidgets('with the feature off the screen says so', (tester) async {
    await open(tester, const Size(390, 844), featureOn: false);
    expect(find.byKey(const ValueKey('standalone-check')), findsNothing);
    expect(find.textContaining('not switched on'), findsOneWidget);
  });
}
