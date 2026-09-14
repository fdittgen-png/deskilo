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

void main() {
  test('the policy does not promise anonymisation the code does not do',
      () {
    for (final path in ['PRIVACY.md', 'docs/SPECIFICATION.md']) {
      final text = File(path).readAsStringSync().toLowerCase();
      expect(
        text.contains('ledger history is anonymized') ||
            text.contains('ledger history is anonymised'),
        isFalse,
        reason: '$path promises the ledger is anonymised on erasure. '
            '`erase_my_membership` does not touch ledger_entries — see '
            '#1237. Either change the function, or keep the document '
            'describing what it does.',
      );
    }
  });

  test('erasure still touches exactly the four tables the policy names',
      () {
    final sql = File(_erasure).readAsStringSync();
    final body = sql.substring(sql.indexOf('erase_my_membership'));
    // The four the retention matrix in PRIVACY.md describes.
    for (final table in [
      'public.reservations',
      'public.member_notes',
      'public.members',
      'public.profiles',
    ]) {
      expect(body, contains(table), reason: 'erasure should touch $table');
    }
    expect(
      body.substring(0, body.indexOf(r'$$;')).contains('ledger_entries'),
      isFalse,
      reason: 'if erasure starts touching the ledger, PRIVACY.md has to '
          'say so — that is the whole point of this pair of tests',
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
