// SPDX-License-Identifier: 0BSD
//
// #1276 S2 — a template row from 0229 onwards carries what it holds and
// which format it is in; a row from before carries neither and must still
// read as the floor-plan-only template it always was.
import 'package:deskilo/features/workspace/domain/workspace_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a row saved before 0229 reads as a floor plan, version 1', () {
    final t = WorkspaceTemplate.fromRow(<String, dynamic>{
      'id': 't1',
      'key': 'tiny',
      'name': 'Tiny',
      'visibility': 'builtin',
      'floor_plan': <Object?>[],
    });
    expect(t.entities, ['floor_plan']);
    expect(t.schemaVersion, 1);
    expect(t.templateVersion, 1);
    expect(t.tags, isEmpty);
    expect(t.carriesConfiguration, isFalse);
  });

  test('a snapshot with configuration says so, with its versions and tags',
      () {
    final t = WorkspaceTemplate.fromRow(<String, dynamic>{
      'id': 't2',
      'key': 'rules',
      'name': 'Rules',
      'visibility': 'private',
      'owner_workspace_id': 'ws-1',
      'floor_plan': <Object?>[],
      'entities': <Object?>['booking_rules', 'tariffs'],
      'schema_version': 1,
      'template_version': 3,
      'tags': <Object?>['coworking', 'small'],
    });
    expect(t.entities, ['booking_rules', 'tariffs']);
    expect(t.templateVersion, 3);
    expect(t.tags, ['coworking', 'small']);
    expect(t.carriesConfiguration, isTrue);
  });
}
