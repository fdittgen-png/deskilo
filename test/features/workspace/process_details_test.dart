// SPDX-License-Identifier: 0BSD
// Read-only process navigation explains canonical dependencies and saved choices.
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/widgets/process_details.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'features_screen_test.dart' show pumpFeatures;

void main() {
  Future<void> pump(WidgetTester tester, Widget child, {String locale = 'en'}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!),
      home: child,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Features opens the read-only hierarchy', (tester) async {
    final repository = await pumpFeatures(tester);
    await tester.tap(find.byIcon(Icons.account_tree_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(ProcessDetails), findsOneWidget);
    expect(repository.flagWrites, isEmpty);
  });

  testWidgets('process hierarchy opens capability explanation', (tester) async {
    await pump(tester, const ProcessDetails(raw: {}));
    await tester.tap(find.text('Workspace & access'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('People & membership'));
    await tester.tap(find.text('People & membership'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Members directory'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Members directory'));
    await tester.pumpAndSettle();
    expect(find.byType(CapabilityDetails), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['en', 'fr', 'de', 'es', 'it']) {
    testWidgets('$locale narrow large text reveals technical key', (tester) async {
      await pump(tester, const CapabilityDetails(
        feature: WorkspaceFeature.adminInvoicing,
        raw: {WorkspaceFeature.adminInvoicing},
      ), locale: locale);
      expect(find.byType(SelectableText), findsNothing);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('requires-invoicing')), 150);
      expect(find.byIcon(Icons.block), findsWidgets);
      await tester.scrollUntilVisible(find.byType(ExpansionTile), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byType(SelectableText), 150,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('adminInvoicing'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('requires and cross-process homes come from the manifest', (tester) async {
    await pump(tester, const CapabilityDetails(
      feature: WorkspaceFeature.einvoiceCustomerDelivery, raw: {}));
    await tester.scrollUntilVisible(find.byKey(const ValueKey('requires-invoicing')), 150);
    expect(find.textContaining('Billing & payments'), findsWidgets);
    expect(find.textContaining('Requires'), findsWidgets);
  });
}
