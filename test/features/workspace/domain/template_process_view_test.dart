// SPDX-License-Identifier: 0BSD
//
// #1330 — a template's feature change-set, read by business process.
import 'package:deskilo/features/workspace/domain/template_preview.dart';
import 'package:deskilo/features/workspace/domain/template_process_view.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_process.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the delta is what differs between the resolved maps, not the raw '
      'keys — an absent key is its registry default', () {
    // A feature that ships on: absent before, written false after = a
    // flip. One that ships off: absent before, written false after =
    // nothing, whatever the raw maps look like.
    final shipsOn = featureManifest.entries
        .firstWhere((e) => e.value.defaultOn)
        .key
        .name;
    final shipsOff = featureManifest.entries
        .firstWhere((e) => !e.value.defaultOn)
        .key
        .name;
    final changes = featureChangesOf([
      {
        'scope': 'workspace',
        'op': 'change',
        'key': 'feature_flags',
        'before': <String, Object?>{},
        'after': {shipsOn: false, shipsOff: false},
      },
      {'scope': 'row', 'op': 'add', 'key': 'something-else'},
    ]);
    expect(changes, {shipsOn: false});
  });

  test('no feature_flags item, no changes; a non-boolean is ignored', () {
    expect(featureChangesOf(null), isEmpty);
    expect(featureChangesOf([{'key': 'name', 'before': 'a', 'after': 'b'}]),
        isEmpty);
    expect(
      featureChangesOf([
        {
          'key': 'feature_flags',
          'before': <String, Object?>{},
          'after': {'kioskMode': 'yes'},
        },
      ]),
      isEmpty,
    );
  });

  test('grouped by process in registry order, the flip under its '
      'subprocess, reserved capabilities last, unknown keys left out', () {
    final view = processViewOf({
      'invoicing': true,
      'kioskMode': true,
      'membersDirectory': false,
      'siteDocuments': true,
      'fromTheFuture': true,
    });
    final keys = [for (final g in view) g.processKey];
    // workspaceAccess comes before billingPayments in the registry.
    final access = workspaceProcesses.indexWhere((p) => p.key == 'workspaceAccess');
    final billing =
        workspaceProcesses.indexWhere((p) => p.key == homeProcessOf(WorkspaceFeature.invoicing));
    expect(access, lessThan(billing));
    expect(keys.first, 'workspaceAccess');
    expect(keys.last, isNull, reason: 'siteDocuments is reserved');
    expect(keys, isNot(contains('fromTheFuture')));

    final accessGroup = view.first;
    expect(
      [for (final c in accessGroup.changes) '${c.subprocessKey}/${c.feature.name}=${c.enabled}'],
      ['people/membersDirectory=false', 'physicalAccess/kioskMode=true'],
      reason: 'subprocess order of the registry, then capability order',
    );
    expect(accessGroup.onCount, 1);
    expect(accessGroup.offCount, 1);
    expect(view.last.changes.single.feature, WorkspaceFeature.siteDocuments);
    expect(view.last.changes.single.subprocessKey, isNull);
  });

  test('an empty delta is an empty view', () {
    expect(processViewOf(const {}), isEmpty);
  });

  test('the preview aggregates the flips of every group', () {
    final p = TemplatePreview.fromJson(<String, dynamic>{
      'compatibility': 'supported',
      'groups': [
        {
          'group': 'documents_operations',
          'state': 'change',
          'items': [
            {
              'key': 'feature_flags',
              'before': {'kioskMode': false},
              'after': {'kioskMode': true},
            },
          ],
        },
        {'group': 'space', 'state': 'new', 'items': [<String, Object?>{}]},
      ],
    });
    expect(p.groups.first.featureChanges, {'kioskMode': true});
    expect(p.groups.last.featureChanges, isEmpty);
    expect(p.featureChanges, {'kioskMode': true});
  });
}
