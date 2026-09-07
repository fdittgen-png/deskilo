// SPDX-License-Identifier: 0BSD
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> pumpSettings(
  WidgetTester tester, {
  Map<String, dynamic> featureFlags = const {},
}) async {
  final workspace =
      FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  return workspace;
}

Future<FakeWorkspaceRepository> pumpFeatures(
  WidgetTester tester, {
  Map<String, dynamic> featureFlags = const {},
}) async {
  // Ten manifest features no longer fit the default 800×600 surface and
  // the lazy list drops off-screen tiles; keep every switch mounted.
  // #759 lengthened four descriptions, so the list outgrew 5600 px.
  // #800 gave every tile a second note line, and #802 added two more
  // features — 7200 px stopped fitting the last two switches. #821–#831
  // added five more with long descriptions; 9600 px dropped the last.
  // 2026-09-05 — 82 manifest features (#874) outgrow 12000 px.
  tester.view.physicalSize = const Size(800, 17000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final workspace =
      await pumpSettings(tester, featureFlags: featureFlags);
  await tester.tap(find.text('Features'));
  await tester.pumpAndSettle();
  return workspace;
}

SwitchListTile switchTitled(WidgetTester tester, String title) =>
    tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text(title),
        matching: find.byType(SwitchListTile),
      ),
    );

void main() {
  testWidgets('features screen lists a switch per manifest feature',
      (tester) async {
    await pumpFeatures(tester);

    expect(
      find.byType(SwitchListTile),
      findsNWidgets(featureManifest.length),
    );
    // Everything defaults ON — except adminSeatBlocking (#161),
    // accessorySupplements (#170), onlinePayments (0043), the
    // level-booking pair (0050) and the invoice delegation (0060),
    // which the owner must explicitly activate.
    expect(switchTitled(tester, 'Admins can block seats').value, isFalse);
    expect(switchTitled(tester, 'Accessory supplements').value, isFalse);
    expect(switchTitled(tester, 'Online payments').value, isFalse);
    expect(switchTitled(tester, 'Desk, office & level reservations').value, isFalse);
    expect(
      switchTitled(tester, 'Admins can assign levels').value,
      isFalse,
    );
    expect(switchTitled(tester, 'Admins issue invoices').value, isFalse);
    final onCount = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .where((t) => t.value)
        .length;
    // Default-off owner decisions: adminSeatBlocking, accessorySupplements,
    // onlinePayments, levelBooking, adminLevelAssign, adminInvoicing,
    // autoCheckInOut (#396), badgeSignIn (#662) and, since #914,
    // managedProfileAccess — narrowing who administers a profile is
    // opt-in, because the rule nobody narrowed is what #887 already did.
    expect(onCount, featureManifest.length - 15);
  });

  testWidgets(
      '#963 — toggling a feature writes THAT key only; the row keeps the '
      'rest, and the switch flips', (tester) async {
    final workspace = await pumpFeatures(tester);
    final before = Map.of(workspace.workspaces.single.featureFlags);

    await tester.tap(find.text('Money tab'));
    await tester.pumpAndSettle();

    expect(workspace.flagWrites.last, {'moneyTab': false},
        reason: 'a full map from a stale copy of the row undid the '
            'pilot\'s earlier switches');
    final flags = workspace.workspaces.single.featureFlags;
    expect(flags['moneyTab'], isFalse);
    for (final entry in before.entries) {
      if (entry.key != 'moneyTab') expect(flags[entry.key], entry.value);
    }
    expect(switchTitled(tester, 'Money tab').value, isFalse);

    // Toggling back re-enables it.
    await tester.tap(find.text('Money tab'));
    await tester.pumpAndSettle();
    expect(workspace.flagWrites.last, {'moneyTab': true});
    expect(switchTitled(tester, 'Money tab').value, isTrue);
  });

  testWidgets(
      '#963 — switching a child on writes its parent chain with it and '
      'nothing else', (tester) async {
    final workspace = await pumpFeatures(tester);

    await tester.tap(find.text('Sites on documents'));
    await tester.pumpAndSettle();

    expect(workspace.flagWrites.last,
        {'siteDocuments': true, 'multiSite': true});
    expect(switchTitled(tester, 'Sites on documents').value, isTrue);
    expect(switchTitled(tester, 'Sites').value, isTrue);
  });

  testWidgets(
      'the owner activates accessory supplements (#170): the flag '
      'persists true', (tester) async {
    final workspace = await pumpFeatures(tester);

    await tester.tap(find.text('Accessory supplements'));
    await tester.pumpAndSettle();

    final flags = workspace.workspaces.single.featureFlags;
    expect(flags['accessorySupplements'], isTrue);
    expect(switchTitled(tester, 'Accessory supplements').value, isTrue);
    // The other default-OFF feature is not even written (#963) and
    // stays off.
    expect(flags.containsKey('adminSeatBlocking'), isFalse);
    expect(switchTitled(tester, 'Admins can block seats').value, isFalse);
  });

  testWidgets('stored overrides seed the switches', (tester) async {
    await pumpFeatures(
      tester,
      featureFlags: const {'seriesBooking': false},
    );

    expect(switchTitled(tester, 'Series booking').value, isFalse);
    expect(switchTitled(tester, 'Calendar tab').value, isTrue);
  });

  testWidgets('settings hides the Services tile when services is disabled',
      (tester) async {
    // The personal tiles above the admin section keep growing (#223/#231
    // WhatsApp + Status) — keep every asserted tile mounted.
    tester.view.physicalSize = const Size(800, 4600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpSettings(tester, featureFlags: const {'services': false});

    expect(find.text('Services'), findsNothing);
    // The owner tiles around it stay.
    expect(find.text('Billing'), findsOneWidget);
    expect(find.text('Features'), findsOneWidget);
  });

  testWidgets('settings shows the Services tile when services is enabled',
      (tester) async {
    // The personal tiles above the admin section keep growing (#223/#231
    // WhatsApp + Status, 0038 Photo) — a taller view keeps Services mounted.
    tester.view.physicalSize = const Size(800, 4600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpSettings(tester);

    expect(find.text('Services'), findsOneWidget);
  });

  testWidgets(
      'HIERARCHY: a child switch stays LIVE while its parent is off, and '
      'says what turning it on would bring with it', (tester) async {
    // #800 — this used to be greyed out. A switch an owner cannot move
    // is a dead end: they wanted the feature, and the app answered by
    // disabling the control and explaining nothing about what to do.
    await pumpFeatures(tester, featureFlags: const {'kioskMode': false});

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('feature-nfcBadges')),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    final child = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('feature-nfcBadges')),
    );
    expect(child.onChanged, isNotNull);
    expect(find.textContaining('Requires'), findsWidgets);
    expect(find.textContaining('also enables'), findsWidgets);
  });

  testWidgets(
      'HIERARCHY: switching a child on switches its whole chain on',
      (tester) async {
    // badgeSignIn needs nfcBadges, which needs kioskMode. Turning the
    // deepest one on must bring both — otherwise the owner reads three
    // switches and gets no feature.
    final workspace = await pumpFeatures(
      tester,
      featureFlags: const {'kioskMode': false, 'nfcBadges': false},
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('feature-badgeSignIn')),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('feature-badgeSignIn')));
    await tester.pumpAndSettle();

    final written = workspace.workspaces.single.featureFlags;
    expect(written['badgeSignIn'], isTrue);
    expect(written['nfcBadges'], isTrue, reason: 'the chain comes with it');
    expect(written['kioskMode'], isTrue);
    // And it SAYS so, rather than changing two other settings silently.
    expect(find.textContaining('Also switched on'), findsOneWidget);
  });
}
