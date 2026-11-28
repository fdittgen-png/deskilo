// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4501 -- an exempt or out-of-scope VAT rate's reason is picked from the VATEX codes, never typed: the pick writes the
// code's legal wording in the business's document language, a stored wording of a code shows as that code in any
// language, and a stored wording no code has stays visible, as its own choice, until another is picked.
import 'package:deskilo/core/ui/form_kit.dart';
import 'package:deskilo/features/money/domain/vat_exemption_reasons.dart';
import 'package:deskilo/features/money/presentation/widgets/vat_exemption_field.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_de.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo/l10n/app_localizations_fr.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();
final _fr = AppLocalizationsFr();

const _workspace = Workspace(
  id: 'ws-1',
  name: 'Atelier',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
  defaultLocale: 'fr',
);

Future<List<String>> _pump(WidgetTester tester, {required String category, String value = ''}) async {
  final written = <String>[];
  await pumpApp(
    tester,
    Scaffold(
      body: VatExemptionField(
        key: const ValueKey('reason'),
        category: category,
        value: value,
        label: 'Reason',
        onChanged: written.add,
      ),
    ),
    overrides: [currentWorkspaceProvider.overrideWith((ref) async => _workspace)],
  );
  await tester.pumpAndSettle();
  return written;
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('reason')));
  await tester.pumpAndSettle();
}

void main() {
  test('the codes of a category and their word stems', () {
    expect(vatExemptionCodesOf('E'), vatRateExemptionCodes['E']);
    expect(vatExemptionCodesOf('O'), [vatexOutsideScope]);
    expect(vatExemptionCodesOf('S'), isEmpty);
    expect(vatExemptionCodesOf('Z'), isEmpty);
    expect(vatexArbStem('VATEX-EU-79-C'), '79c');
    expect(vatexArbStem('VATEX-EU-132'), '132');
    expect(vatexArbStem(vatexOutsideScope), 'O');
    // every code has its name and wording in every language the app ships
    for (final code in [...vatExemptionCodesOf('E'), ...vatExemptionCodesOf('O')]) {
      expect(vatExemptionLabel(_en, code), isNotEmpty);
      expect(vatExemptionWording(_fr, code), isNotEmpty);
    }
  });

  testWidgets('an exempt rate offers the exempting articles; the pick writes the wording in the document language', (
    tester,
  ) async {
    final written = await _pump(tester, category: 'E');
    await _open(tester);
    for (final code in vatExemptionCodesOf('E')) {
      expect(find.text(vatExemptionLabel(_en, code)).last, findsOneWidget);
    }
    await tester.tap(find.text(_en.vatex132Label).last);
    await tester.pumpAndSettle();
    expect(written, [_fr.vatex132Text]);
  });

  testWidgets('an out-of-scope rate offers its one reason', (tester) async {
    final written = await _pump(tester, category: 'O');
    await _open(tester);
    await tester.tap(find.text(_en.vatexOLabel).last);
    await tester.pumpAndSettle();
    expect(written, [_fr.vatexOLabel]);
  });

  testWidgets('a stored wording of a code shows as that code, whatever its language', (tester) async {
    await _pump(tester, category: 'E', value: AppLocalizationsDe().vatex148Text);
    expect(find.text(_en.vatex148Label), findsOneWidget);
  });

  testWidgets('a stored wording no code has stays visible until another is picked', (tester) async {
    final written = await _pump(tester, category: 'E', value: 'Article 261 CGI');
    expect(find.text('Article 261 CGI'), findsOneWidget);
    await _open(tester);
    await tester.tap(find.text('Article 261 CGI').last);
    await tester.pumpAndSettle();
    expect(written, isEmpty, reason: 'keeping the stored wording changes nothing');
    await _open(tester);
    await tester.tap(find.text(_en.vatex309Label).last);
    await tester.pumpAndSettle();
    expect(written, [_fr.vatex309Text]);
  });

  testWidgets('the tax reference sheet shows the reason for E and O, and for any rate that holds one', (tester) async {
    final fields = FormControllers({'reason': ''});
    addTearDown(fields.dispose);
    Future<void> show(String category) async {
      await pumpApp(
        tester,
        Scaffold(body: taxReferenceExemptionField(fields, category, 'Reason')),
        overrides: [currentWorkspaceProvider.overrideWith((ref) async => _workspace)],
      );
      await tester.pumpAndSettle();
    }

    await show('S');
    expect(find.byType(VatExemptionField), findsNothing);
    await show('E');
    expect(find.byType(VatExemptionField), findsOneWidget);
    fields['reason'].text = 'hors champ';
    await show('S');
    expect(find.text('hors champ'), findsOneWidget);
  });
}
