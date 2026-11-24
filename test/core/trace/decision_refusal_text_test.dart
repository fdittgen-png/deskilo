// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4146 -- a decision on an event the caller may not read is refused by
// respond_to_event with DKN01. In every language the app reads it as the
// permission refusal, never as the server's English sentence.
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/trace/refusal_text.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _refusal = PostgrestException(
  message: 'you are not an eligible validator for this event',
  code: DkCode.dkn01,
);

void main() {
  final sentences = <String>{};
  for (final language in const ['en', 'fr', 'de', 'es', 'it']) {
    test('$language: the refused decision reads as the permission refusal', () {
      final l10n = lookupAppLocalizations(Locale(language));
      final text = knownRefusalText(l10n, _refusal);
      expect(text, l10n.refusalPermission);
      expect(text, isNot(contains('eligible validator')));
      sentences.add(text!);
    });
  }
  test('each language has its own sentence', () {
    expect(sentences, hasLength(5));
  });
}
