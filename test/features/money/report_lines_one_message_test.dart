// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3768 — a report line with a print-time value is ONE message: the day count
// of a reminder carries its plural in the document's language, and the lines
// that stood beside a token in the default templates are whole messages.
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/report_data_letters.dart';
import 'package:deskilo/features/money/domain/report_facts.dart';
import 'package:deskilo/features/money/presentation/report_defaults.dart';
import 'package:deskilo/features/money/presentation/report_defaults_purchase_order.dart';
import 'package:deskilo/features/money/presentation/report_strings_l10n.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/app_localizations_de.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo/l10n/app_localizations_es.dart';
import 'package:deskilo/l10n/app_localizations_fr.dart';
import 'package:deskilo/l10n/app_localizations_it.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

const _workspace = Workspace(
  id: 'ws-1',
  name: 'Test Space',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'CODE123456',
  invoiceLegal: {'is_association': false},
);

final _invoice = Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'm1',
  number: 'INV-2026-0007',
  issuedAt: DateTime(2026, 7),
  title: '2026-07',
  lines: const [],
  totalCents: 12000,
  currency: 'EUR',
  memberName: 'Ana Martin',
  memberAddress: '',
  workspaceName: 'Test Space',
  workspaceAddress: '',
  issuerName: 'Flo',
  signature: 'f',
);

final _languages = <String, AppLocalizations>{
  'en': AppLocalizationsEn(),
  'de': AppLocalizationsDe(),
  'fr': AppLocalizationsFr(),
  'es': AppLocalizationsEs(),
  'it': AppLocalizationsIt(),
};

Map<String, Object?> _reminder(AppLocalizations l10n, int days) =>
    reminderReportData(
      reportStringsOf(l10n, formatLocale: null),
      ReminderFacts(
        now: DateTime(2026, 7).add(Duration(days: days)),
        workspace: _workspace,
      ),
      _invoice,
      level: 1,
      reference: ActiveTaxReference.current,
    );

void main() {
  group('a reminder letter says how long the invoice has been open', () {
    const one = {
      'en': 'Open for 1 day',
      'de': 'Offen seit 1 Tag',
      'fr': 'Ouverte depuis 1 jour',
      'es': 'Abierta desde hace 1 día',
      'it': 'Aperta da 1 giorno',
    };
    const many = {
      'en': 'Open for 12 days',
      'de': 'Offen seit 12 Tagen',
      'fr': 'Ouverte depuis 12 jours',
      'es': 'Abierta desde hace 12 días',
      'it': 'Aperta da 12 giorni',
    };
    for (final MapEntry(key: code, value: l10n) in _languages.entries) {
      test('$code: one day is one day, twelve days is a plural', () {
        expect(_reminder(l10n, 1)['days_open_text'], one[code]);
        expect(_reminder(l10n, 12)['days_open_text'], many[code]);
        // The count stays a number for a design a business saved itself.
        expect(_reminder(l10n, 12)['days_open'], 12);
      });
    }

    test('the default letter holds the whole line, not a unit after a number',
        () {
      final bands = defaultReminderBands(1, AppLocalizationsEn());
      expect(bands.body, contains('{{ days_open_text }}'));
      expect(bands.body, isNot(contains('{{ days_open }}')));
    });
  });

  group('the other lines are one message per language', () {
    test('the purchase order names its expected delivery as a whole line', () {
      const expected = {
        'en': 'Expected delivery {{ expected_on }}',
        'de': 'Erwartete Lieferung am {{ expected_on }}',
        'fr': 'Livraison prévue le {{ expected_on }}',
        'es': 'Entrega prevista el {{ expected_on }}',
        'it': 'Consegna prevista il {{ expected_on }}',
      };
      for (final MapEntry(key: code, value: l10n) in _languages.entries) {
        expect(purchaseOrderBands(l10n).header, contains(expected[code]));
      }
    });

    test('a formal letter places its subject in the language', () {
      const subject = {
        'en': 'Subject: x',
        'de': 'Betreff: x',
        'fr': 'Objet : x',
        'es': 'Asunto: x',
        'it': 'Oggetto: x',
      };
      for (final MapEntry(key: code, value: l10n) in _languages.entries) {
        expect(l10n.reportSubjectLine('x'), subject[code]);
      }
    });
  });
}
