// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3813 (part of #3657) -- a lease settlement's texts print from the facts
// the server froze with them, in the reader's language: the term's period,
// the schedule's supplier. What cannot be read prints the stored text; a
// title the owner typed (its facts dropped) prints as typed.
import 'package:deskilo/features/money/domain/expense_schedule.dart';
import 'package:deskilo/features/money/domain/premises_lease.dart';
import 'package:deskilo/features/money/presentation/settlement_texts.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo/l10n/app_localizations_fr.dart';
import 'package:flutter_test/flutter_test.dart';

String _iso(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

const _period = <String, Object?>{
  'kind': 'settlement_period',
  'version': 1,
  'values': {'from': '2025-01-01', 'to': '2025-12-31'},
};
const _supplier = <String, Object?>{
  'kind': 'service_charge_settlement',
  'version': 1,
  'values': {'supplier': 'SCI Les Halles'},
};

LeaseTerm _term(Map<String, Object?>? facts) => LeaseTerm.fromJson({
  'id': 't1',
  'kind': 'other',
  'label': 'Settlement 2025-01-01 to 2025-12-31',
  'amount_cents': 30000,
  'effective_from': '2026-02-01',
  'text': facts,
});

ExpenseSchedule _schedule(Map<String, Object?>? facts, {String? title}) =>
    ExpenseSchedule.fromDb({
      'id': 's1',
      'workspace_id': 'ws',
      'member_id': 'm',
      'title': title ?? 'Service charge settlement — SCI Les Halles',
      'amount_cents': 30000,
      'starts_on': '2026-02-01',
      'unit': 'month',
      'text_facts': facts,
    });

void main() {
  final fr = AppLocalizationsFr();
  final en = AppLocalizationsEn();

  test('the term names its period in the reader\'s language', () {
    expect(
      leaseTermLabel(fr, _iso, _term(_period)),
      'Régularisation du 01/01/2025 au 31/12/2025',
    );
    expect(
      leaseTermLabel(en, _iso, _term(_period)),
      'Settlement 01/01/2025 to 31/12/2025',
    );
  });

  test('the schedule names its supplier in the reader\'s language', () {
    expect(
      scheduleTitle(fr, _iso, _schedule(_supplier)),
      'Régularisation des charges — SCI Les Halles',
    );
  });

  test('what cannot be read prints the stored text', () {
    for (final facts in <Map<String, Object?>?>[
      null,
      {..._period, 'kind': 'from_a_later_version'},
      {..._period, 'version': 2},
      {
        ..._period,
        'values': {'from': 'not a day', 'to': '2025-12-31'},
      },
    ]) {
      expect(
        leaseTermLabel(fr, _iso, _term(facts)),
        'Settlement 2025-01-01 to 2025-12-31',
        reason: '$facts',
      );
    }
  });

  test('an owner\'s own title prints as typed', () {
    expect(
      scheduleTitle(fr, _iso, _schedule(null, title: 'Charges 2025, Halles')),
      'Charges 2025, Halles',
    );
  });

  test('the models read the facts the server sends', () {
    expect(_term(_period).textFacts, _period);
    expect(_schedule(_supplier).textFacts, _supplier);
    expect(_term(null).textFacts, isNull);
  });
}
