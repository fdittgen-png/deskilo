// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4402 -- a stock refusal is worded in one function. The server's reason is
// read into a StockRefusal at the data boundary (a reason this build does not
// know is `other`, never another reason); every value has its sentence; the
// reasons two kinds of thing share take the words of what the screen saves (a
// duplicate name of a group is not a duplicate name of a variant); a tag that
// is not in force is said so only where a tag is saved.
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/features/stock/data/stock_refusals.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/presentation/stock_config_text.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _en = AppLocalizationsEn();

Object _thrown(PostgrestException e) {
  try {
    throwStockFailure(e, StackTrace.current);
  } on Object catch (thrown) {
    return thrown;
  }
}

void main() {
  test('the server reason is read into the enum at the data boundary; an unknown one is other', () {
    expect(
      _thrown(const PostgrestException(message: 'refused', code: DkCode.dkg11, details: '{"field": "name", "reason": "name_duplicate"}')),
      isA<StockConfigRefused>().having((e) => e.reason, 'reason', StockRefusal.nameDuplicate).having((e) => e.field, 'field', 'name'),
    );
    expect(
      _thrown(const PostgrestException(message: 'refused', code: DkCode.dkg11, details: '{"field": "x", "reason": "a_reason_of_tomorrow"}')),
      isA<StockConfigRefused>().having((e) => e.reason, 'reason', StockRefusal.other),
    );
    expect(StockRefusal.fromWire(''), StockRefusal.other, reason: 'other has no wire name of its own');
  });

  test('every reason has a sentence; one the build does not know is the generic refusal', () {
    for (final r in StockRefusal.values) {
      expect(stockRefusalText(_en, r), isNotEmpty, reason: r.wire);
    }
    expect(stockRefusalText(_en, StockRefusal.other), _en.stockReasonOther);
    expect(stockProblemText(_en, const StockConfigRefused('x', StockRefusal.other)), _en.stockReasonOther);
  });

  test('a duplicate name reads as a group\'s on a group and as a variant\'s elsewhere', () {
    const refused = StockConfigRefused('name', StockRefusal.nameDuplicate);
    expect(stockProblemText(_en, refused, subject: StockSubject.group), _en.stockReasonGroupNameDuplicate);
    expect(stockProblemText(_en, refused), _en.stockReasonNameDuplicate);
  });

  test('a unit in use reads as a unit of measure\'s on that screen and as an item unit\'s elsewhere', () {
    const refused = StockConfigRefused('code', StockRefusal.unitInUse);
    expect(stockProblemText(_en, refused, subject: StockSubject.measureUnit), _en.measureReasonInUse);
    expect(stockProblemText(_en, refused), _en.stockReasonUnitInUse);
  });

  test('a tag not in force is said where a tag is saved; elsewhere an unknown reference is not called a tag', () {
    const refused = StockTagRefused(DkCode.dkg04);
    expect(stockProblemText(_en, refused, subject: StockSubject.tag), _en.stockTagNotInForce);
    expect(stockProblemText(_en, refused), _en.stockEditNotSaved);
  });

  test('the typed failures keep their words; anything else is "not saved"', () {
    expect(stockProblemText(_en, const StockConfigStale()), _en.stockEditStale);
    expect(stockProblemText(_en, const StockConfigInUse()), _en.stockEditInUse);
    expect(stockProblemText(_en, const StockNotEnough()), _en.refusalStockNotEnough);
    expect(stockProblemText(_en, const StockUnitRefused(DkCode.dkg29)), _en.refusalStockUnitCodeTaken);
    expect(stockProblemText(_en, StateError('a defect')), _en.stockEditNotSaved);
  });
}
