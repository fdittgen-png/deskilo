// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4497 -- the setup questionnaire offers an exempt or out-of-scope VAT rate's reason from a list (web/setup_params.js
// VAT_EXEMPTIONS). That list is a mirror of the invoice model's vatRateExemptionCodes, never a second catalogue: a code
// in one and not the other, or under another category, fails here; and every code the page offers has its label and
// its legal wording in the five languages of the page's own texts.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// `['E','VATEX-EU-132','vatex132Label','vatex132Text']` rows of VAT_EXEMPTIONS: (category, code, label key, text key).
final _row = RegExp(r"\['([A-Z])','(VATEX-[A-Z0-9-]+)','(\w+)','(\w+)'\]");

List<(String, String, String, String)> _setupList() {
  final src = File('web/setup_params.js').readAsStringSync();
  final line = src.split('\n').firstWhere((l) => l.startsWith('const VAT_EXEMPTIONS='), orElse: () => '');
  return [for (final m in _row.allMatches(line)) (m[1]!, m[2]!, m[3]!, m[4]!)];
}

/// The page's words by language, as web/setup_l10n.js gives them.
Map<String, Object?> _setupStrings() {
  final js = File('web/setup_l10n.js').readAsStringSync();
  final start = js.indexOf('window.SETUP_L10N=') + 'window.SETUP_L10N='.length;
  return jsonDecode(js.substring(start, js.lastIndexOf(';'))) as Map<String, Object?>;
}

void main() {
  final rows = _setupList();

  test('the setup list is read', () => expect(rows, isNotEmpty, reason: 'VAT_EXEMPTIONS was not found in web/setup_params.js'));

  test('every code the setup offers is the invoice model\'s, under the same category, and the reverse', () {
    final setup = {for (final (c, code, _, _) in rows) '$c $code'};
    final model = {
      for (final e in vatRateExemptionCodes.entries)
        for (final code in e.value) '${e.key} $code',
    };
    expect(setup.difference(model), isEmpty, reason: 'offered by setup.html but not in vatRateExemptionCodes');
    expect(model.difference(setup), isEmpty, reason: 'in vatRateExemptionCodes but not offered by setup.html');
  });

  test('every code offered has its label and its legal wording in the five languages', () {
    final missing = <String>[];
    for (final lang in ['en', 'fr', 'de', 'es', 'it']) {
      // #4501 -- the words are the app's (lib/l10n/_fragments/vat_exemptions_*.arb), as the page loads them
      final texts = (_setupStrings()[lang] as Map<String, Object?>)['s'] as Map<String, Object?>;
      for (final (_, code, label, text) in rows) {
        for (final k in [label, text]) {
          if ((texts[k] as String? ?? '').trim().isEmpty) missing.add('$lang $code $k');
        }
      }
    }
    expect(missing, isEmpty);
  });
}
