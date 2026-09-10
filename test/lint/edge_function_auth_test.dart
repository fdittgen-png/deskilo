// SPDX-License-Identifier: 0BSD
//
// #1078 — an edge function must know WHO is asking before it answers,
// and it must resolve that caller to ONE member row.
//
// `send-e-invoice` failed both halves, and each failure was invisible
// to the tests that existed. The membership lookup was
// `.eq("workspace_id", …).maybeSingle()` with no `user_id`: since
// `members_select` lets a member read every row of their workspace,
// PostgREST returned one row per member, `maybeSingle()` treated more
// than one as an error, and EVERY send was refused with "not an admin
// of this workspace" — to the owner. Any fixture with a single member
// passes; every real workspace fails.
//
// And the `action:"config"` branch answered ABOVE the caller check, so
// anyone holding a workspace UUID learned whether e-invoicing was
// configured, its provider, the missing fields and the wired
// environments. `create-payment-order` had already closed that hole and
// documented it; the fix was simply never carried across, which is the
// argument for checking it here rather than in one function's comments.
//
// Deno is not installed in CI, so this reads the source. That is enough
// for a structural invariant, and it is the only guard these functions
// have.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Functions that act on behalf of a signed-in member of a workspace.
/// A function that is deliberately unauthenticated does not belong here.
const _memberScoped = [
  'send-e-invoice',
  'create-payment-order',
];

void main() {
  for (final name in _memberScoped) {
    group(name, () {
      final source =
          File('supabase/functions/$name/index.ts').readAsStringSync();

      test('every members lookup is scoped to the calling user', () {
        // Each `.from("members")` chain up to its terminator.
        final chains = RegExp(
          r'\.from\(\s*"members"\s*\)(.*?)(maybeSingle|single)\(\)',
          dotAll: true,
        ).allMatches(source);
        expect(chains, isNotEmpty,
            reason: '$name no longer looks members up — retire this entry');
        for (final chain in chains) {
          expect(chain.group(1), contains('user_id'),
              reason: 'a members lookup in $name is scoped by workspace '
                  'alone. RLS lets a member read every row of their '
                  'workspace, so this returns one row per member and '
                  'maybeSingle() then refuses the caller.');
        }
      });

      test('the caller is identified before any branch answers', () {
        final auth = source.indexOf('auth.getUser(');
        expect(auth, greaterThan(-1),
            reason: '$name never resolves the caller');
        // Every early return that hands data back to the caller.
        for (final answer in RegExp(r'action === "(\w+)"').allMatches(source)) {
          expect(auth, lessThan(answer.start),
              reason: 'the "${answer.group(1)}" branch of $name answers '
                  'before the caller is known — a workspace id is not a '
                  'secret, so that discloses the workspace\'s setup to '
                  'anyone who has one.');
        }
      });
    });
  }
}
