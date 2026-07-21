// SPDX-License-Identifier: 0BSD
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/payment_method.dart';
import 'package:deskilo/features/money/domain/payment_provider.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/workspace/domain/overage_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Future<FakeMoneyRepository> pumpMoney(
  WidgetTester tester, {
  FakeMoneyRepository? money,
  FakeEventRepository? events,
  FakeWorkspaceRepository? workspace,
}) async {
  money ??= FakeMoneyRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        money: money,
        events: events,
        workspace: workspace,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Money'));
  await tester.pumpAndSettle();
  return money;
}

/// A workspace whose owner configured how-to-pay details (#155, #192).
FakeWorkspaceRepository workspaceWithInstructions() {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  workspace.workspaces[0] = workspace.workspaces[0].copyWith(
    paymentInstructions: const {
      'iban': 'DE89 3704 0044 0532 0130 00',
      'paypal_me': 'deskilo',
      'reference': 'DesKilo member period',
      'wero': '+49 170 0000000',
      'lydia': '+33 6 00 00 00 00',
      'wise': '@deskilo',
    },
  );
  return workspace;
}

/// The period before 'yyyy-MM'.
String previousPeriod(String period) {
  final year = int.parse(period.substring(0, 4));
  final month = int.parse(period.substring(5));
  return DateFormat('yyyy-MM').format(DateTime(year, month - 1));
}

