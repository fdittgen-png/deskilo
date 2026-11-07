// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3381 — a client text limit that repeats a SQL cap is pinned to it.
//
// A form clips what a person types to N characters so the server's cut
// (`left(..., N)`) never silently drops the end of a sentence. The two numbers
// live in different languages and nothing tied them: change the SQL and the
// form clips short (or not at all) without a red test. Each pair below names
// the Dart/TypeScript constant and the LATEST migration definition that holds
// the same number; a third place that clips a free-text parameter without
// being listed is red too, so a new one cannot be forgotten.
//
// These are technical transport widths (a column's cut), not business values:
// no setting, no UI point. The source of each is the migration named below.
import 'dart:io';

import 'package:deskilo/features/money/domain/capability_state.dart';
import 'package:deskilo/features/money/domain/credit_move.dart';
import 'package:deskilo/features/money/domain/einvoice_resolution.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The text of [function]'s definition in the LAST migration that defines it.
String _latestDefinition(String function) {
  final header = 'create or replace function public.$function(';
  String? found;
  for (final file in sqlFiles('supabase/migrations')
    ..sort((a, b) => a.path.compareTo(b.path))) {
    final text = file.readAsStringSync();
    final at = text.indexOf(header);
    if (at < 0) continue;
    final next = text.indexOf('create or replace function', at + header.length);
    found = text.substring(at, next < 0 ? text.length : next);
  }
  expect(found, isNotNull, reason: 'no migration defines public.$function');
  return found!;
}

int _clip(String definition, String parameter) {
  final match = RegExp(
    "left\\((?:btrim|trim)\\((?:coalesce\\()?$parameter[^)]*\\)+,\\s*(\\d+)\\)",
  ).firstMatch(definition);
  expect(match, isNotNull, reason: 'no clip of $parameter in the definition');
  return int.parse(match!.group(1)!);
}

/// Definer writers that clip a reason with no client form to agree with (the
/// text arrives from a validator or a job). A ratchet: it only falls.
const _unpinnedClippers = 9;

void main() {
  // function, parameter, the client constant.
  final pairs = <(String, String, int)>[
    ('move_payment_credit_v1', 'p_reason', creditMoveReasonWidth),
    ('resolve_einvoice_manually_v1', 'p_reason', einvoiceReasonWidth),
    ('resolve_einvoice_manually_v1', 'p_evidence', einvoiceEvidenceWidth),
    ('set_capability_state_v1', 'p_reason', capabilityReasonWidth),
  ];

  for (final (function, parameter, width) in pairs) {
    test('$function clips $parameter at the width the form enforces', () {
      expect(
        _clip(_latestDefinition(function), parameter),
        width,
        reason:
            'the SQL cut of $function($parameter) and the client constant '
            'differ: change both together',
      );
    });
  }

  test('the capability reason column accepts what the form allows', () {
    final table = File(
      'supabase/migrations/0692_capability_states.sql',
    ).readAsStringSync();
    final m = RegExp(r'char_length\(reason\) <= (\d+)').firstMatch(table);
    expect(m, isNotNull);
    expect(int.parse(m!.group(1)!), capabilityReasonWidth);
  });

  test('the edge handler clips a declared value at the database width', () {
    final ts = File(
      'supabase/functions/send-e-invoice/handler.ts',
    ).readAsStringSync();
    final dart = int.parse(
      RegExp(r'const DECLARED_WIDTH = (\d+);').firstMatch(ts)!.group(1)!,
    );
    final sql = RegExp(
      r"left\(e\.value #>> '\{\}', (\d+)\)",
    ).firstMatch(_latestDefinition('provenance_clip_declared'));
    expect(sql, isNotNull);
    expect(dart, int.parse(sql!.group(1)!));
  });

  test('no other definer function clips a reason or evidence unpinned', () {
    final pinned = {for (final p in pairs) p.$1};
    final clip = RegExp(
      r'left\((?:btrim|trim)\((?:coalesce\()?p_(?:reason|evidence)',
    );
    final fn = RegExp(r'create or replace function public\.([a-z0-9_]+)\(');
    final latest = <String, String>{};
    for (final file in sqlFiles('supabase/migrations')
      ..sort((a, b) => a.path.compareTo(b.path))) {
      final text = file.readAsStringSync();
      final heads = fn.allMatches(text).toList();
      for (var i = 0; i < heads.length; i++) {
        final end = i + 1 < heads.length ? heads[i + 1].start : text.length;
        latest[heads[i].group(1)!] = text.substring(heads[i].start, end);
      }
    }
    final unpinned = [
      for (final e in latest.entries)
        if (clip.hasMatch(e.value) && !pinned.contains(e.key)) e.key,
    ];
    expect(
      unpinned.length,
      lessThanOrEqualTo(_unpinnedClippers),
      reason:
          'a new function clips a reason/evidence: if a form limits the same '
          'text, add its pair above; otherwise this ratchet may not grow '
          '(now: ${unpinned.length}, ceiling $_unpinnedClippers)',
    );
  });
}
