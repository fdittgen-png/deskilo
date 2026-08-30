// SPDX-License-Identifier: 0BSD
//
// #751 — a change of the consent TEXT must ask every account again:
// the text of record (the English fallback in privacy_policy.dart) is
// pinned by a content hash to kPrivacyPolicyVersion. Changing the text
// fails this test until kPrivacyPolicyVersion is bumped (and the pin
// re-recorded) — so re-acceptance can never be forgotten.
import 'package:deskilo/core/privacy/privacy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// FNV-1a (32-bit) over the UTF-16 code units — stable across runs
/// and platforms, unlike `Object.hash`.
int _fnv1a(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// Version → hash of the text it was accepted for. Add a row for every
/// bump; the current version's row must match the current text.
const _pins = <String, int>{
  '2026-08-30': 2136118761,
};

void main() {
  test('the consent text is pinned to kPrivacyPolicyVersion — a changed '
      'text needs a new version so every account is asked again', () {
    final text = privacySections(null)
        .map((s) => '${s.title}\n${s.body}')
        .join('\n\n');
    final hash = _fnv1a(text);
    expect(
      _pins[kPrivacyPolicyVersion],
      hash,
      reason: 'The consent text changed (hash $hash) but '
          'kPrivacyPolicyVersion is still $kPrivacyPolicyVersion. Bump the '
          'version (today\'s date) in lib/core/privacy/privacy_policy.dart, '
          'add "<version>: $hash" to _pins, and mirror the text in the '
          'help ×5, the wiki ×5 and web/privacy.html.',
    );
  });

  test('the version is a date and the wiki link points at the privacy '
      'section', () {
    expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(kPrivacyPolicyVersion),
        isTrue);
    expect(kPrivacyWikiUrl, contains('#14-privacy'));
  });
}