void main() {
  testWidgets(
      'the bill shows the localized month, subscription, entitlement, '
      'overage and the outstanding balance state', (tester) async {
    await pumpMoney(tester);

    expect(
      find.text(DateFormat.yMMMM('en').format(DateTime.now())),
      findsOneWidget,
    );
    expect(find.text('Subscription 50%'), findsOneWidget);
    expect(
      find.text('24 of 22 half-days used (22 open days)'),
      findsOneWidget,
    );
    expect(find.text('2 extra half-days'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
    expect(find.text('Outstanding'), findsOneWidget);
    // No accessory supplements on the statement (#170) — no line.
    expect(find.text('Accessory supplements'), findsNothing);
  });

  testWidgets(
      'the entitlement card headlines the month in days used and left (0041)',
      (tester) async {
    // The default statement: 24 of 22 half-days used → 12 of 11 days, 0 left,
    // over the cap → the blocked full-cap hint shows.
    await pumpMoney(tester);

    expect(find.byKey(const Key('entitlement-card')), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('12 of 11 days used'), findsOneWidget);
    expect(find.text('0 days left'), findsOneWidget);
    expect(
      find.textContaining("used all your days this month"),
      findsOneWidget,
    );
  });

  testWidgets(
      'a pay-as-you-go member sees the per-day overage rate on the card '
      '(0041)', (tester) async {
    final money = FakeMoneyRepository();
    money.statement = money.statement.copyWith(
      includedHalfDays: 20,
      usedHalfDays: 10,
      extraHalfDays: 0,
      overageCents: 0,
      remainingHalfDays: 10,
      overagePolicy: OveragePolicy.payg,
      overageRateCents: 800, // per half-day → €16.00 per day
    );
    await pumpMoney(tester, money: money);

    expect(find.text('5 of 10 days used'), findsOneWidget);
    expect(find.text('5 days left'), findsOneWidget);
    // The band overage rate is per half-day; a whole extra day bills double.
    expect(
      find.descendant(
        of: find.byKey(const Key('entitlement-card')),
        matching: find.textContaining('€16.00'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'the buy-a-package button shows only for package-plan members and buys '
      'the chosen package (0042)', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.myMember =
        workspace.myMember.copyWith(overagePolicy: OveragePolicy.package);
    final money = FakeMoneyRepository();
    await pumpMoney(tester, money: money, workspace: workspace);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('buy-package-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('buy-package-button')));
    await tester.pumpAndSettle();

    // The sheet lists the seeded 5-day pack; buy it.
    expect(find.text('5-day pack'), findsOneWidget);
    await tester.tap(find.text('5-day pack'));
    await tester.pumpAndSettle();

    expect(money.boughtPackages, [('ws-1', 'package-5')]);
    expect(find.textContaining('Days added'), findsOneWidget);
  });

  testWidgets('a blocked member sees no buy-a-package button (0042)',
      (tester) async {
    // The default member is on the blocked policy.
    await pumpMoney(tester);
    expect(
      find.byKey(const ValueKey('buy-package-button')),
      findsNothing,
    );
  });

  testWidgets('a bought package shows as a Day packages bill line (0042)',
      (tester) async {
    final money = FakeMoneyRepository();
    money.ledger.add(
      LedgerEntry(
        id: 'led-pkg',
        memberId: 'member-1',
        kind: LedgerKind.charge,
        category: LedgerCategory.package,
        amountCents: 4000,
        description: '5-day pack (5d)',
        period: money.statement.period,
        createdAt: DateTime.now(),
      ),
    );
    await pumpMoney(tester, money: money);

    expect(find.byKey(const Key('packages-card')), findsOneWidget);
    expect(find.text('Day packages'), findsOneWidget);
    expect(find.text('5-day pack (5d)'), findsOneWidget);
  });

  testWidgets(
      'with online payments on, an outstanding bill offers Pay online and '
      'starts the order for the owed amount (0043)', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.workspaces[0] = workspace.workspaces[0].copyWith(
      featureFlags: const {'onlinePayments': true},
    );
    final money = FakeMoneyRepository(); // owes €16.00 (balance −1600)
    await pumpMoney(tester, money: money, workspace: workspace);

    await tester.scrollUntilVisible(
      find.byKey(const Key('pay-online-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('pay-online-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pay-online-button')));
    await tester.pumpAndSettle();

    // Single configured provider (PayPal) → the order starts directly for
    // the owed amount; the fake returns no URL (secrets missing), so the
    // OWNER gets the diagnostics dialog naming the missing config.
    expect(money.paymentOrders, [(PaymentProvider.paypal, 1600)]);
    expect(
      find.text('Online payments — not configured'),
      findsOneWidget,
    );
    expect(find.textContaining('PAYPAL_CLIENT_ID'), findsOneWidget);
  });

  testWidgets(
      'several configured providers open the chooser; picking the card '
      'provider starts a Stripe order', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.workspaces[0] = workspace.workspaces[0].copyWith(
      featureFlags: const {'onlinePayments': true},
    );
    final money = FakeMoneyRepository()
      ..paymentProviders = [
        PaymentProvider.paypal,
        PaymentProvider.stripe,
        PaymentProvider.mollie,
      ]
      ..paymentApprovalUrl = Uri.parse('https://checkout.example/session');
    await pumpMoney(tester, money: money, workspace: workspace);

    await tester.scrollUntilVisible(
      find.byKey(const Key('pay-online-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('pay-online-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pay-online-button')));
    await tester.pumpAndSettle();

    // All three providers offered; card goes through Stripe.
    expect(find.text('Credit card (Stripe)'), findsOneWidget);
    expect(find.text('Mollie — iDEAL, Bancontact…'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pay-provider-stripe')));
    await tester.pumpAndSettle();

    expect(money.paymentOrders, [(PaymentProvider.stripe, 1600)]);
  });

  testWidgets('online payments off hides the Pay-online button (0043)',
      (tester) async {
    // Instructions present so the how-to-pay card renders, but the feature
    // is off → no online button.
    await pumpMoney(tester, workspace: workspaceWithInstructions());

    expect(find.byKey(const Key('howToPayIban')), findsOneWidget);
    expect(find.byKey(const Key('pay-online-button')), findsNothing);
  });

  testWidgets(
      'a non-zero accessory supplement (#170) renders its own bill line '
      'with the amount', (tester) async {
    final money = FakeMoneyRepository();
    money.statement = money.statement.copyWith(
      accessorySupplementCents: 900,
      balanceCents: -2500,
    );
    await pumpMoney(tester, money: money);

    expect(find.text('Accessory supplements'), findsOneWidget);
    expect(find.text('−€9.00'), findsOneWidget);
  });

  testWidgets(
      'a non-zero level supplement (0050) renders its own bill line with '
      'the amount', (tester) async {
    final money = FakeMoneyRepository();
    money.statement = money.statement.copyWith(
      levelSupplementCents: 5000,
      balanceCents: -6600,
    );
    await pumpMoney(tester, money: money);

    expect(find.text('Level reservations'), findsOneWidget);
    expect(find.text('−€50.00'), findsOneWidget);
  });

  testWidgets('a settled statement shows the settled state', (tester) async {
    final money = FakeMoneyRepository();
    money.statement = money.statement.copyWith(
      creditsCents: 20000,
      balanceCents: 3400,
    );
    await pumpMoney(tester, money: money);

    expect(find.text('Settled'), findsOneWidget);
    expect(find.text('Outstanding'), findsNothing);
  });

  testWidgets(
      'all bill sections render: services with total, pending open '
      'positions with badge, payments & credits', (tester) async {
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final period = currentPeriod();
    final money = FakeMoneyRepository();
    money.ledger.addAll([
      LedgerEntry(
        id: 'l-coffee',
        memberId: 'member-1',
        kind: LedgerKind.charge,
        category: LedgerCategory.service,
        amountCents: 300,
        description: 'Coffee x2',
        period: period,
        createdAt: DateTime.now(),
      ),
      LedgerEntry(
        id: 'l-payment',
        memberId: 'member-1',
        kind: LedgerKind.credit,
        category: LedgerCategory.payment,
        amountCents: 15000,
        description: 'Bank transfer',
        period: period,
        createdAt: DateTime.now(),
      ),
    ]);
    final events = FakeEventRepository();
    events.events.add(
      WorkspaceEvent(
        id: 'evt-pending',
        workspaceId: 'ws-1',
        type: EventType.serviceCharge,
        action: EventAction.submitted,
        actorMemberId: 'member-1',
        subjectMemberId: 'member-1',
        payload: {
          'name': 'Printing',
          'quantity': 4,
          'amount_cents': 80,
          'period': period,
        },
        status: EventStatus.pending,
        createdAt: DateTime.now(),
      ),
    );
    await pumpMoney(tester, money: money, events: events);

    expect(find.text('Consumed services'), findsOneWidget);
    expect(find.text('Coffee x2'), findsOneWidget);
    expect(find.text('Services total'), findsOneWidget);
    expect(find.text('−€3.00'), findsNWidgets(2)); // row + section total

    expect(find.text('Open positions'), findsOneWidget);
    expect(find.text('pending validation'), findsOneWidget);
    expect(find.text('Printing ×4'), findsOneWidget);
    expect(find.text('−€0.80'), findsOneWidget);

    expect(find.text('Payments & credits'), findsOneWidget);
    expect(find.text('Bank transfer'), findsOneWidget);
    expect(find.text('+€150.00'), findsOneWidget);

    expect(find.text('Balance'), findsOneWidget);
  });

  testWidgets('empty sections are hidden entirely', (tester) async {
    await pumpMoney(tester);

    expect(find.text('Consumed services'), findsNothing);
    expect(find.text('Open positions'), findsNothing);
    expect(find.text('Payments & credits'), findsNothing);
    // The subscription block and balance footer always render.
    expect(find.text('Subscription 50%'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
  });

  testWidgets(
      'the period chevrons query the neighbouring month and the forward '
      'chevron stops at the current period', (tester) async {
    final previous = previousPeriod(currentPeriod());
    final money = FakeMoneyRepository();
    money.statements[previous] = money.statement.copyWith(
      period: previous,
      subscriptionPct: 25,
      feeCents: 0,
    );
    await pumpMoney(tester, money: money);

    // At the current period the forward chevron is disabled.
    final forward = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(forward.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(money.fetchedPeriods, contains(previous));
    expect(find.text('Subscription 25%'), findsOneWidget);
    final year = int.parse(previous.substring(0, 4));
    final month = int.parse(previous.substring(5));
    expect(
      find.text(DateFormat.yMMMM('en').format(DateTime(year, month))),
      findsOneWidget,
    );

    // Going forward again returns to the current period.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('Subscription 50%'), findsOneWidget);
  });

  testWidgets(
      'pending payments and expenses appear as open positions only on the '
      'current period', (tester) async {
    final events = FakeEventRepository();
    events.events.add(
      WorkspaceEvent(
        id: 'evt-payment',
        workspaceId: 'ws-1',
        type: EventType.payment,
        action: EventAction.submitted,
        actorMemberId: 'member-1',
        subjectMemberId: 'member-1',
        payload: const {'amount_cents': 5000, 'note': 'transfer'},
        status: EventStatus.pending,
        createdAt: DateTime.now(),
      ),
    );
    await pumpMoney(tester, events: events);

    expect(find.text('Open positions'), findsOneWidget);
    expect(find.text('+€50.00'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('Open positions'), findsNothing);
  });

  testWidgets('recording a payment submits cents for confirmation',
      (tester) async {
    final money = await pumpMoney(tester);

    await tester.scrollUntilVisible(find.text('Record a payment'), 100);
    await tester.tap(find.text('Record a payment'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Amount'),
      '150,50',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Note (optional)'),
      'July rent',
    );
    await tester.tap(find.text('Submit for confirmation'));
    await tester.pumpAndSettle();

    expect(money.recordedPayments.single.amountCents, 15050);
    expect(money.recordedPayments.single.note, 'July rent');
    expect(money.recordedPayments.single.method, isNull,
        reason: 'no chip tapped → method not specified (#154)');
    expect(
      find.text('Payment submitted — waiting for confirmation.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a method chip records the payment method (#154)',
      (tester) async {
    final money = await pumpMoney(tester);

    await tester.scrollUntilVisible(find.text('Record a payment'), 100);
    await tester.tap(find.text('Record a payment'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Amount'),
      '25',
    );
    await tester.tap(find.text('PayPal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit for confirmation'));
    await tester.pumpAndSettle();

    expect(money.recordedPayments.single.amountCents, 2500);
    expect(money.recordedPayments.single.method, PaymentMethod.paypal);
  });

  testWidgets(
      'an outstanding statement shows the how-to-pay card: IBAN copies, '
      'PayPal.me is a tappable link, the reference hint renders (#155)',
      (tester) async {
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpMoney(tester, workspace: workspaceWithInstructions());

    expect(find.text('Payment instructions'), findsOneWidget);
    expect(find.text('DE89 3704 0044 0532 0130 00'), findsOneWidget);
    expect(find.text('https://paypal.me/deskilo'), findsOneWidget);
    expect(find.text('DesKilo member period'), findsOneWidget);

    // The PayPal row is tappable (opens externally in production).
    final paypalTile = tester.widget<ListTile>(
      find.byKey(const Key('howToPayPaypal')),
    );
    expect(paypalTile.onTap, isNotNull);

    // Tapping the IBAN row copies it (scroll it into view first — the
    // card sits below the balance footer).
    // Clipboard.setData awaits SystemChannels.platform, which has no
    // handler in widget tests — mock it so the copy completes.
    ClipboardData? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = ClipboardData(
            text: (call.arguments as Map<Object?, Object?>)['text']!
                as String,
          );
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.ensureVisible(find.byKey(const Key('howToPayIban')));
    await tester.tap(find.byKey(const Key('howToPayIban')));
    // One frame, not pumpAndSettle — settling would pump through the
    // snackbar's whole display duration and it would already be gone.
    await tester.pump();
    await tester.pump();
    expect(find.text('IBAN copied.'), findsOneWidget);
    expect(copied?.text, 'DE89 3704 0044 0532 0130 00');
  });

  testWidgets(
      'the how-to-pay card renders Wero, Lydia and Wise rows and tapping '
      'the Wero row copies its phone number (#192)', (tester) async {
    tester.view.physicalSize = const Size(600, 2800);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpMoney(tester, workspace: workspaceWithInstructions());

    expect(find.text('Wero'), findsOneWidget);
    expect(find.text('+49 170 0000000'), findsOneWidget);
    expect(find.text('Lydia'), findsOneWidget);
    expect(find.text('+33 6 00 00 00 00'), findsOneWidget);
    expect(find.text('Wise'), findsOneWidget);
    expect(find.text('@deskilo'), findsOneWidget);

    // Clipboard.setData awaits SystemChannels.platform, which has no
    // handler in widget tests — mock it so the copy completes.
    ClipboardData? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = ClipboardData(
            text: (call.arguments as Map<Object?, Object?>)['text']!
                as String,
          );
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.ensureVisible(find.byKey(const Key('howToPayWero')));
    await tester.tap(find.byKey(const Key('howToPayWero')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Copied to clipboard.'), findsOneWidget);
    expect(copied?.text, '+49 170 0000000');
  });

  testWidgets(
      'recording a payment with the Wero chip submits the wero method '
      'end-to-end (#192)', (tester) async {
    final money = await pumpMoney(tester);

    await tester.scrollUntilVisible(find.text('Record a payment'), 100);
    await tester.tap(find.text('Record a payment'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Amount'),
      '12',
    );
    await tester.tap(find.text('Wero'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit for confirmation'));
    await tester.pumpAndSettle();

    expect(money.recordedPayments.single.amountCents, 1200);
    expect(money.recordedPayments.single.method, PaymentMethod.wero);
  });

  testWidgets(
      'the method picker keeps the catch-all chip last even though the '
      'enum is append-only (#192)', (tester) async {
    await pumpMoney(tester);

    await tester.scrollUntilVisible(find.text('Record a payment'), 100);
    await tester.tap(find.text('Record a payment'));
    await tester.pumpAndSettle();

    final chipLabels = [
      for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)))
        ((chip.label) as Text).data,
    ];
    expect(chipLabels.last, 'Other');
    expect(chipLabels, containsAll(['Wero', 'Lydia', 'Wise']));
  });

  testWidgets('a settled statement shows NO how-to-pay card (#155)',
      (tester) async {
    final money = FakeMoneyRepository();
    money.statement = money.statement.copyWith(
      creditsCents: 20000,
      balanceCents: 3400,
    );
    await pumpMoney(
      tester,
      money: money,
      workspace: workspaceWithInstructions(),
    );

    expect(find.text('Settled'), findsOneWidget);
    expect(find.text('Payment instructions'), findsNothing);
  });

  testWidgets('no configured instructions → no how-to-pay card even when '
      'outstanding (#155)', (tester) async {
    await pumpMoney(tester);

    expect(find.text('Outstanding'), findsOneWidget);
    expect(find.text('Payment instructions'), findsNothing);
  });

  testWidgets('re-tapping the selected method chip deselects it (#154)',
      (tester) async {
    final money = await pumpMoney(tester);

    await tester.scrollUntilVisible(find.text('Record a payment'), 100);
    await tester.tap(find.text('Record a payment'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Amount'),
      '25',
    );
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit for confirmation'));
    await tester.pumpAndSettle();

    expect(money.recordedPayments.single.method, isNull);
  });

  testWidgets(
      'adding consumption records service, quantity and period (#129)',
      (tester) async {
    final money = await pumpMoney(tester);

    await tester.scrollUntilVisible(find.text('Add consumption'), 100);
    // The quota-request button (0031) pushed this below the fold edge;
    // scrollUntilVisible stops once BUILT, ensureVisible finishes.
    await tester.ensureVisible(find.text('Add consumption'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add consumption'));
    await tester.pumpAndSettle();

    // Coffee is the first active service (name-ordered); bump quantity.
    expect(find.text('Coffee — €1.50'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.text('Submit for confirmation'));
    await tester.pumpAndSettle();

    final recorded = money.recordedServiceCharges.single;
    expect(recorded.workspaceId, 'ws-1');
    expect(recorded.subjectMemberId, 'member-1');
    expect(recorded.serviceId, 'service-coffee');
    expect(recorded.quantity, 2);
    expect(recorded.period, currentPeriod());
    expect(
      find.text('Consumption recorded — waiting for confirmation.'),
      findsOneWidget,
    );
  });

  testWidgets('the consumption sheet offers only active services',
      (tester) async {
    final money = await pumpMoney(tester);

    await tester.scrollUntilVisible(find.text('Add consumption'), 100);
    // The quota-request button (0031) pushed this below the fold edge;
    // scrollUntilVisible stops once BUILT, ensureVisible finishes.
    await tester.ensureVisible(find.text('Add consumption'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add consumption'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Coffee — €1.50'));
    await tester.pumpAndSettle();
    // Locker is inactive and must not be offered.
    expect(find.textContaining('Locker'), findsNothing);
    await tester.tap(find.text('Printing — €0.20').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit for confirmation'));
    await tester.pumpAndSettle();

    expect(
      money.recordedServiceCharges.single.serviceId,
      'service-printing',
    );
    expect(money.recordedServiceCharges.single.quantity, 1);
  });
}
