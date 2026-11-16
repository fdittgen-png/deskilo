// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4119 -- the sheet drawn on the screen is the paper the document prints
// on. Each surface that draws a sheet (the quick view, the page designer,
// the layout preview, the reminder letter preview, the setup's sample
// invoice) is shown with Letter and with A4: on Letter the sheet is 612 by
// 792 points and the address window is at the Letter field (#3981); on A4
// nothing is different from what it was. The Demo's New York house, a
// business on Letter, shows a Letter sheet in the quick view and in the
// designer.
import 'dart:typed_data';

import 'package:deskilo/core/demo/seed/demo_new_york_seed.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_render.dart';
import 'package:deskilo/features/money/presentation/invoice_pdf_actions.dart';
import 'package:deskilo/features/money/presentation/invoicing/reminder_letter_preview_page.dart';
import 'package:deskilo/features/money/presentation/widgets/report_layout_preview.dart';
import 'package:deskilo/features/money/presentation/widgets/report_page_designer.dart';
import 'package:deskilo/features/money/presentation/widgets/report_page_style.dart';
import 'package:deskilo/features/money/presentation/widgets/report_preview.dart';
import 'package:deskilo/features/money/presentation/widgets/setup_sample_invoice.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_document_model/deskilo_document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart' show tapInvoicingTool;
import '../../helpers/screens/invoices.dart' show pumpInvoices;
import '../../helpers/test_workspace_context.dart';

const double _mm = 72 / 25.4;

const _report = InvoiceReport(
  header: [ReportHeading('Invoice')],
  body: [ReportText('Zephyrine Quarterbridge-Okonkwo')],
  footer: [],
);

InvoiceReport _on(Paper paper) => _report.onPaper(paper);

const _layout = '''
<report-layout margin="20mm">
  <header height="25mm"><text style="heading">{{ workspace }}</text></header>
  <recipient window="din"/>
  <body y="90mm"><text style="subheading">INVOICE {{ number }}</text></body>
  <footer height="20mm"><text style="small">foot</text></footer>
</report-layout>
''';

const _data = <String, Object?>{
  'workspace': 'COWORKONTI',
  'number': 'INV-2026-0050',
  'member': 'Zephyrine Quarterbridge-Okonkwo',
  'client_address': '1 Main Street',
};

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pump();
}

/// The white sheet that holds the report's blocks.
Size _sheetOf(WidgetTester tester) => tester.getSize(
  find
      .ancestor(
        of: find.byType(ReportBlocksView),
        matching: find.byType(Container),
      )
      .first,
);

/// The recipient's field on the layout preview, in points from the sheet.
Rect _field(WidgetTester tester) {
  final box = tester.getRect(
    find.byKey(const ValueKey('layout-preview-recipient-field')),
  );
  final sheet = tester.getTopLeft(find.byType(LayoutPageView));
  return box.shift(-sheet);
}

