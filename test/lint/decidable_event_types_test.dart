// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4143 -- the event types that can wait for a decision are those a
// validation rule decides: the app's validation cards (_cardTypes in
// validation_settings_screen.dart) and the server's
// event_type_waits_for_decision (whose latest definition the migrations
// hold) list the same types. A validator's rule reads only those types.
import 'dart:io';

import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The db names of the `EventType.x` entries of `_cardTypes` in [dart].
Set<String> cardTypes(String dart) {
  final start = dart.indexOf('const _cardTypes = [');
  final end = dart.indexOf('];', start);
  final names = RegExp(r'EventType\.(\w+)')
      .allMatches(
        dart.substring(start, end).replaceAll(RegExp(r'//[^\n]*'), ''),
      )
      .map((m) => m.group(1)!);
  return {for (final n in names) EventType.values.byName(n).dbName};
}

/// The types the latest definition of event_type_waits_for_decision in
/// [migrations] answers true for.
Set<String> serverDecidableTypes(Iterable<String> migrations) {
  String? latest;
  for (final sql in migrations) {
    final i = sql.indexOf('function public.event_type_waits_for_decision(');
    if (i >= 0) latest = sql.substring(i);
  }
  if (latest == null) return const {};
  final m = RegExp(r"when p_type in \(([^)]*)\) then true").firstMatch(latest);
  return {
    for (final t in RegExp(r"'(\w+)'").allMatches(m?.group(1) ?? ''))
      t.group(1)!,
  };
}

void main() {
  test('the parsers read the cards and the server list', () {
    expect(
      cardTypes(
        'const _cardTypes = [\n  EventType.payment,\n  // EventType.expense,\n  EventType.memberJoin,\n];',
      ),
      {'payment', 'member_join'},
    );
    expect(
      serverDecidableTypes([
        "create or replace function public.event_type_waits_for_decision(p_type text)\n"
            "  select case when p_type in ('payment', 'expense') then true when p_type in ('adjustment') then false end;",
      ]),
      {'payment', 'expense'},
    );
  });

  test(
    'the types that wait for a decision are the app\'s validation cards',
    () {
      final cards = cardTypes(
        File(
          'lib/features/events/presentation/screens/validation_settings_screen.dart',
        ).readAsStringSync(),
      );
      final server = serverDecidableTypes([
        for (final f in sqlFiles('supabase/migrations')) f.readAsStringSync(),
      ]);
      expect(cards, isNotEmpty);
      expect(server, cards);
    },
  );
}
