// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4402/#4403 -- the stock rules exist on the server (SQL, the authority) and
// in Dart (the Demo and the domain checks); the two cannot be left to drift.
// The refusal reasons: every reason the SQL can give is a `StockRefusal`, and
// a value no migration raises any more goes. A reason is raised by
// `stock_config_refuse(field, 'reason')` (also inside an anchored patch,
// where the quotes are doubled) or written by hand as the DKG11 detail
// `jsonb_build_object('field', ..., 'reason', '...')`.
import 'dart:io';

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

/// #4403 -- the reasons no pgTAP file names and no Demo fake gives yet, each with where the server raises it and
/// why it is not proven yet. The list only shrinks: a reason proven since leaves it (the test says so).
const _notYetProven = <String, String>{
  'default_sale_twice': 'save_stock_item_v1 (0836), a second default sale unit: the Demo checks the purchase twin only',
  'has_tags': 'a tag mode changed while tags are bound (0886): no pgTAP case binds a tag first',
  'inexact': 'workspace_unit_convert (0951), an answer six decimals cannot hold: the Demo rounds before it asks',
  'kind_unknown': 'save_stock_item_v1 (0836), a code kind that is not gtin or own: the screen offers only those two',
  'location_has_children': 'save_stock_location_v1 (0836), a place deactivated with active children',
  'lot_group_conflict': 'stock_put_away_apply (0840), two allocations naming one lot group differently',
  'name_length': 'item_group_save_core (0883), a name over 80 characters: the form holds 80',
  'one_subject': 'stock_trace_chain_v1 (0923, 0940), a request naming a piece and a movement at once',
  'out_of_range': 'a number outside its column (0836 shelf life, 0951 factor): the screens check the range first',
  'parent_inactive': 'save_stock_location_v1 (0836), a child put under a deactivated place',
  'place_unknown': 'item_group_check_value (0883), a group home zone that is no place of the business',
  'stock_on_hand': 'save_stock_item_v1 (0836), the stock setting turned off with goods on hand',
  'tag_owner_inactive': 'stock_tag_bind_v1 (0886), a tag bound to a deactivated item or place',
  'tag_owner_unknown': 'stock_tag_bind_v1 (0886), a tag bound to an owner of another business',
  'tracking_unsupported': 'save_stock_item_v1 (0836, 0931), a tracking the business has not turned on',
  'unit_duplicate': 'save_stock_item_v1 (0836), one packaging unit twice: the Demo checks it, under its own name only',
  'unit_fixed': 'workspace_units_guard (0951), a built-in unit given another factor',
  'unknown_reference': 'item_group_save_core (0883), a parameter naming a row of another business',
};

/// Each reason named by a pgTAP file of the database job, given by a Demo fake, or on [_notYetProven].
Set<String> unprovenReasons() {
  final demo = StringBuffer();
  for (final f in Directory('lib/core/demo/data').listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    if (name.startsWith('demo_stock_') || name == 'demo_item_groups.dart' || name == 'demo_workspace_units.dart') {
      demo.write(f.readAsStringSync());
    }
  }
  final pg = [for (final f in sqlFiles('supabase/tests/database')) f.readAsStringSync()].join('\n');
  final shown = demo.toString();
  return {
    for (final r in StockRefusal.values)
      if (r != StockRefusal.other && !shown.contains('StockRefusal.${r.name}') && !RegExp('\\b${r.wire}\\b').hasMatch(pg)) r.wire,
  };
}

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

  test('each reason is proven by a pgTAP file or a Demo fake, or listed with where it is raised and why not yet', () {
    final unproven = unprovenReasons();
    expect(unproven.difference(_notYetProven.keys.toSet()), isEmpty,
        reason: 'a reason no pgTAP file names and no Demo fake gives: prove it, or list it with why');
    expect(_notYetProven.keys.toSet().difference(unproven), isEmpty, reason: 'it is proven now: take it off the list');
  });
}
