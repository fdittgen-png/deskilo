// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4143 -- every server function that reads events follows the events'
// reading rule or is listed with what it returns. The check runs on the
// replayed database (supabase/tests/database/456_definer_event_readers.sql),
// which sees every definer routine however it was written or patched. Its
// list of reasoned exceptions is the one list; this test checks that each
// signature in it is a definer routine of the effective contract
// (assets/instance/contract.txt), so a renamed or dropped function cannot
// linger there.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _listFile = 'supabase/tests/database/456_definer_event_readers.sql';

/// The `(name, argument types)` of each `('<signature>', '<reason>')` entry
/// of the database test's list.
List<({String name, List<String> types, String reason})> listedReaders(
  String sql,
) => [
  for (final m in RegExp(
    r"\(\s*'(\w+)\(([^)]*)\)',\s*'((?:[^']|'')+)'\s*\)",
  ).allMatches(sql))
    (
      name: m.group(1)!,
      types: m.group(2)!.isEmpty ? const [] : m.group(2)!.split(','),
      reason: m.group(3)!,
    ),
];

/// The definer routines of [contract]: name, then each argument as written
/// (`p_workspace_id uuid`).
Map<String, List<List<String>>> contractDefiners(String contract) {
  final out = <String, List<List<String>>>{};
  final line = RegExp(
    r'^routine public\.(\w+)\((.*?)\) -> .*? \| function \| definer \|',
  );
  for (final raw in contract.split('\n')) {
    final m = line.firstMatch(raw);
    if (m == null) continue;
    final args = m.group(2)!.isEmpty ? <String>[] : m.group(2)!.split(', ');
    out.putIfAbsent(m.group(1)!, () => []).add(args);
  }
  return out;
}

/// Whether a contract argument (`p_name type`, or the type alone) has [type].
bool _argIs(String arg, String type) => arg == type || arg.endsWith(' $type');

/// The listed signatures that are not a definer routine of [contract].
List<String> missingFromContract(
  List<({String name, List<String> types, String reason})> listed,
  Map<String, List<List<String>>> definers,
) => [
  for (final l in listed)
    if (!(definers[l.name] ?? const []).any(
      (args) =>
          args.length == l.types.length &&
          [for (var i = 0; i < args.length; i++) _argIs(args[i], l.types[i])]
              .every((ok) => ok),
    ))
      '${l.name}(${l.types.join(',')})',
];

void main() {
  test(
    'the parser reads entries and the contract, and tells a missing routine',
    () {
      final listed = listedReaders(
        "insert into listed (sig, reason) values\n"
        "  ('feed(uuid,timestamp with time zone)',\n   'callable by the service role only'),\n"
        "  ('gone(text)',\n   'the caller''s own');",
      );
      expect(listed.map((l) => l.name), ['feed', 'gone']);
      expect(listed.last.reason, "the caller''s own");
      final definers = contractDefiners(
        'routine public.feed(p_ws uuid, p_from timestamp with time zone) -> jsonb | function | definer | stable | exec:service_role | body:x\n'
        'routine public.gone(p text) -> jsonb | function | invoker | stable | exec:service_role | body:x',
      );
      expect(missingFromContract(listed, definers), ['gone(text)']);
    },
  );

  test('every reasoned exception of the database test is a definer routine of the contract', () {
    final listed = listedReaders(File(_listFile).readAsStringSync());
    expect(listed, hasLength(37));
    expect(listed.every((l) => l.reason.trim().isNotEmpty), isTrue);
    final definers = contractDefiners(
      File('assets/instance/contract.txt').readAsStringSync(),
    );
    expect(missingFromContract(listed, definers), isEmpty);
  });
}
