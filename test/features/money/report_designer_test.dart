// SPDX-License-Identifier: 0BSD
//
// #822 — the report editor as a full-screen designer: the page with
// undo / redo, in-place editing in the element's own typography, the
// insert palette, the searchable field picker, drag to reorder, move
// to another band, image size and alignment, guards before replacing
// or leaving, the engine's error spelled out, and the three structural
// documents listed.
import 'dart:convert' show base64Decode;

import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/presentation/report_edit_history.dart';
import 'package:deskilo/features/money/presentation/widgets/report_page_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'invoices_test.dart' show pumpInvoices, seededMoney;

final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQ'
    'DwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

/// Opens the editor page from the Invoices header.
Future<void> openEditor(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('invoice-template-button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('report-editor-page')), findsOneWidget);
}

Future<void> reset(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('invoice-template-reset')));
  await tester.pumpAndSettle();
}

Future<String> markupOf(WidgetTester tester, String band) async {
  await tester.tap(find.text('Markup'));
  await tester.pumpAndSettle();
  final text = tester
      .widget<TextField>(find.byKey(ValueKey('invoice-template-$band')))
      .controller!
      .text;
  await tester.tap(find.text('Visual'));
  await tester.pumpAndSettle();
  return text;
}

Finder _keyPrefix(String prefix) => find.byWidgetPredicate((w) {
      final key = w.key;
      return key is ValueKey<String> && key.value.startsWith(prefix);
    });

