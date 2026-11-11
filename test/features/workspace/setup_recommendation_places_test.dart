// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3702 -- a business that books no places is not given place booking by an
// unrelated answer: the recommendation knows whether the business books
// places, only an explicit answer (door tablet, several rooms or sites) raises
// its bookings level, and one answer recomputes only the processes whose rules
// name that question.
import 'package:deskilo/features/workspace/domain/setup_levels.dart';
import 'package:flutter_test/flutter_test.dart';

SetupAnswers _only(String question) =>
    const SetupAnswers().withAnswer(question, yes: true);

void main() {
  test('a studio without places answering "public page: yes" keeps bookings '
      'none and gets the public page', () {
    final r = recommendSetupLevels(_only('public_page'), booksPlaces: false);
    expect(r[SetupProcess.bookings]!.level, 'none');
    expect(r[SetupProcess.bookings]!.reason, 'books_no_places');
    expect(r[SetupProcess.presentation]!.level, 'public');
    // The same answer for a business that books places is unchanged.
    expect(
      recommendSetupLevels(_only('public_page'))[SetupProcess.bookings]!.level,
      'simple',
    );
  });

  test('explicit booking answers still raise the level without places', () {
    for (final (q, level) in [
      ('door_tablet', 'measured'),
      ('several_rooms_or_sites', 'resources'),
    ]) {
      expect(
        recommendSetupLevels(_only(q), booksPlaces: false)[SetupProcess.bookings]!
            .level,
        level,
        reason: q,
      );
    }
  });

  test('one answer recomputes only the processes whose rules name it', () {
    expect(setupProcessesNaming(['public_page']), {SetupProcess.presentation});
    expect(
      setupProcessesNaming(['tracks_purchases']),
      containsAll([SetupProcess.money, SetupProcess.purchases]),
    );
    expect(
      setupProcessesNaming(['public_page']),
      isNot(contains(SetupProcess.bookings)),
    );
  });

  test('every combination of answers, with and without places, gives a '
      'vector without gaps', () {
    for (final booksPlaces in [true, false]) {
      for (var bits = 0; bits < 1 << setupQuestions.length; bits++) {
        final answers = SetupAnswers.fromJson({
          for (final (i, q) in setupQuestions.indexed) q: bits & (1 << i) != 0,
        });
        final r = recommendSetupLevels(answers, booksPlaces: booksPlaces);
        final vector = {for (final e in r.entries) e.key: e.value.level};
        expect(setupVectorGaps(vector), isEmpty, reason: '$bits $booksPlaces');
        if (!booksPlaces &&
            !answers['door_tablet'] &&
            !answers['several_rooms_or_sites']) {
          expect(vector[SetupProcess.bookings], 'none', reason: '$bits');
        }
      }
    }
  });

  test('a recomputed level is never set below what a kept level needs', () {
    // Tax stays at VAT (it needs invoices); the answers would lower money.
    const answers = SetupAnswers();
    final recommended = recommendSetupLevels(answers);
    expect(recommended[SetupProcess.money]!.level, 'none');
    final candidate = {
      for (final p in SetupProcess.values) p: recommended[p]!.level,
      SetupProcess.tax: 'vat',
    };
    final checked = holdRecomputedAtNeeds(candidate, {SetupProcess.money});
    expect(
      setupLevelRank(SetupProcess.money, checked.vector[SetupProcess.money]!),
      greaterThanOrEqualTo(setupLevelRank(SetupProcess.money, 'invoices')),
    );
    expect(checked.held[SetupProcess.money]!.by, SetupProcess.tax);
    expect(setupVectorGaps(checked.vector), isEmpty);
    // A recomputed level that already meets the need is not touched.
    final fine = holdRecomputedAtNeeds({
      ...candidate,
      SetupProcess.money: 'invoices',
    }, {SetupProcess.money});
    expect(fine.held, isEmpty);
  });

  test('a business that books places with one first-level feature off is not '
      'told it books none (#3702)', () {
    // placeBooking on, placeFeedback off: the `simple` level is not reached,
    // but the business books places: the fallback is `simple`.
    final r = recommendSetupLevels(const SetupAnswers());
    expect(r[SetupProcess.bookings]!.level, 'simple');
    expect(r[SetupProcess.bookings]!.reason, 'shared_places');
  });
}
