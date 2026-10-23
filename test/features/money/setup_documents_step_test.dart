// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2875 — the invoice look step of the setup guide. The step says which
// design the invoices print with; the preview is a sample invoice through
// the report engine with the workspace's own design (its letterhead) or
// the built-in one, marked as a sample and never numbered from a series;
// a look being tried redraws the sample before anything is saved, and
// "Use this look" stores it as the invoice's bands, keeping the rest of
// the template. One column on a phone.
import 'package:deskilo/app/routes/setup_grow_pages.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/presentation/report_defaults.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 2400);

/// An owner's own design: a letterhead line no shipped look prints.
const _own = InvoicePdfTemplate(
  header: '# {{ workspace }}\n> Letterhead of the owner',
  body: '{{ number }} · {{ member }} · {{ total }}',
  texts: {'greeting': 'Hello'},
);

Future<void> _pump(WidgetTester tester, FakeMoneyRepository money) async {
  await pumpApp(
    tester,
    const SetupStepScreen(stepId: 'documents', growPages: setupGrowPages),
    size: _phone,
    overrides: standardTestOverrides(money: money),
  );
  await tester.pumpAndSettle();
}

Finder _inSample(Finder f) => find.descendant(
  of: find.byKey(const ValueKey('setup-sample-sheet')),
  matching: f,
);

void main() {
  testWidgets('the owner\'s own design prints the sample: the letterhead, '
      'SAMPLE where the number goes, no series number', (tester) async {
    final money = FakeMoneyRepository()..pdfTemplate = _own;
    await _pump(tester, money);
    expect(find.byKey(const ValueKey('setup-documents-own')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('setup-documents-replaces')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('setup-sample-badge')), findsOneWidget);
    expect(_inSample(find.text('Letterhead of the owner')), findsOneWidget);
    expect(_inSample(find.textContaining('SAMPLE · A member')), findsOneWidget);
    expect(_inSample(find.textContaining('INV-')), findsNothing);
    expect(money.numberSequences['invoice']!.nextValue, 1);
  });

  testWidgets('a look is tried in the sample before saving, and Use this look '
      'stores it as the invoice bands, the rest of the template kept', (
    tester,
  ) async {
    // Owner texts but no bands of its own: the built-in design prints.
    final money = FakeMoneyRepository()
      ..pdfTemplate = const InvoicePdfTemplate(texts: {'greeting': 'Hi'});
    await _pump(tester, money);
    expect(
      find.byKey(const ValueKey('setup-documents-built-in')),
      findsOneWidget,
    );
    final simple = presetsForDoc(
      'invoice',
      AppLocalizationsEn(),
    ).firstWhere((p) => p.id == 'simple');
    final before = tester
        .widgetList<Text>(_inSample(find.byType(Text)))
        .map((t) => t.data)
        .toList();

    await tester.tap(find.byKey(const ValueKey('setup-documents-look-simple')));
    await tester.pump();
    final tried = tester
        .widgetList<Text>(_inSample(find.byType(Text)))
        .map((t) => t.data)
        .toList();
    expect(tried, isNot(before));
    expect(money.pdfTemplate.hasBands, isFalse, reason: 'nothing saved yet');

    await tester.tap(find.byKey(const ValueKey('setup-documents-apply')));
    await tester.pumpAndSettle();
    expect(money.pdfTemplate.header, simple.bands.header);
    expect(money.pdfTemplate.body, simple.bands.body);
    expect(money.pdfTemplate.texts, {'greeting': 'Hi'});
    expect(find.text('The invoice look is saved.'), findsOneWidget);
  });

  testWidgets('one column on a phone', (tester) async {
    await _pump(tester, FakeMoneyRepository()..pdfTemplate = _own);
    expect(find.byKey(const ValueKey('setup-step-one-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
