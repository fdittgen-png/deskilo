// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2571 -- a retention refusal is read from the server's error and said in
// every language; nothing else is mistaken for one.
import 'dart:convert';

import 'package:deskilo/core/trace/retention_text.dart';
import 'package:deskilo/core/vat/retention_assessment.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

void main() {
  final review = {
    'disposition': 'review_required',
    'retain_until': '2012-12-31',
    'indefinite': false,
    'rule': {'source': 'Code de commerce L123-22'},
    'holds': <Object?>[],
    'reasons': ['fiscal_calendar_assumed', 'unconfirmed'],
  };

  test('the refusal carries the assessment; other errors are not one', () {
    final kept = retentionRefusalOf(
      PostgrestException(message: 'retention: ...', code: 'DKE01', details: jsonEncode(review)),
    );
    expect(kept?.disposition, RetentionDisposition.reviewRequired);
    expect(kept?.retainUntil, DateTime(2012, 12, 31));
    expect(kept?.reasons, ['fiscal_calendar_assumed', 'unconfirmed']);
    expect(retentionRefusalOf(const PostgrestException(message: 'x', code: '42501')), isNull);
    expect(retentionRefusalOf(const PostgrestException(message: 'x', code: 'DKE01', details: 'not json')),
        isNull);
    expect(retentionRefusalOf(StateError('x')), isNull);
  });

  test('no disposition is nothing to keep', () {
    expect(RetentionAssessment.fromJson({'disposition': null, 'issuers': <Object?>[]}), isNull);
    expect(RetentionAssessment.fromJson(null), isNull);
  });

  test('the stricter of two: a hold, then a running clock, then a review, then the later end', () {
    RetentionAssessment a(RetentionDisposition d, String? until, {bool hold = false}) => RetentionAssessment(
      disposition: d,
      retainUntil: until == null ? null : DateTime.parse(until),
      indefinite: hold,
    );
    final ended = a(RetentionDisposition.eligible, '2010-01-01');
    final review = a(RetentionDisposition.reviewRequired, '2011-01-01');
    final clock = a(RetentionDisposition.retain, '2030-01-01');
    final later = a(RetentionDisposition.retain, '2035-01-01');
    final hold = a(RetentionDisposition.retain, '2001-01-01', hold: true);
    expect(RetentionAssessment.strictest(ended, review), review);
    expect(RetentionAssessment.strictest(review, clock), clock);
    expect(RetentionAssessment.strictest(clock, later), later);
    expect(RetentionAssessment.strictest(later, hold), hold);
    expect(RetentionAssessment.strictest(null, ended), ended);
  });

  test('every disposition reads in all five languages', () async {
    await initializeDateFormatting();
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final tag = locale.toLanguageTag();
      for (final kept in [
        RetentionAssessment.fromJson(review)!,
        RetentionAssessment(disposition: RetentionDisposition.retain, retainUntil: DateTime(2036, 12, 31), ruleSource: 'R'),
        const RetentionAssessment(disposition: RetentionDisposition.retain, indefinite: true, holdReasons: ['audit']),
        const RetentionAssessment(disposition: RetentionDisposition.eligible),
      ]) {
        expect(retentionAssessmentText(l10n, kept, tag), isNotEmpty, reason: '$locale');
      }
    }
    final en = lookupAppLocalizations(const Locale('en'));
    expect(
      retentionAssessmentText(en, const RetentionAssessment(disposition: RetentionDisposition.eligible), 'en'),
      'The retention period has ended: the space may review the erasure',
    );
  });
}
