// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3547 — Overview does not tell a business without places that switched-on
// features "wait for Bookable places". A practice keeps its place choices
// stored beneath the places it switched off; that is its choice, not setup
// left to do. A coworking space whose places are off, a business whose kind
// cannot be read, and a coworking space that also runs a practice keep the
// line. Nothing is written: the stored flags are the same before and after.
import 'package:deskilo/features/workspace/domain/attention.dart';
import 'package:deskilo/features/workspace/domain/business_kind.dart';
import 'package:deskilo/features/workspace/domain/business_profile.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/attention_providers.dart';
import 'package:deskilo/features/workspace/providers/business_kind_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_workspace_context.dart';

const _kinds = [
  BusinessKind(code: 'coworking', sortOrder: 10),
  BusinessKind(
    code: 'practice',
    sortOrder: 30,
    profile: {'placeBooking': false, 'services': true},
  ),
];

/// A business whose places are off while three place choices stay stored.
final _flags = <String, dynamic>{
  WorkspaceFeature.placeBooking.dbKey: false,
  WorkspaceFeature.levelBooking.dbKey: true,
  WorkspaceFeature.adminSeatBlocking.dbKey: true,
  WorkspaceFeature.kioskMode.dbKey: true,
};

class _Read {
  _Read(this.unblock, this.flagsBefore, this.flagsAfter);
  final List<Attention> unblock;
  final Map<String, dynamic> flagsBefore, flagsAfter;
}

Future<_Read> _read({
  required BusinessProfile profile,
  bool registryReadable = true,
}) async {
  final repo = FakeWorkspaceRepository.withWorkspace();
  repo.workspaces[0] = repo.workspaces[0].copyWith(featureFlags: _flags);
  final before = {...repo.workspaces[0].featureFlags};
  final container = ProviderContainer(
    overrides: [
      ...standardTestOverrides(workspace: repo),
      enabledFeaturesSyncProvider.overrideWithValue(const {}),
      myPermissionsProvider.overrideWithValue(const {
        WorkspacePermission.manageConfiguration,
      }),
      businessKindsProvider.overrideWith(
        (ref) async => registryReadable
            ? _kinds
            : throw StateError('the registry cannot be read'),
      ),
      businessProfileProvider.overrideWith((ref) async => profile),
      testReadyWorkspaceContext(),
    ],
  );
  addTearDown(container.dispose);
  // The kinds and the profile are read before the list is: the list watches
  // them and does not wait for them.
  final kindsKeep = container.listen(businessKindsProvider, (_, _) {});
  addTearDown(kindsKeep.close);
  final profileKeep = container.listen(businessProfileProvider, (_, _) {});
  addTearDown(profileKeep.close);
  await container
      .read(businessKindsProvider.future)
      .then<void>((_) {}, onError: (Object _) {});
  await container.read(businessProfileProvider.future);
  final keep = container.listen(attentionProvider, (_, _) {});
  addTearDown(keep.close);
  final all = await container.read(attentionProvider.future);
  return _Read(
    [
      for (final a in all)
        if (a.action == AttentionAction.unblock) a,
    ],
    before,
    {...repo.workspaces[0].featureFlags},
  );
}

void main() {
  test('a practice, whose kind switches the places off, is not told its '
      'stored place choices wait for them', () async {
    final read = await _read(profile: const BusinessProfile(kind: 'practice'));
    expect(read.unblock, isEmpty);
    expect(
      read.flagsAfter,
      read.flagsBefore,
      reason: 'reading Overview writes no flag and removes no stored choice',
    );
  });

  test('a coworking space whose places are off is still told what waits '
      'for them (the positive control)', () async {
    final read = await _read(profile: const BusinessProfile(kind: 'coworking'));
    expect(
      [for (final a in read.unblock) (a.subject, a.route)],
      [(WorkspaceFeature.placeBooking.name, '/features')],
    );
    expect(
      read.unblock.single.count,
      greaterThanOrEqualTo(3),
      reason: 'at least the three stored place choices wait for the places',
    );
  });

  test('a coworking space that also runs a practice keeps its line: the '
      'primary kind decides', () async {
    final read = await _read(
      profile: const BusinessProfile(
        kind: 'coworking',
        moreKinds: ['practice'],
      ),
    );
    expect(read.unblock, hasLength(1));
  });

  test('a registry that cannot be read leaves the line, the conservative '
      'answer, and writes nothing', () async {
    final read = await _read(
      profile: const BusinessProfile(kind: 'practice'),
      registryReadable: false,
    );
    expect(read.unblock, hasLength(1));
    expect(read.flagsAfter, read.flagsBefore);
  });
}
