// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3809 (part of #3657) -- a room charge's line prints from the facts the
// server froze with it, in the document's language. What this reader cannot
// read (an unknown kind or version, unreadable values) prints the frozen
// label, never an empty or invented text; a line written before the facts
// existed prints exactly as it did.
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/presentation/report_strings_l10n.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo/l10n/app_localizations_fr.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _label = 'Rented room · 2027-04-12';

const _roomDay = <String, Object?>{
  'kind': 'room_day',
  'version': 1,
  'values': {'room': 'Salle louée', 'day': '2027-04-12'},
};

InvoiceLine _line(Map<String, Object?>? text, {String kind = 'service'}) =>
    InvoiceLine(kind: kind, label: _label, amountCents: 1500, text: text);

void main() {
  setUpAll(initializeDateFormatting);
  final fr = reportStringsOf(AppLocalizationsFr(), formatLocale: 'fr_FR');
  final en = reportStringsOf(AppLocalizationsEn(), formatLocale: 'en_GB');

  test('a room charge reads in French on a French document', () {
    expect(invoiceLineText(fr, _line(_roomDay)), 'Salle louée · 12 avr. 2027');
    expect(invoiceLineText(en, _line(_roomDay)), 'Salle louée · Apr 12, 2027');
  });

  test('its reversal says what was taken back, in the same language', () {
    const cancelled = <String, Object?>{
      'kind': 'cancelled',
      'version': 1,
      'values': {'of': _roomDay},
    };
    expect(
      invoiceLineText(fr, _line(cancelled, kind: 'adjustment')),
      'Annulé : Salle louée · 12 avr. 2027',
    );
    expect(
      invoiceLineText(en, _line(cancelled, kind: 'adjustment')),
      'Cancelled: Salle louée · Apr 12, 2027',
    );
  });

  test('what this reader cannot read prints the frozen label', () {
    for (final facts in <Map<String, Object?>>[
      {..._roomDay, 'kind': 'from_a_later_version'},
      {..._roomDay, 'version': 2},
      {..._roomDay, 'values': 'not an object'},
      {
        ..._roomDay,
        'values': {'room': 'Salle', 'day': 'not a day'},
      },
      {
        'kind': 'cancelled',
        'version': 1,
        'values': {'of': 'nothing readable'},
      },
    ]) {
      expect(invoiceLineText(fr, _line(facts)), _label, reason: '$facts');
    }
  });

  test('a line written without facts prints exactly as before', () {
    expect(invoiceLineText(fr, _line(null)), _label);
  });

  test('the annex prints the same facts behind its category', () {
    const entry = InvoiceDetailEntry(
      on: '2027-04-12',
      category: 'service',
      label: _label,
      amountCents: 1500,
      text: _roomDay,
    );
    expect(
      annexEntryText(fr, entry),
      '${fr.categoryService} · Salle louée · 12 avr. 2027',
    );
  });

  test(
    'the snapshot reader keeps the facts and ignores what is not an object',
    () {
      expect(
        invoiceLineFromSnapshot({'label': _label, 'text': _roomDay}).text,
        _roomDay,
      );
      expect(
        invoiceLineFromSnapshot({'label': _label, 'text': 'x'}).text,
        isNull,
      );
      expect(invoiceLineFromSnapshot({'label': _label}).text, isNull);
    },
  );
}