void main() {
  test('the sheet of a paper, in points', () {
    expect(ReportPage.widthOf(Paper.a4), ReportPage.width);
    expect(ReportPage.heightOf(Paper.a4), ReportPage.height);
    expect(ReportPage.contentHeightOf(Paper.a4), ReportPage.contentHeight);
    expect(ReportPage.widthOf(Paper.letter), closeTo(612, 0.01));
    expect(ReportPage.heightOf(Paper.letter), closeTo(792, 0.01));
  });

  for (final (paper, width) in [(Paper.a4, 595.27559), (Paper.letter, 612.0)]) {
    group('on ${paper.wire}', () {
      testWidgets('the quick view draws the sheet of the report', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => TextButton(
                key: const ValueKey('go'),
                onPressed: () => showReportQuickPreview(
                  context,
                  report: _on(paper),
                  simulated: false,
                ),
                child: const Text('go'),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('go')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(_sheetOf(tester).width, closeTo(width, 0.01));
      });

      testWidgets('the page designer draws the page, its guides and count', (
        tester,
      ) async {
        await _pump(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: ReportPageDesigner(
                header: TextEditingController(text: '# Invoice'),
                body: TextEditingController(),
                footer: TextEditingController(),
                headerLabel: 'Header',
                bodyLabel: 'Body',
                footerLabel: 'Footer',
                editorKeyPrefix: 'sheet-paper',
                previewData: () => const {},
                paper: paper,
              ),
            ),
          ),
        );
        final page = tester.getSize(
          find.byKey(const ValueKey('report-designer-page')),
        );
        expect(page.width, closeTo(width, 0.01));
        expect(page.height, closeTo(paper.heightMm * _mm, 0.01));
        final guides = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((p) => p.painter)
            .whereType<PageBreakGuidePainter>();
        expect(guides.single.paper, paper);
      });

      testWidgets('the layout preview draws the sheet and the window field', (
        tester,
      ) async {
        await _pump(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: LayoutPageView(
                document: renderLayoutDocument(_layout, _data).onPaper(paper),
                data: _data,
              ),
            ),
          ),
        );
        final sheet = tester.getSize(find.byType(LayoutPageView));
        expect(sheet.width, closeTo(width, 0.01));
        expect(sheet.height, closeTo(paper.heightMm * _mm, 0.01));
        // The window's outline: the field of that window on that paper.
        final field = AddressWindow.left.fieldOn(paper);
        final rect = _field(tester);
        expect(rect.left, closeTo(field.leftMm * _mm, 0.5));
        expect(rect.top, closeTo(field.topMm * _mm, 0.5));
        expect(rect.width, closeTo(field.widthMm * _mm, 0.5));
        expect(rect.height, closeTo(field.heightMm * _mm, 0.5));
        // the body resumes below the field, on the paper's own line
        final body = tester.getTopLeft(find.text('INVOICE INV-2026-0050'));
        expect(body.dy, greaterThanOrEqualTo(field.flowResumeMm * _mm - 0.5));
      });

      testWidgets('the reminder letter preview draws the sheet', (
        tester,
      ) async {
        await _pump(
          tester,
          ReminderLetterPreviewPage(
            title: 'Reminder',
            report: _on(paper),
            images: const <String, Uint8List>{},
            canShare: false,
          ),
        );
        expect(_sheetOf(tester).width, closeTo(width, 0.01));
      });

      testWidgets('the setup\'s sample invoice draws the sheet', (
        tester,
      ) async {
        await _pump(
          tester,
          Scaffold(body: SetupSampleSheet(report: _on(paper))),
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('setup-sample-sheet')))
              .width,
          closeTo(width, 0.01),
        );
      });
    });
  }

  testWidgets('the Letter window sits at its own field, not at the A4 one', (
    tester,
  ) async {
    await _pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: LayoutPageView(
            document: renderLayoutDocument(
              _layout,
              _data,
            ).onPaper(Paper.letter),
            data: _data,
          ),
        ),
      ),
    );
    final rect = _field(tester);
    expect(rect.left, closeTo(25.4 * _mm, 0.5));
    expect(rect.top, closeTo(56 * _mm, 0.5));
    expect(rect.width, closeTo(83 * _mm, 0.5));
    expect(rect.height, closeTo(21 * _mm, 0.5));
  });

  group('the Demo\'s New York house, on Letter', () {
    Workspace house() => demoNewYorkSpace().copyWith(id: 'ws-1');

    testWidgets('its invoice\'s quick view is a Letter sheet', (tester) async {
      final money = FakeMoneyRepository();
      await money.createInvoice(
        workspaceId: 'ws-1',
        memberId: 'member-1',
        period: '2026-11',
      );
      // the paper its country froze at issue, as the Demo's invoices carry it
      final invoice = money.invoices.single.copyWith(paper: Paper.letter.wire);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...standardTestOverrides(
              money: money,
              workspace: FakeWorkspaceRepository(workspaces: [house()]),
            ),
            testReadyWorkspaceContext(),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) => TextButton(
                key: const ValueKey('go'),
                onPressed: () => quickViewInvoice(context, ref, invoice),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('go')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.byKey(const ValueKey('report-quick-preview')),
        findsOneWidget,
      );
      expect(_sheetOf(tester).width, closeTo(612, 0.01));
    });

    testWidgets('its designer draws a Letter page', (tester) async {
      // the house's country, currency and clock on the test space's switches
      // (the Demo's own set the money tools aside from this screen)
      final repo = FakeWorkspaceRepository.withWorkspace();
      repo.workspaces[0] = repo.workspaces[0].copyWith(
        countryCode: house().countryCode,
        currencyCode: house().currencyCode,
        timezone: house().timezone,
      );
      await pumpInvoices(tester, money: FakeMoneyRepository(), workspace: repo);
      await tapInvoicingTool(tester, 'invoice-template-button');
      await tester.ensureVisible(
        find.byKey(const ValueKey('invoice-template-mode')),
      );
      await tester.tap(find.text('Visual'));
      await tester.pumpAndSettle();
      final page = tester.getSize(
        find.byKey(const ValueKey('report-designer-page')),
      );
      expect(page.width, closeTo(612, 0.01));
      expect(page.height, greaterThanOrEqualTo(792 - 0.01));
    });
  });
}