void main() {
  group('image markup (#822)', () {
    test('![name|size|align] parses and round-trips; a bare name stays '
        'medium-left and serializes as itself', () {
      final image = ReportImage.parse('logo|l|center');
      expect(image.name, 'logo');
      expect(image.size, ReportImageSize.large);
      expect(image.align, ReportImageAlign.center);
      expect(image.markup, 'logo|l|center');
      expect(ReportImage.parse('logo').markup, 'logo');
      // Order-free, case-free, unknown words ignored.
      final odd = ReportImage.parse('stamp|RIGHT|s|whatever');
      expect(odd.size, ReportImageSize.small);
      expect(odd.align, ReportImageAlign.right);
      final block = parseReportMarkup('![logo|m|right]').single as ReportImage;
      expect(block.align, ReportImageAlign.right);
      expect(reportImageAlignment(block.align), Alignment.centerRight);
    });

    test('a broken band names itself and the engine\'s reason; a sound '
        'one reports nothing', () {
      const broken =
          ReportBands(header: '# ok', footer: '{{ number | nosuchfilter }}');
      final why = reportBandsError(bands: broken, data: const {'voided': false});
      expect(why, isNotNull);
      expect(why, startsWith('footer:'));
      expect(
          reportBandsError(
              bands: const ReportBands(header: '# {{ number }}'),
              data: const {'number': '1'}),
          isNull);
    });
  });

  group('edit history (#822)', () {
    test('typing coalesces into one step, a structural change is its own, '
        'undo and redo walk the stack, a redo tail dies on a new push', () {
      final t0 = DateTime.utc(2026, 9, 2, 10);
      final h = ReportEditHistory(const ReportBands());
      h.push(const ReportBands(header: 'a'), at: t0);
      h.push(const ReportBands(header: 'ab'),
          at: t0.add(const Duration(milliseconds: 200)));
      h.push(const ReportBands(header: 'abc'),
          at: t0.add(const Duration(milliseconds: 400)));
      expect(h.length, 2, reason: 'three keystrokes, one step');
      h.push(const ReportBands(header: 'PRESET'),
          at: t0.add(const Duration(milliseconds: 500)), step: true);
      expect(h.length, 3);
      expect(h.undo().header, 'abc');
      expect(h.undo().header, '');
      expect(h.canUndo, isFalse);
      expect(h.redo().header, 'abc');
      h.push(const ReportBands(header: 'new'),
          at: t0.add(const Duration(seconds: 5)));
      expect(h.canRedo, isFalse);
      expect(h.current.header, 'new');
      // Unchanged bands push nothing.
      h.push(const ReportBands(header: 'new'),
          at: t0.add(const Duration(seconds: 9)));
      expect(h.length, 3);
    });
  });

  testWidgets('the editor opens as a PAGE in Visual mode with undo / redo '
      'in the toolbar; reset is a step undo takes back', (tester) async {
    await pumpInvoices(tester, money: await seededMoney());
    await openEditor(tester);
    expect(find.byKey(const ValueKey('report-designer-page')), findsOneWidget);
    IconButton undo() => tester
        .widget<IconButton>(find.byKey(const ValueKey('report-designer-undo')));
    expect(undo().onPressed, isNull);

    await reset(tester);
    expect(undo().onPressed, isNotNull);
    expect(await markupOf(tester, 'header'), contains('{{ number }}'));

    await tester.tap(find.byKey(const ValueKey('report-designer-undo')));
    await tester.pumpAndSettle();
    expect(await markupOf(tester, 'header'), isEmpty);
    await tester.tap(find.byKey(const ValueKey('report-designer-redo')));
    await tester.pumpAndSettle();
    expect(await markupOf(tester, 'header'), contains('{{ number }}'));
    // The page counts its pages.
    expect(find.byKey(const ValueKey('report-designer-pages')), findsOneWidget);
  });

  testWidgets('Reset and Templates ask before replacing a layout that '
      'exists — and not before an empty one', (tester) async {
    await pumpInvoices(tester, money: await seededMoney());
    await openEditor(tester);
    await reset(tester);
    expect(find.byKey(const ValueKey('report-designer-replace-confirm')),
        findsNothing);
    // A second reset over a filled layout asks.
    await tester.tap(find.byKey(const ValueKey('invoice-template-reset')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-designer-replace-confirm')),
        findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-template-presets')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('invoice-template-preset-simple')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-designer-replace-confirm')),
        findsOneWidget);
    await tester
        .tap(find.byKey(const ValueKey('report-designer-replace-confirm')));
    await tester.pumpAndSettle();
    expect(await markupOf(tester, 'header'), contains('{{ workspace }}'));
  });

  testWidgets('an element is edited in its OWN typography; the insert '
      'palette adds a typed element below; the field picker finds a '
      'field by name and inserts it at the cursor', (tester) async {
    await pumpInvoices(tester, money: await seededMoney());
    await openEditor(tester);
    await reset(tester);
    // Line 1 of the facture layout is the title.
    await tester.ensureVisible(
        find.byKey(const ValueKey('visual-header-line-1')));
    await tester.tap(find.byKey(const ValueKey('visual-header-line-1')));
    await tester.pumpAndSettle();
    final field = tester
        .widget<TextField>(find.byKey(const ValueKey('visual-header-field-1')));
    expect(field.style?.fontSize, ReportPage.heading.fontSize);
    expect(field.style?.fontFamily, ReportPage.fontFamily);

    await tester.tap(find.byKey(const ValueKey('visual-header-insert-1')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('visual-header-insert-1-section')));
    await tester.pumpAndSettle();
    // The new element is selected, a section, right below.
    expect(find.byKey(const ValueKey('visual-header-field-2')), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('visual-header-field-2')), 'Billed to ');
    await tester.tap(find.byKey(const ValueKey('visual-header-fields-2')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('report-fields-search')), 'memb');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-field-number')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('report-field-member')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('visual-header-done-2')));
    await tester.pumpAndSettle();
    expect(await markupOf(tester, 'header'), contains('## Billed to {{ member }}'));
  });

  testWidgets('an element moves to another band from its menu, and a '
      'long-press drag reorders lines', (tester) async {
    await pumpInvoices(tester, money: await seededMoney());
    await openEditor(tester);
    // The agreement is a flat letter — no column fences in the way.
    await tester.ensureVisible(
        find.byKey(const ValueKey('invoice-template-doc-agreement')));
    await tester
        .tap(find.byKey(const ValueKey('invoice-template-doc-agreement')));
    await tester.pumpAndSettle();
    await reset(tester);
    final before = await markupOf(tester, 'header');
    final lines = before.split('\n');
    expect(lines.length, greaterThan(1));

    // Move line 0 (the title) to the footer.
    await tester.ensureVisible(
        find.byKey(const ValueKey('visual-header-line-0')));
    await tester.tap(find.byKey(const ValueKey('visual-header-line-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('visual-header-moveto-0')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('visual-header-moveto-0-footer')));
    await tester.pumpAndSettle();
    expect(await markupOf(tester, 'header'), isNot(contains(lines.first)));
    expect(await markupOf(tester, 'footer'), contains(lines.first));

    // Drag: the header's line 1 lands before its line 0.
    final header = await markupOf(tester, 'header');
    final h = header.split('\n');
    expect(h.length, greaterThan(1));
    final from = find.byKey(const ValueKey('visual-header-line-1'));
    final onto = find.byKey(const ValueKey('visual-header-drop-0'));
    await tester.ensureVisible(from);
    final gesture = await tester.startGesture(tester.getCenter(from));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(tester.getCenter(onto));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    final after = (await markupOf(tester, 'header')).split('\n');
    expect(after.first, h[1]);
    expect(after[1], h[0]);
  });

  testWidgets('an image gets a size and an alignment on the page, written '
      'as ![name|size|align] and honoured by the preview', (tester) async {
    final money = await seededMoney();
    money.reportImages['logo.png'] = _png;
    await pumpInvoices(tester, money: money);
    await openEditor(tester);
    await tester.tap(find.byKey(const ValueKey('invoice-template-image')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report-image-logo.png')));
    await tester.pumpAndSettle();
    // The new image element is selected with its controls.
    expect(_keyPrefix('visual-header-image-size-'), findsOneWidget);
    await tester.tap(find.text('Large'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.format_align_center));
    await tester.pumpAndSettle();
    expect(await markupOf(tester, 'header'), contains('![logo.png|l|center]'));

    // Preview draws it large and centred.
    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('report-designer-mode')),
        matching: find.text('Preview')));
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.descendant(
        of: find.byKey(const ValueKey('report-designer-preview')),
        matching: find.byType(Image)));
    expect(image.height, ReportImageSize.large.height);
    final align = tester.widget<Align>(find.ancestor(
        of: find.byWidget(image), matching: find.byType(Align)).first);
    expect(align.alignment, Alignment.center);
  });

  testWidgets('a template that does not render says which band and why; '
      'the structural documents have chips', (tester) async {
    await pumpInvoices(tester, money: await seededMoney());
    await openEditor(tester);
    for (final doc in ['coa', 'badges', 'space_codes']) {
      expect(find.byKey(ValueKey('invoice-template-doc-$doc')), findsOneWidget,
          reason: doc);
    }
    await tester.tap(find.text('Markup'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('invoice-template-footer')),
        '{{ number | nosuchfilter }}');
    await tester.tap(find.text('Visual'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('report-designer-mode')),
        matching: find.text('Preview')));
    await tester.pumpAndSettle();
    final error = tester.widget<Text>(
        find.byKey(const ValueKey('report-designer-preview-error')));
    expect(error.data, contains('footer:'));
  });

  testWidgets('leaving with unsaved work asks; Keep editing stays, Discard '
      'leaves', (tester) async {
    await pumpInvoices(tester, money: await seededMoney());
    await openEditor(tester);
    await reset(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-designer-discard')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('report-designer-keep-editing')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-editor-page')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report-designer-discard')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-editor-page')), findsNothing);
  });

  testWidgets('a language with its own bands wears a dot, and the overlay '
      'can be cleared back to the default', (tester) async {
    await pumpInvoices(tester, money: await seededMoney());
    await openEditor(tester);
    expect(find.byKey(const ValueKey('invoice-template-lang-own-fr')),
        findsNothing);
    await tester.tap(find.byKey(const ValueKey('invoice-template-lang-fr')));
    await tester.pumpAndSettle();
    await reset(tester);
    expect(find.byKey(const ValueKey('invoice-template-lang-own-fr')),
        findsOneWidget);
    await tester.ensureVisible(
        find.byKey(const ValueKey('invoice-template-clear-overlay')));
    await tester.tap(
        find.byKey(const ValueKey('invoice-template-clear-overlay')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invoice-template-lang-own-fr')),
        findsNothing);
  });

  testWidgets('with the flag off the editor stays a sheet', (tester) async {
    final money = await seededMoney();
    await pumpInvoices(
      tester,
      money: money,
      workspace: FakeWorkspaceRepository.withWorkspace(
          featureFlags: const {'reportDesigner': false}),
    );
    await tester.tap(find.byKey(const ValueKey('invoice-template-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-editor-page')), findsNothing);
    expect(find.byKey(const ValueKey('invoice-template-header')), findsOneWidget);
  });
}
