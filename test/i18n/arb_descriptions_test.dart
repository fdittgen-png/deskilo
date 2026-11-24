// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4429 -- a translator reads a message's description to know what it says and
// where: a ticket number, the key's own name or one word ("#4172 refusal") says
// nothing. A description says at least two words beyond its ticket references
// and the key's name. The messages written before this check are listed in
// docs/design/ARB_DESCRIPTION_BASELINE.txt, which only shrinks: a new message
// cannot join it, and one whose description was written leaves it.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baselinePath = 'docs/design/ARB_DESCRIPTION_BASELINE.txt';

/// Whether [description] of [key] tells a translator nothing.
bool thinDescription(String key, String description) {
  final rest = description
      .replaceAll(RegExp(r'#\d+'), ' ')
      .replaceAll(key, ' ')
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
  return rest.isEmpty || rest.split(' ').length < 2;
}

/// The keys of [en] whose description is thin or missing, sorted.
List<String> thinKeys(Map<String, dynamic> en) => [
  for (final key in en.keys)
    if (!key.startsWith('@') &&
        thinDescription(
          key,
          ((en['@$key'] as Map?)?['description'] as String?) ?? '',
        ))
      key,
]..sort();

void main() {
  test('the check sees a description that says nothing', () {
    expect(thinDescription('stockRefused', '#4172 refusal'), isTrue);
    expect(thinDescription('attentionAdmit', '#2326: attentionAdmit'), isTrue);
    expect(thinDescription('x', ''), isTrue);
    expect(
      thinDescription('refusalStockNotEnough', 'refusal DKG03 (#3824)'),
      isFalse,
    );
    expect(
      thinDescription('stockChainTitle', '#4432 G18 trace chain'),
      isFalse,
    );
  });

  test('no message joins the thin descriptions, and a written one leaves them', () {
    final en = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final thin = thinKeys(en).toSet();
    final baseline = {
      for (final l in File(_baselinePath).readAsLinesSync())
        if (l.trim().isNotEmpty && !l.startsWith('#')) l.trim(),
    };
    expect(
      thin.difference(baseline),
      isEmpty,
      reason: 'describe what the message says and where it shows (two words or more beyond its ticket)',
    );
    expect(
      baseline.difference(thin),
      isEmpty,
      reason:
          'these descriptions were written or their keys are gone: drop them from $_baselinePath',
    );
  });
}
