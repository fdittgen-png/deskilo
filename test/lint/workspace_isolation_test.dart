// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A workspace's data never mixes with another workspace's.
//
// A person may belong to several workspaces, and the database lets them read
// each of them (row-level security asks for membership, not for "the active
// workspace"). So the isolation inside the app is the app's own, and this
// test keeps it: every read or write of a workspace-scoped table in the data
// layer names the workspace, or the row it targets by id, or a parent that
// is itself one workspace's (a level's offices, an office's desks). A call
// that does none of these would return every workspace the person belongs to
// at once.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tables that carry a workspace_id, read from the migrations that create them.
Set<String> _workspaceTables() {
  final out = <String>{};
  final create = RegExp(
    r'create table (?:if not exists )?public\.(\w+)\s*\(([\s\S]*?)\n\);',
    caseSensitive: false,
  );
  for (final f in Directory('supabase/migrations').listSync().whereType<File>()) {
    if (!f.path.endsWith('.sql')) continue;
    for (final m in create.allMatches(f.readAsStringSync())) {
      if (RegExp(r'\bworkspace_id\b').hasMatch(m.group(2)!)) out.add(m.group(1)!);
    }
  }
  return out;
}

/// Calls scoped by a parent that is itself one workspace's, with the reason.
const Map<String, String> _scopedByParent = {
  'lib/features/plan/data/supabase_accessory_repository.dart:seat_accessories':
      'by seat id: a seat belongs to one workspace, and the trigger rejects '
          'cross-workspace links',
  'lib/features/plan/data/supabase_floor_plan_repository.dart:offices':
      'by level id: a level is one workspace\'s plan',
  'lib/features/plan/data/supabase_floor_plan_repository.dart:desks':
      'by the offices of one level',
  'lib/features/plan/data/supabase_floor_plan_repository.dart:seats':
      'by the desks of one level',
  'lib/features/plan/data/supabase_floor_plan_repository.dart:plan_images':
      'by level id',
  'lib/features/workspace/data/supabase_workspace_roles.dart:workspace_role_members':
      'by role id: a role is one workspace\'s',
  'lib/features/workspace/data/supabase_deployment_repository.dart:deployments':
      'by pair id: the dev and prod of one pair',
};

void main() {
  test('every data call on a workspace table names its workspace or its row', () {
    final tables = _workspaceTables();
    expect(tables, isNotEmpty);
    final call = RegExp(r"\.from\(\s*'(\w+)'\s*\)");
    final scoped = RegExp(
      r"workspace_id|workspaceId|\.eq\(\s*'id'|\.inFilter\(\s*'id'|\.match\(|"
      r"\.eq\(\s*'member_id'|\.eq\(\s*'user_id'|conversation_id",
    );
    final offenders = <String>[];
    final used = <String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in call.allMatches(src)) {
        final table = m.group(1)!;
        if (!tables.contains(table)) continue;
        final end = src.indexOf(';', m.end);
        final stmt = src.substring(
            m.start, (end < 0 ? m.end + 400 : end).clamp(0, m.start + 900));
        if (scoped.hasMatch(stmt)) continue;
        final key = '${f.path}:$table';
        if (_scopedByParent.containsKey(key)) {
          used.add(key);
        } else {
          offenders.add(key);
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'these read or write a workspace table without naming the '
            'workspace or the row — with two workspaces they would return both');
    expect(_scopedByParent.keys.toSet().difference(used), isEmpty,
        reason: 'an exemption nothing uses any more is a boundary kept alive '
            'for nothing');
  });
}
