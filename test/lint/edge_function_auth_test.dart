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
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Functions that act on behalf of a signed-in member of a workspace.
/// A function that is deliberately unauthenticated does not belong here.
const _memberScoped = [
  'send-e-invoice',
  'create-payment-order',
];

/// The same function as the self-hoster receives it. `bundle.json` is a
/// GENERATED artifact committed to the repo, so a branch cut before a
/// function was fixed regenerates it from the stale source — and merging
/// that branch afterwards silently reverts the fix for every self-hosted
/// instance while `supabase/functions/` still reads correct. A security
/// review caught exactly that on the #1092 branch.
String _bundled(String slug) {
  final bundle = jsonDecode(
    File('assets/instance/bundle.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final entry = (bundle['functions'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((f) => f['slug'] == slug,
          orElse: () => throw StateError('$slug is not in the bundle'));
  return (entry['files'] as List)
      .cast<Map<String, dynamic>>()
      .map((f) => f['content'] as String)
      .join();
}

void _assertGuarded(String name, String source, String where) {
  final chains = RegExp(
    r'\.from\(\s*"members"\s*\)(.*?)(maybeSingle|single)\(\)',
    dotAll: true,
  ).allMatches(source);
  expect(chains, isNotEmpty,
      reason: '$name ($where) no longer looks members up — retire it');
  for (final chain in chains) {
    expect(chain.group(1), contains('user_id'),
        reason: 'a members lookup in $name ($where) is scoped by '
            'workspace alone. RLS lets a member read every row of their '
            'workspace, so this returns one row per member and '
            'maybeSingle() then refuses the caller.');
  }
  final auth = source.indexOf('auth.getUser(');
  expect(auth, greaterThan(-1),
      reason: '$name ($where) never resolves the caller');
  for (final answer in RegExp(r'action === "(\w+)"').allMatches(source)) {
    expect(auth, lessThan(answer.start),
        reason: 'the "${answer.group(1)}" branch of $name ($where) '
            'answers before the caller is known — a workspace id is not '
            'a secret, so that discloses the workspace\'s setup to '
            'anyone who has one.');
  }
}

void main() {
  for (final name in _memberScoped) {
    group(name, () {
      final source =
          File('supabase/functions/$name/index.ts').readAsStringSync();

      // Nothing in CI typechecks Deno, so a deleted binding that is still
      // referenced ships silently. Removing the second `caller` client in
      // #1078 left one `caller.auth.getUser()` behind — a ReferenceError
      // on every real invoice send, invisible to 2 660 Dart tests and to
      // the auth lint below, and caught only by reading the DEPLOYED
      // function side by side with the local one.
      test('every identifier it uses is declared', () {
        final lines = source.split('\n');
        for (final id in const ['caller', 'anonKey', 'admin', 'userData']) {
          final word = RegExp('\\b$id\\b');
          // A declaration is any const/let line naming it — which covers
          // `const admin: X = …` and `const { data: userData } = …` alike.
          final declared = lines.any((l) =>
              (l.contains('const ') || l.contains('let ')) &&
              word.hasMatch(l));
          // A use is a member access that is not itself a property.
          final used = RegExp('(?<![\\w.])$id\\.').hasMatch(source);
          expect(used && !declared, isFalse,
              reason: '`$id` is used in $name but never declared — the '
                  'binding was removed and a reference left behind. Deno '
                  'is not typechecked here, so this ships.');
        }
      });

      test('the BUNDLED copy is guarded too', () {
        _assertGuarded(name, _bundled(name), 'assets/instance/bundle.json');
      });

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
