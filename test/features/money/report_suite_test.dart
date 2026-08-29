// SPDX-License-Identifier: 0BSD
//
// The report SUITE (#494): the financial agreement, the monthly
// payments report and the workspace report — engine documents with
// their own presets, self-service on the Money tab, sendable per member
// and exportable from workspace settings.
import 'package:deskilo/features/money/presentation/invoice_actions.dart';
import 'package:deskilo/features/money/presentation/report_defaults.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';
import 'invoices_test.dart' show pumpInvoices, seededMoney;

/// Builds the agreement's data model off a floor plan, in English —
/// the document body itself is rendered by the shared report engine, so
/// what a member is DISCLOSED is exactly this line list.
Future<List<Map<String, Object?>>> agreementLines(
  WidgetTester tester,
  FakeFloorPlanRepository plans,
) async {
  List<Map<String, Object?>>? lines;
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(floorPlan: plans),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) {
            // The builder reads the plan providers synchronously, so
            // wait for them here exactly as the screens do.
            final levels = ref.watch(levelsProvider).value;
            if (levels == null) return const SizedBox.shrink();
            for (final level in levels) {
              if (ref.watch(floorPlanProvider(level.id)).value == null) {
                return const SizedBox.shrink();
              }
            }
            lines = (agreementReportData(
              context,
              ref,
              memberName: 'Flo',
              subscriptionPct: 100,
              localeName: 'en',
            )['lines'] as List)
                .cast<Map<String, Object?>>();
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(lines, isNotNull, reason: 'the agreement data never built');
  return lines!;
}

void main() {
  group('the three new documents ship the four presets (#494)', () {
    for (final doc in ['agreement', 'payments', 'workspace']) {
      test(doc, () {
        final presets = presetsForDoc(doc, null);
        expect(presets.map((p) => p.id),
            ['classic', 'simple', 'verbose', 'formal']);
        expect(presets.first.bands.header,
            defaultBandsForDoc(doc, null).header);
        expect(defaultBandsForDoc(doc, null).hasBands, isTrue);
      });
    }
  });

  testWidgets(
      'the agreement DISCLOSES a bookable desk price (#638) beside the '
      'office one — a member cannot be charged a price their own '
      'agreement never named', (tester) async {
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    plans.desks[0] = plans.desks[0]
        .copyWith(bookableAsWhole: true, priceCents: 1800);
    plans.offices[0] = plans.offices[0]
        .copyWith(bookableAsWhole: true, priceCents: 4200);

    final lines = await agreementLines(tester, plans);
    final labels = [for (final l in lines) l['label'] as String];

    expect(
      labels,
      contains('Window desk — Desk reservations'),
      reason: 'desks are priced, billed and shown on the bill',
    );
    expect(labels, contains('Main room — Office reservations'));
    final desk = lines.firstWhere(
        (l) => (l['label'] as String).startsWith('Window desk'));
    expect(desk['amount'], contains('18'));
  });

  testWidgets('a desk that is not bookable as a whole, or free, stays '
      'off the agreement (#638)', (tester) async {
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    // Priced but not offered as a whole: nothing to disclose.
    plans.desks[0] = plans.desks[0].copyWith(priceCents: 1800);

    final lines = await agreementLines(tester, plans);

    expect(
      [for (final l in lines) l['label'] as String],
      isNot(contains(startsWith('Window desk'))),
    );
  });

  test('extraDocs round-trip through the template jsonb (#494)', () {
    const template = InvoicePdfTemplate(extraDocs: {
      'agreement': ReportBands(header: '# A'),
      'workspace': ReportBands(body: 'B'),
    });
    final restored = InvoicePdfTemplate.fromJson(
        template.toJson().cast<String, dynamic>());
    expect(restored.docBands('agreement')!.header, '# A');
    expect(restored.docBands('workspace')!.body, 'B');
    expect(restored.docBands('payments'), isNull);
    // withDoc replaces one and keeps the rest.
    final next =
        restored.withDoc('payments', const ReportBands(header: '# P'));
    expect(next.docBands('agreement')!.header, '# A');
    expect(next.docBands('payments')!.header, '# P');
  });

  testWidgets('the editor lists the three documents as chips and saves '
      'their bands into extraDocs (#494)', (tester) async {
    final money = await pumpInvoices(tester, money: await seededMoney());

    await tester.tap(find.byKey(const ValueKey('invoice-template-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
        find.byKey(const ValueKey('invoice-template-doc-agreement')));
    await tester
        .tap(find.byKey(const ValueKey('invoice-template-doc-agreement')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-template-reset')));
    await tester.pump();
    await tester.ensureVisible(
        find.byKey(const ValueKey('invoice-template-save')));
    await tester.tap(find.byKey(const ValueKey('invoice-template-save')));
    await tester.pumpAndSettle();

    final agreement = money.pdfTemplate.docBands('agreement');
    expect(agreement, isNotNull);
    expect(agreement!.header, contains('Financial agreement'));
    // The invoice's own bands stayed untouched.
    expect(money.pdfTemplate.invoiceBands.hasBands, isFalse);
  });

  testWidgets('the Money tab offers the self-service documents with '
      'quick view / download / share (#494)', (tester) async {
    await pumpInvoices(tester, money: await seededMoney());
    // Back to the Money tab root (pumpInvoices navigates to /invoices).
    await tester.pageBack();
    await tester.pumpAndSettle();

    // #720 — the payments report lives on the Payments face, the
    // agreement on the Invoices face (pumpInvoices left us there).
    await tester.tap(find.byKey(const ValueKey('money-face-payments')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
        find.byKey(const ValueKey('payments-report-button')));
    expect(find.byKey(const ValueKey('payments-report-button')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('money-face-invoices')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
        find.byKey(const ValueKey('agreement-report-button')));
    expect(find.byKey(const ValueKey('agreement-report-button')),
        findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('agreement-report-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('member-doc-quick')), findsOneWidget);
    expect(find.byKey(const ValueKey('member-doc-download')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('member-doc-share')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('member-doc-quick')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-quick-preview')),
        findsOneWidget);
    // #496 — the DE fixture workspace resolves the document language to
    // German: the member's self-service agreement is a Finanzvereinbarung.
    expect(find.textContaining('Finanzvereinbarung'), findsWidgets);
  });
}
