// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4402/#4403 -- the stock rules exist on the server (SQL, the authority) and
// in Dart (the Demo and the domain checks); the two cannot be left to drift.
// The refusal reasons: every reason the SQL can give is a `StockRefusal`, and
// a value no migration raises any more goes. A reason is raised by
// `stock_config_refuse(field, 'reason')` (also inside an anchored patch,
// where the quotes are doubled) or written by hand as the DKG11 detail
// `jsonb_build_object('field', ..., 'reason', '...')`.
import 'package:deskilo/features/stock/domain/stock_refusal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lint/lint_sources.dart';

final _call = RegExp(
  r"stock_config_refuse\(((?:[^()']|'[^']*'|\((?:[^()']|'[^']*'|\([^()]*\))*\))*?),\s*'([a-z0-9_]+)'\s*\)",
);
final _patched = RegExp(r"stock_config_refuse\([^;]*?,\s*''([a-z0-9_]+)''\s*\)");
final _detail = RegExp(
  r"errcode\s*=\s*'DKG11'\s*,\s*detail\s*=\s*jsonb_build_object\('field',\s*[^,]+,\s*'reason',\s*'([a-z0-9_]+)'",
);

/// The reasons [sql] can refuse with (comments left out).
Set<String> refusalReasonsIn(String sql) {
  final code = sql.replaceAll(RegExp(r'--[^\n]*'), '');
  return {
    for (final m in _call.allMatches(code)) m.group(2)!,
    for (final m in _patched.allMatches(code)) m.group(1)!,
    for (final m in _detail.allMatches(code)) m.group(1)!,
  };
}

/// Every reason the migrations can refuse a stock command with.
Set<String> serverStockReasons() => {
  for (final f in sqlFiles('supabase/migrations')) ...refusalReasonsIn(f.readAsStringSync()),
};

void main() {
  test('a reason is found in a call, a patched call and a hand-written detail; a comment is not', () {
    expect(
      refusalReasonsIn("perform public.stock_config_refuse('lines[0]', 'malformed'); -- stock_config_refuse('x', 'no')"),
      {'malformed'},
    );
    expect(refusalReasonsIn("perform public.stock_config_refuse(format('lines[%s]', v_no - 1), 'reason_places');"), {'reason_places'});
    expect(refusalReasonsIn("E'perform public.stock_config_refuse(''tracking'', ''tags_off'');'"), {'tags_off'});
    expect(
      refusalReasonsIn("raise exception 'x' using errcode = 'DKG11',\n detail = jsonb_build_object('field', 'parent_id', 'reason', 'depth')::text;"),
      {'depth'},
    );
    expect(refusalReasonsIn('select 1'), isEmpty);
  });

  test('the enum holds exactly the reasons the SQL can give', () {
    final sql = serverStockReasons();
    final wires = {for (final r in StockRefusal.values) if (r != StockRefusal.other) r.wire};
    expect(
      sql.difference(wires),
      isEmpty,
      reason: 'the SQL gives a reason that is not a StockRefusal: add it to stock_refusal.dart and word it in stock_config_text.dart',
    );
    expect(wires.difference(sql), isEmpty, reason: 'a StockRefusal is no longer raised by any migration: remove it');
    expect(StockRefusal.fromWire('reason_places'), StockRefusal.reasonPlaces);
    expect(StockRefusal.fromWire('never_heard_of'), StockRefusal.other);
  });
}
