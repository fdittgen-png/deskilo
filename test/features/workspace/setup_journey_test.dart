// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2868 — the pieces behind the stored answers: the answers read and write
// the same keys the questions are asked under, a stored journey keeps only
// processes and levels the app knows, the recommendation rules are
// well-formed data, and the obligations shown beside the questions are the
// reference rows of the country — dated, sourced, confirmed or not —
// never a claim the data does not make.
import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/features/workspace/domain/setup_journey.dart';
import 'package:deskilo/features/workspace/domain/setup_levels.dart';
import 'package:deskilo/features/workspace/domain/setup_obligations.dart';
import 'package:flutter_test/flutter_test.dart';

TaxReferenceRow _mandate(
  String country,
  String duty,
  String from, {
  bool confirmed = false,
  String validFrom = '1900-01-01',
  String? validTo,
}) => TaxReferenceRow(
  country: country,
  key: duty,
  validFrom: validFrom,
  validTo: validTo,
  value: MandateValue(duty: duty, from: from),
  source: 'law of $country',
  confirmed: confirmed,
);

void main() {
  group('answers', () {
    test('read and write every question under its key', () {
      for (final q in setupQuestions) {
        final yes = const SetupAnswers().withAnswer(q, yes: true);
        expect(yes[q], isTrue, reason: q);
        expect(setupQuestions.where((other) => yes[other]), [
          q,
        ], reason: 'only $q is answered yes');
        expect(SetupAnswers.fromJson(yes.toJson()), yes);
      }
    });

    test('a missing or unknown answer is a no; a malformed one is a '
        'defect, not a no', () {
      final answers = SetupAnswers.fromJson({'retired_question': true});
      expect(answers, const SetupAnswers());
      expect(() => answers['retired_question'], throwsArgumentError);
      expect(
        () => SetupAnswers.fromJson({'issue_invoices': 'yes'}),
        throwsA(isA<JsonShapeException>()),
      );
    });
  });

  test('a stored journey keeps only the processes and levels the app has', () {
    final journey = SetupJourney.fromJson({
      'answers': {'vat_registered': true},
      'levels': {'money': 'invoices', 'tax': 'gold', 'catering': 'full'},
      'version': 3,
      'updated_at': '2026-10-23T10:00:00Z',
      'updated_by_name': 'Ada OWNER',
    })!;
    expect(journey.answers.vatRegistered, isTrue);
    expect(journey.levels, {SetupProcess.money: 'invoices'});
    expect(journey.version, 3);
    expect(journey.updatedByName, 'Ada OWNER');
    expect(SetupJourney.fromJson(null), isNull);
  });

  test('the recommendation rules are data the page can run', () {
    expect(setupRecommendationRules.keys.toSet(), SetupProcess.values.toSet());
    for (final MapEntry(key: process, value: rules)
        in setupRecommendationRules.entries) {
      expect(
        rules.last.anyOf,
        isEmpty,
        reason: '${process.name}: the last rule must always hold',
      );
      for (final rule in rules) {
        expect(
          setupLevels[process]!.map((l) => l.id),
          contains(rule.level),
          reason: '${process.name}: ${rule.level}',
        );
        expect(setupQuestions, containsAll(rule.anyOf));
      }
    }
  });

  group('obligations', () {
    final reference = TaxReferenceSet([
      _mandate('FR', 'issue_all', '2027-09-01'),
      _mandate('FR', 'receive_all', '2026-09-01', confirmed: true),
      // A planned change nobody confirmed stays behind the version it
      // would close.
      _mandate('FR', 'e_reporting', '2026-09-01', validTo: '2026-01-01'),
      _mandate('FR', 'e_reporting', '2028-01-01', validFrom: '2026-01-01'),
      const TaxReferenceRow(
        country: 'FR',
        key: 'small_business_next_year',
        validFrom: '1900-01-01',
        value: ThresholdValue(
          cents: 3750000,
          effect: 'next_year',
          currency: 'EUR',
        ),
        source: 'CGI art. 293 B',
        confirmed: true,
      ),
      _mandate('*', 'issue_all', '2030-01-01'),
    ]);

    test('the duties by date, then the limits, each with its source and '
        'whether it was confirmed', () {
      final rows = setupObligations('fr', reference: reference);
      expect(
        [for (final o in rows) '${o.kind.name} ${o.detail} ${o.from}'],
        [
          'einvoicing e_reporting 2026-09-01',
          'einvoicing receive_all 2026-09-01',
          'einvoicing issue_all 2027-09-01',
          'vatThreshold next_year null',
        ],
      );
      expect([for (final o in rows) o.confirmed], [false, true, false, true]);
      expect(rows.last.cents, 3750000);
      expect(rows.last.source, 'CGI art. 293 B');
      expect(rows.first.kind.question, 'issue_invoices');
      expect(rows.last.kind.question, 'vat_registered');
    });

    test('a country without rows has none, not the shared ones', () {
      expect(setupObligations('PT', reference: reference), isEmpty);
    });
  });
}
