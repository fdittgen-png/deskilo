// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4170 -- a sale refused for what the main store holds says what it holds and
// links to the Stock page of that item. The numbers and the item come from the
// server's JSON detail, never from its sentence: a detail that is not that
// JSON, or a refusal of a move (no scope), keeps the generic words and no link.
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/trace/refusal_text.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _en = AppLocalizationsEn();

PostgrestException _refusal(String code, String? details) =>
    PostgrestException(message: 'not enough in the main store: 0.5 of 1 are there', code: code, details: details);

const _json = '{"held": "0.500000", "asked": "1", "scope": "main_store", "item_id": "i-1"}';

void main() {
  test('less than the sale asks says what the main store holds and links to that item', () {
    final e = _refusal(DkCode.dkg03, _json);
    expect(knownRefusalText(_en, e), _en.refusalMainStoreShort('0.500000', '1'));
    expect(refusalLinkOf(e), '/stock?item=i-1');
  });

  test('only expired goods left says so, and links too', () {
    final e = _refusal(DkCode.dkg15, _json);
    expect(knownRefusalText(_en, e), _en.refusalMainStoreExpired('0.500000', '1'));
    expect(refusalLinkOf(e), '/stock?item=i-1');
  });

  test('a refusal of a move, or a detail that is not ours, keeps the generic words and no link', () {
    for (final details in [null, 'not json', '{"scope": "elsewhere"}', '{"scope": "main_store"}']) {
      final e = _refusal(DkCode.dkg03, details);
      expect(knownRefusalText(_en, e), _en.refusalStockNotEnough, reason: '$details');
      expect(refusalLinkOf(e), isNull, reason: '$details');
    }
    expect(refusalLinkOf(_refusal(DkCode.dkg05, _json)), isNull);
  });
}
