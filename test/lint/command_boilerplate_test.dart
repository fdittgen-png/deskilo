// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4399 -- a command starts with `command_actor(...)` and `request_begin(...)` (0948), not with the copies each command
// carried: nine `*_actor` helpers of 0.84 to 0.97 text similarity, and the advisory lock + request lookup + digest
// compare + refusal block eight times over five request stores. From 0949 on, a migration that writes the inline
// prelude (`auth.uid() is null or ... mcp_is_delegated()`) or the inline idempotency block (the `purchase_request:`
// advisory lock, or a read of `purchase_requests`) is refused: its function calls the helpers.
//
// The migrations up to 0948 keep what they have (applied files never change); the helpers are in 0948 itself.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The last migration that may carry the boilerplate: the one that adds the helpers.
const _lastCopy = '0948';

final _prelude = RegExp(r'auth\.uid\(\)\s+is\s+null\s+or\s+(?:public\.)?mcp_is_delegated\(\)', caseSensitive: false);
final _idempotency = RegExp(
  r"pg_advisory_xact_lock\s*\(\s*hashtextextended\s*\(\s*'purchase_request:|from\s+public\.purchase_requests\b",
  caseSensitive: false,
);

/// `NNNN: <what>` for each migration after [after] that writes the inline prelude or the inline idempotency block.
/// [sources] maps a migration's four-digit number to its text; comments are not code and are not read.
List<String> inlineBoilerplate(Map<String, String> sources, {String after = _lastCopy}) {
  final found = <String>[];
  for (final MapEntry(key: number, value: text) in sources.entries) {
    if (number.compareTo(after) <= 0) continue;
    final code = text.replaceAll(RegExp(r'--[^\n]*'), '');
    if (_prelude.hasMatch(code)) found.add('$number: the inline actor prelude (use command_actor)');
    if (_idempotency.hasMatch(code)) found.add('$number: the inline idempotency block (use request_begin / request_finish)');
  }
  return found..sort();
}

void main() {
  test('no migration after 0948 writes the inline actor prelude or the inline idempotency block', () {
    final found = inlineBoilerplate({
      for (final f in sqlFiles('supabase/migrations')) f.uri.pathSegments.last.substring(0, 4): f.readAsStringSync(),
    });
    expect(found, isEmpty,
        reason: 'A command starts with command_actor(workspace, permission, feature) and request_begin(workspace, '
            'request, operation, digest) -- 0948. Call them instead of copying their body:\n  ${found.join('\n  ')}');
  });

  test('the lint can fail: a fixture with either copy is found, a helper call and a comment are not', () {
    const prelude = '''
create or replace function public.x(p_workspace_id uuid) returns uuid language plpgsql as \$fn\$
begin
  if auth.uid() is null or public.mcp_is_delegated() then raise exception 'no' using errcode = 'DKN01'; end if;
  return null;
end \$fn\$;''';
    const block = '''
  perform pg_advisory_xact_lock(hashtextextended('purchase_request:' || p_workspace_id::text || p_request_id::text, 0));
  select * into v_done from public.purchase_requests where request_id = p_request_id;''';
    const clean = '''
-- the old copy was: auth.uid() is null or public.mcp_is_delegated()
create or replace function public.y(p_workspace_id uuid) returns uuid language plpgsql as \$fn\$
begin
  return public.command_actor(p_workspace_id, 'manageStock', 'stockManagement');
end \$fn\$;''';
    expect(inlineBoilerplate({'0949': prelude}), ['0949: the inline actor prelude (use command_actor)']);
    expect(inlineBoilerplate({'0950': block}), ['0950: the inline idempotency block (use request_begin / request_finish)']);
    expect(inlineBoilerplate({'0949': prelude, '0950': block}).length, 2);
    expect(inlineBoilerplate({'0951': clean}), isEmpty);
    expect(inlineBoilerplate({'0948': prelude + block, '0836': prelude}), isEmpty, reason: 'up to 0948 the copies stay');
  });
}
