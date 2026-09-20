// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1447 — the policy manifest lists what the migrations create, checked
// from the files rather than from a replay.
//
// `assets/instance/policies.txt` is what the doctor compares a live
// project against, in both directions: a policy it does not list reads as
// one no migration created — the hand-made `floor_plans_read` of #1316 —
// and a listed policy the project lacks is an alarm too. The manifest is
// therefore maintained by hand, from the replay's own diff.
//
// The replay proves it, and takes forty-five minutes to say so. 0247
// added two tables with a select policy each and learned about the
// manifest from CI. This reads the same answer out of the migration text
// in under a second.
//
// It is deliberately weaker than the replay and never replaces it: a
// policy created inside a plpgsql `execute` string is invisible here, and
// the storage policies of 0215 are hand-made on purpose. What it catches
// is the ordinary case — `create policy` written in a migration, and
// nobody told the manifest.
import 'dart:io';

import 'package:deskilo/core/instance/instance_policies.dart';
import 'package:flutter_test/flutter_test.dart';

final _create = RegExp(
  r'create\s+policy\s+([a-z0-9_"]+)\s+on\s+([a-z0-9_."]+)',
  caseSensitive: false,
);
final _drop = RegExp(
  r'drop\s+policy\s+(?:if\s+exists\s+)?([a-z0-9_"]+)\s+on\s+([a-z0-9_."]+)',
  caseSensitive: false,
);
/// A dropped table takes its policies with it — `workspace_admin_invites`
/// left in 0051 and its policy left with it.
final _dropTable = RegExp(
  r'drop\s+table\s+(?:if\s+exists\s+)?([a-z0-9_."]+)',
  caseSensitive: false,
);

String _bare(String s) => s.trim().toLowerCase().replaceAll('"', '');

String _qualified(String table, String policy) {
  final t = _bare(table);
  return '${t.contains('.') ? t : 'public.$t'}.${_bare(policy)}';
}

/// The policies [sql] files leave behind, read in file order.
///
/// `drop policy if exists x on t` immediately followed by `create policy
/// x on t` is the house idiom for replacing one, so the statements are
/// replayed in order and the last word wins — the same answer the replay
/// reaches, for the cases it can see.
Set<String> policiesCreatedBy(Iterable<String> sql) {
  final live = <String>{};
  for (final text in sql) {
    String table(String t) {
      final b = _bare(t);
      return b.contains('.') ? b : 'public.$b';
    }

    final events = <({int at, String kind, String name})>[
      for (final m in _create.allMatches(text))
        (
          at: m.start,
          kind: 'create',
          name: _qualified(m.group(2)!, m.group(1)!)
        ),
      for (final m in _drop.allMatches(text))
        (at: m.start, kind: 'drop', name: _qualified(m.group(2)!, m.group(1)!)),
      for (final m in _dropTable.allMatches(text))
        (at: m.start, kind: 'table', name: table(m.group(1)!)),
    ]..sort((a, b) => a.at.compareTo(b.at));
    for (final e in events) {
      switch (e.kind) {
        case 'create':
          live.add(e.name);
        case 'drop':
          live.remove(e.name);
        case 'table':
          live.removeWhere((p) => p.startsWith('${e.name}.'));
      }
    }
  }
  return live;
}

void main() {
  final files = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('every policy a migration creates is in the manifest the doctor '
      'reads', () {
    final created = policiesCreatedBy(files.map((f) => f.readAsStringSync()));
    final manifest = parseInstancePolicies(
      File('assets/instance/policies.txt').readAsStringSync(),
    );
    final missing = created.difference(manifest).toList()..sort();
    expect(
      missing,
      isEmpty,
      reason: 'these are created by a migration and absent from '
          'assets/instance/policies.txt, so the doctor would call each one '
          'a policy no migration created:\n${missing.join('\n')}',
    );
  });

  test('the manifest has not gone stale — it lists nothing the migrations '
      'stopped creating', () {
    final created = policiesCreatedBy(files.map((f) => f.readAsStringSync()));
    final manifest = parseInstancePolicies(
      File('assets/instance/policies.txt').readAsStringSync(),
    );
    // Storage policies are hand-made (0215) and a few are created inside
    // plpgsql, so a manifest entry this reader cannot see is expected;
    // what must not happen is a PUBLIC table policy surviving here after
    // its migration dropped it.
    final ghosts = manifest
        .where((p) => p.startsWith('public.'))
        .where((p) => !created.contains(p))
        .toList()
      ..sort();
    expect(
      ghosts,
      isEmpty,
      reason: 'listed in the manifest and created by no migration:\n'
          '${ghosts.join('\n')}',
    );
  });

  group('the reader answers the shapes the migrations actually use', () {
    test('a plain create is found, and qualified with its schema', () {
      expect(
        policiesCreatedBy(['create policy p_read on public.things for select']),
        {'public.things.p_read'},
      );
      expect(
        policiesCreatedBy(['create policy p_read on things for select']),
        {'public.things.p_read'},
      );
    });

    test('drop-then-create leaves the policy, which is the house idiom', () {
      expect(
        policiesCreatedBy([
          'drop policy if exists p on public.t;\ncreate policy p on public.t;',
        ]),
        {'public.t.p'},
      );
    });

    test('a later migration that drops a policy takes it away', () {
      expect(
        policiesCreatedBy([
          'create policy p on public.t;',
          'drop policy p on public.t;',
        ]),
        isEmpty,
      );
    });

    test('a dropped table takes its policies with it', () {
      expect(
        policiesCreatedBy([
          'create policy p on public.t;',
          'drop table public.t;',
        ]),
        isEmpty,
      );
    });

    test('two tables may carry policies of the same name', () {
      expect(
        policiesCreatedBy([
          'create policy sel on public.a;\ncreate policy sel on public.b;',
        ]),
        {'public.a.sel', 'public.b.sel'},
      );
    });
  });
}
