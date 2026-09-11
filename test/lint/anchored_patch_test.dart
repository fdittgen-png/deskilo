// SPDX-License-Identifier: 0BSD
//
// #1092 — a migration that re-creates a function FROM SCRATCH silently
// discards every anchored patch applied to it since.
//
// `CREATE OR REPLACE FUNCTION` replaces the whole body. When 0185
// re-created `create_workspace` to add `p_environment` and
// `p_with_twin`, it dropped both rules later migrations had patched in:
// 0165's founder `member_number` and 0166's "an owner must have an
// e-mail address". Neither was noticed for weeks, because nothing looks
// at a function's history — and the e-mail rule still held in
// `activate_co_owner`, patched by the same 0166 block, so it applied to
// a co-owner and not to the person creating the space.
//
// The same class cost this project a day once already (#960/0175, the
// detailed invoices). This is the guard: adding a wholesale re-creation
// of a previously-patched function fails the build and names it, so the
// author carries the patches forward deliberately instead of finding
// out from a field report.
//
// A pair here is NOT necessarily a bug — three of the four below were
// verified against the live database and had kept their patches. The
// set is frozen so that NEW pairs must be argued for; it may shrink,
// never grow.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `function` re-created after being patched, each verified by hand.
/// Recorded as `function@recreating-migration`.
const _reviewed = {
  // 0185 lost BOTH patches. Restored by 0192, with a live harness.
  'create_workspace@0185',
  // 0180/0185 kept the 0139/0154 permission additions — verified in
  // pg_get_functiondef on the live project.
  'has_permission@0180',
  'has_permission@0185',
  // 0182 rewrote both for #985 (dated rate versions) and kept the
  // earlier rules; the 2-arg invoice_lines_for body still carries
  // 0156's credit-VAT coalesce, and set_vat_rates still carries
  // 0170's group_key / outside_base / exemption_reason.
  'invoice_lines_for@0182',
  'set_vat_rates@0182',
  // #1110/0200 adds `origin` to the three paths that create a member.
  // The bodies were not taken from an earlier migration file — they were
  // read out of `pg_get_functiondef` on the LIVE project, which is the
  // post-patch state by definition, and the one line each was added to
  // them. That is the only way to re-create a patched function without
  // guessing, and unlike carrying patches forward by hand it cannot
  // silently miss one.
  //
  // Verified afterwards by reading the live definitions back:
  // create_workspace still carries 0166's `user_has_email` and 0165's
  // `next_document_number`; join_workspace still carries 0165's numbering,
  // 0153's managed-identity claim and the member_join event;
  // create_managed_member still carries 0153's identity row and 0161's
  // data_access_log write.
  'create_workspace@0200',
  'join_workspace@0200',
  'create_managed_member@0200',
};

void main() {
  test('no migration re-creates a function a later-unreviewed patch owns',
      () {
    final files = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final patchedIn = <String, List<String>>{};
    final recreatedIn = <String, List<String>>{};

    for (final file in files) {
      final number = file.uri.pathSegments.last.substring(0, 4);
      final source = file.readAsStringSync();
      // A patch reads the live body and rewrites it at an anchor.
      for (final m
          in RegExp(r"proname\s*=\s*'(\w+)'").allMatches(source)) {
        (patchedIn[m.group(1)!] ??= []).add(number);
      }
      for (final m in RegExp(r'create or replace function public\.(\w+)')
          .allMatches(source)) {
        (recreatedIn[m.group(1)!] ??= []).add(number);
      }
    }

    final offenders = <String>[];
    for (final entry in patchedIn.entries) {
      final lastPatch = entry.value.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      for (final recreation in recreatedIn[entry.key] ?? const <String>[]) {
        if (recreation.compareTo(lastPatch) <= 0) continue;
        final key = '${entry.key}@$recreation';
        if (!_reviewed.contains(key)) offenders.add(key);
      }
    }

    expect(offenders, isEmpty,
        reason: 'These functions are re-created wholesale AFTER a '
            'migration patched them at an anchor, so the patch is gone '
            'unless the new body repeats it:\n  ${offenders.join('\n  ')}\n'
            'Carry the earlier rules forward, verify against the LIVE '
            'function with pg_get_functiondef — not against the migration '
            'text — and then add the pair to _reviewed with what you '
            'checked.');
  });

  test('the reviewed set has not gone stale', () {
    // Every entry must still describe a real pair; a removed migration
    // or a renamed function should shrink this list, not be forgotten.
    final numbers = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last.substring(0, 4))
        .toSet();
    for (final key in _reviewed) {
      expect(numbers, contains(key.split('@').last),
          reason: '$key names a migration that no longer exists');
    }
  });
}
