// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3852 — the paper the business's documents are printed on. The settings
// offer the papers the country's row allows, follow the country by default,
// and say why when it allows one only. A country whose invoices end on a
// payment slip allows A4 only, in the reference rows the app and the server
// both read, so the slips the app installs and the catalogue cannot drift.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/country/country_catalog.dart';
import 'package:deskilo/core/country/country_rows.dart';
import 'package:deskilo/core/country/country_seed.g.dart';
import 'package:deskilo/core/jurisdiction/installed_payment_slips.dart';
import 'package:deskilo/core/ui/form_kit.dart';
import 'package:deskilo/features/money/presentation/widgets/tax_reference_gate_fields.dart';
import 'package:deskilo/features/money/presentation/widgets/tax_reference_paper_fields.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/presentation/screens/workspace_settings_form.dart';
import 'package:deskilo/features/workspace/presentation/widgets/workspace_paper_field.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_document_model/paper.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _l10n = AppLocalizationsEn();

Workspace _workspace(String country, {String? paper}) => Workspace(
  id: 'ws-1',
  name: 'Space',
  countryCode: country,
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'X',
  paper: paper,
);

List<Country> _referenceCountries() => countriesOfReference(
  TaxReferenceSet.parse(
    jsonDecode(File('assets/instance/tax_reference.json').readAsStringSync()),
  ),
);

void main() {
  group('the country rows', () {
    test('the United States and Canada use Letter; Switzerland A4 only', () {
      (Paper, String) papers(Country c) =>
          (c.paper, c.papers.map((p) => p.wire).join(','));
      Country of(String code) =>
          _referenceCountries().firstWhere((c) => c.code == code);
      expect(papers(of('US')), (Paper.letter, 'A4,Letter'));
      expect(papers(of('CA')), (Paper.letter, 'A4,Letter'));
      expect(papers(of('CH')), (Paper.a4, 'A4'));
      expect(papers(of('FR')), (Paper.a4, 'A4,Letter'));
    });

    test('the bundled copy reads the papers the rows name', () {
      expect(
        [
          for (final c in bundledCountries)
            (c.code, c.paper, c.papers.join(',')),
        ],
        [
          for (final c in _referenceCountries())
            (c.code, c.paper, c.papers.join(',')),
        ],
      );
    });

    test(
      'every country whose invoices end on a payment slip allows A4 only',
      () {
        final slips = [
          for (final c in _referenceCountries())
            if (paymentSlipOf(c.code) != null) c,
        ];
        expect(slips, isNotEmpty);
        for (final c in slips) {
          expect(c.papers, [
            Paper.a4,
          ], reason: '${c.code} ends its invoices on a slip printed on A4');
        }
      },
    );
  });

  group('the settings form', () {
    test('it keeps the stored paper and sends it, empty when it follows the country', () {
      final form = WorkspaceSettingsForm()
        ..seedOnce(_workspace('FR', paper: 'Letter'));
      addTearDown(form.dispose);
      expect(form.paper.value, Paper.letter);
      expect(form.toSave('FR').toSettings()['paper'], 'Letter');
      form.paper.value = null;
      expect(form.toSave('FR').toSettings()['paper'], '');
    });

    test('a country that does not use the paper chosen makes it follow the country', () {
      final form = WorkspaceSettingsForm()
        ..seedOnce(_workspace('FR', paper: 'Letter'));
      addTearDown(form.dispose);
      form.pickCountry('US');
      expect(
        form.paper.value,
        Paper.letter,
        reason: 'the United States allow Letter',
      );
      form.pickCountry('CH');
      expect(form.paper.value, isNull);
    });
  });

  group('the paper field', () {
    Future<void> pump(WidgetTester tester, String country) => pumpApp(
      tester,
      Scaffold(
        body: WorkspacePaperField(
          countryCode: country,
          paper: ValueNotifier(null),
          enabled: true,
        ),
      ),
    );

    testWidgets('in the United States it follows Letter, and offers both', (
      tester,
    ) async {
      await pump(tester, 'US');
      expect(find.text('US Letter (usual in United States)'), findsOneWidget);
      expect(find.text(_l10n.workspacePaperHelper), findsOneWidget);
      await tester.tap(find.byKey(const Key('workspaceSettingsPaper')));
      await tester.pumpAndSettle();
      expect(find.text('A4'), findsWidgets);
      expect(find.text('US Letter'), findsWidgets);
    });

    testWidgets('in Switzerland it says why A4 is the only paper', (
      tester,
    ) async {
      await pump(tester, 'CH');
      expect(find.text(_l10n.workspacePaperOnlySlip('A4')), findsOneWidget);
      final field = tester.widget<DropdownButtonFormField<Paper?>>(
        find.byKey(const Key('workspaceSettingsPaper')),
      );
      expect(field.onChanged, isNull);
    });
  });

  group('the reference editor', () {
    FormControllers fields(String papers) =>
        FormControllers({'papers': papers});

    test('it keeps the papers of a row, and A4 is what no paper means', () {
      final ch = documentPaperValueOf(fields('A4'), {'paper': 'A4'});
      expect(ch.paper, isNull);
      expect(ch.papers, ['A4']);
      final us = documentPaperValueOf(fields(''), {'paper': 'Letter'});
      expect(us.paper, 'Letter');
      expect(us.papers, isNull);
    });

    test('it refuses papers it does not print on, twice the same, or without the usual one', () {
      for (final papers in ['A4, Legal', 'A4, A4', 'A4']) {
        expect(
          documentPaperFieldErrors(_l10n, fields(papers), {'paper': 'Letter'}),
          containsPair('papers', _l10n.taxRefInvalidPapers),
          reason: papers,
        );
      }
      expect(
        documentPaperFieldErrors(_l10n, fields('Letter, A4'), {
          'paper': 'Letter',
        }),
        isEmpty,
      );
      expect(
        documentPaperFieldErrors(_l10n, fields(''), {'paper': 'Letter'}),
        isEmpty,
      );
    });

    test('the row it copies seeds the usual paper and the papers', () {
      const ch = DocumentPaperValue(papers: ['A4']);
      expect(taxReferenceChoicesOf(ch)['paper'], 'A4');
      expect(documentPaperTexts(ch)['papers'], 'A4');
      expect(
        taxReferenceChoicesOf(
          const DocumentPaperValue(paper: 'Letter'),
        )['paper'],
        'Letter',
      );
    });
  });
}
