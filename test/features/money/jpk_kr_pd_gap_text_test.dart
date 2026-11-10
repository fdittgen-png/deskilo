// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3380 — a Polish refusal is worded by the catalogue, whole, in every
// language: no English clause inside a translated message.
import 'package:deskilo/features/money/presentation/accounting_export_journal.dart';
import 'package:deskilo/features/money/presentation/saft_gap_text.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/dictionary_labels.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _street = JpkKrPdGap(
  JpkKrPdGapCode.tooLong,
  field: JpkKrPdField.street,
  limit: 65,
);

void main() {
  for (final (locale, field, tail) in [
    ('en', 'street', 'is longer than 65 characters'),
    ('fr', 'rue', 'dépasse 65 caractères'),
    ('de', 'Straße', 'ist länger als 65 Zeichen'),
  ]) {
    testWidgets('a 66-character street is refused in full in $locale', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(Locale(locale));
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => exportGenericJournal(
                  context,
                  () async => JournalSafTRefused([SafTGap.polish(_street)]),
                  save: (_) async {},
                ),
                child: const Text('export'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('export'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining(field), findsOneWidget);
      expect(find.textContaining(tail), findsOneWidget);
      expect(find.textContaining('exceeds schema length'), findsNothing);
      expect(
        find.text(
          l10n.journalSafTRefused(safTGapText(l10n, SafTGap.polish(_street))),
        ),
        findsOneWidget,
      );
    });
  }

  test('every code and every field has words in all five languages', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final code in JpkKrPdGapCode.values) {
        final text = safTGapText(
          l10n,
          SafTGap.polish(
            JpkKrPdGap(code, field: JpkKrPdField.nip, subject: 'X', limit: 1),
          ),
        );
        expect(text.trim(), isNotEmpty, reason: '${code.name} in $locale');
      }
      for (final field in JpkKrPdField.values) {
        expect(
          l10n.jpkKrPdField(field.name).trim(),
          isNotEmpty,
          reason: '${field.name} in $locale',
        );
      }
    }
  });
}
