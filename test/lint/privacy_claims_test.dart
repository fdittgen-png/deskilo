// SPDX-License-Identifier: 0BSD
//
// #1237 — the privacy policy and the erasure function say the same
// thing.
//
// They did not. `PRIVACY.md` promised that "financial ledger history is
// anonymized, not deleted"; `erase_my_membership` does not touch
// `ledger_entries` at all. A member of two workspaces who erased one
// kept a fully named profile — the blanking only fires on the LAST
// membership — joined to every ledger row they left behind.
//
// The decision (#1237) was to correct the DOCUMENT, not the code:
// anonymising the ledger would break the bookkeeping the same paragraph
// says the ledger exists for. This test pins the pair together so the
// next person to change one is told about the other.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The migration that owns export and erasure.
const _erasure = 'supabase/migrations/0133_calendar_hub.sql';

/// #1288 S3 — erasure was extended here, by an anchored patch.
const _erasureExtension = 'supabase/migrations/0249_field_erasure.sql';

/// Every document that could repeat the claim, in every language it is
/// written in.
///
/// The first cut of this test named two files and one English phrase,
/// and the claim was alive in SEVEN other places when it passed: five
/// user guides — which ship inside the app as `assets/help/` and are
/// therefore the copy a member actually reads — plus ADR 0006. A lint
/// that only knows the file it was written against proves nothing.
final List<String> _documents = [
  'PRIVACY.md',
  'docs/SPECIFICATION.md',
  'docs/decisions/0006-quota-overage-billing.md',
  for (final guide in [
    'User-Guide',
    'Guide-utilisateur',
    'Benutzerhandbuch',
    'Guia-de-usuario',
    'Guida-utente',
  ])
    'docs/wiki/$guide.md',
  for (final locale in ['en', 'fr', 'de', 'es', 'it'])
    'assets/help/$locale.md',
];

/// A negation, within this many characters before the verb, turns the
/// claim into its correction — `docs/SPECIFICATION.md` legitimately says
/// "retained, **not** anonymized", and a lint that banned the word
/// outright would forbid saying the true thing.
const _negationWindow = 32;

/// How each language says no, near enough to the verb to be about it.
/// Whole words only: Spanish says "**no** se anonimizan" and Italian
/// "**non** vengono anonimizzate", and a plain substring test for "no"
/// would find it inside "nombre" and "número" and wave any claim
/// through.
final RegExp _negation = RegExp(
  r'(?<![a-zà-ÿ])(not|never|pas|jamais|non|nicht|nie|keine|no|nunca|mai)'
  r'(?![a-zà-ÿ])',
);

/// The verb, in the five languages the guides are written in. Matching
/// the verb alone is deliberately broad: any sentence in any of these
/// documents that says a financial record is anonymised is wrong,
/// whatever shape it is phrased in.
const _anonymise = [
  'anonymized',
  'anonymised',
  'anonymisé', // fr
  'anonymisiert', // de
  'anonimiza', // es
  'anonimizzat', // it
];

void main() {
  test('no document promises anonymisation the code does not do', () {
    for (final path in _documents) {
      final file = File(path);
      if (!file.existsSync()) continue; // assets/help is generated
      final text = file.readAsStringSync().toLowerCase();
      for (final word in _anonymise) {
        for (var at = text.indexOf(word); at >= 0;
            at = text.indexOf(word, at + 1)) {
          final before =
              text.substring((at - _negationWindow).clamp(0, at), at);
          expect(
            _negation.hasMatch(before),
            isTrue,
            reason: '$path claims something is "$word", around:\n'
                '  …${text.substring((at - 90).clamp(0, at), at + 60)}…\n'
                '`erase_my_membership` does not touch ledger_entries, and '
                'invoices are immutable — a ledger row keeps the name it '
                'was written with, for the statutory period (#1237). '
                'Either change the function, or keep the document '
                'describing what it does. The retention matrix in '
                'PRIVACY.md is the wording to follow.',
          );
        }
      }
    }
  });

  test('erasure still touches exactly the tables the policy names', () {
    // Erasure is defined in one migration and EXTENDED in another, so
    // both are read: a later anchored patch that added a table without
    // a row in the retention matrix is exactly what this catches.
    final body = [
      File(_erasure)
          .readAsStringSync()
          .substring(File(_erasure).readAsStringSync().indexOf(
                'erase_my_membership',
              )),
      File(_erasureExtension).readAsStringSync(),
    ].join('\n');

    // The rows the retention matrix in PRIVACY.md describes.
    for (final table in [
      'public.reservations',
      'public.member_notes',
      'public.members',
      'public.profiles',
      // #1288 S3 — the answers to the workspace's own questions, where
      // the question is marked personal data.
      'public.workspace_field_values',
      'public.workspace_field_value_options',
    ]) {
      expect(body, contains(table), reason: 'erasure should touch $table');
    }
    expect(
      body.contains('ledger_entries'),
      isFalse,
      reason: 'if erasure starts touching the ledger, PRIVACY.md has to '
          'say so — that is the whole point of this pair of tests',
    );
  });

  test('erasure keeps the answers the owner marked NON-personal', () {
    // The whole point of the personal_data flag: a shirt size for the
    // association's next order is the workspace's operational data, not
    // a fact about a person, and it survives.
    final body = File(_erasureExtension).readAsStringSync();
    expect(
      body,
      contains('d.personal_data'),
      reason: 'erasure that deleted every answer would be simpler and '
          'would throw away data the workspace still needs; erasure that '
          'deleted none would be a broken promise',
    );
  });

  test('the retention matrix exists and covers the classes that matter',
      () {
    final privacy = File('PRIVACY.md').readAsStringSync();
    expect(privacy, contains('What is kept, and for how long'));
    for (final row in [
      'Profile',
      'Membership row',
      'Bookings',
      'Ledger entries',
      'Invoices',
      'Badge hashes',
      'Diagnostic trace',
    ]) {
      expect(privacy, contains(row), reason: 'retention matrix row: $row');
    }
  });
}
