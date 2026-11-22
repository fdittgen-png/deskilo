// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4168 (A) -- a freelancer is a kind of business of its own. Its proposal is the
// money side of a one-person service business and switches the places off,
// without a provider, messages, a public page or stock; the generic service
// kind is unchanged. A kind's profile has a version and a digest: what the owner
// reviewed is what a save checks, and a profile that changed after the review is
// refused (nothing written) so it is reviewed again. A save whose flags moved
// meanwhile keeps the kind and says the features were refused.
import 'package:deskilo/core/demo/data/business_kind_repository.dart';
import 'package:deskilo/core/demo/data/settings_repository.dart';
import 'package:deskilo/features/workspace/application/business_kind_commands.dart';
import 'package:deskilo/features/workspace/domain/business_kind.dart';
import 'package:deskilo/features/workspace/domain/business_kind_proposal.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/business_kind_names.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

class _Kinds implements BusinessKindRepository {
  _Kinds(this.rows);

  List<BusinessKind> rows;
  final writes = <(String, List<String>)>[];

  @override
  Future<List<BusinessKind>> kinds() async => rows;

  @override
  Future<void> setKind(
    String workspaceId, {
    required String kind,
    required List<String> moreKinds,
  }) async => writes.add((kind, moreKinds));

  /// Null: the server has no `apply_business_kind_v1`; else what it observed.
  BusinessKindApplied? applied;
  final applies = <(String, int, String)>[];

  @override
  Future<BusinessKindApplied> applyKind(
    String workspaceId, {
    required String requestId,
    required ReviewedKind reviewed,
    required Map<String, bool> flags,
    required Map<String, bool> expected,
  }) async {
    final answer = applied;
    if (answer == null) throw const BusinessKindApplyUnsupported();
    applies.add((reviewed.kind, reviewed.version, reviewed.digest));
    return answer;
  }
}

BusinessKind _freelancer({int version = 1, String digest = 'aa'}) => BusinessKind(
  code: 'freelancer',
  sortOrder: 45,
  profile: demoFreelancerProfile,
  profileVersion: version,
  profileDigest: digest,
);

void main() {
  test('the freelancer proposes the money side and switches the places off; '
      'it proposes no provider, messages, public page or stock', () {
    final proposal = proposalFor(
      profile: demoFreelancerProfile,
      raw: {for (final f in WorkspaceFeature.values) f},
      country: 'FR',
    );
    expect(proposal.switchesOff, contains(WorkspaceFeature.placeBooking));
    final named = {...proposal.flags.keys};
    expect(
      named.intersection({
        'onlinePayments',
        'messagesHub',
        'publicListings',
        'stockManagement',
        'seriesBooking',
      }),
      isEmpty,
    );
    expect(
      demoFreelancerProfile.keys,
      containsAll(['invoicing', 'billingCustomers', 'customerQuotes', 'serviceFulfilment', 'purchases']),
    );
  });

  test('the kinds read in order, the generic service unchanged', () {
    const demo = [
      'coworking',
      'studio',
      'practice',
      'salon',
      'freelancer',
      'shop',
      'service',
    ];
    expect(discoverableBusinessKinds, demo);
    expect(discoverableBusinessKinds.indexOf('freelancer'),
        discoverableBusinessKinds.indexOf('salon') + 1);
    expect(demoNoPlacesProfile.containsKey('onlinePayments'), isTrue);
    expect(demoFreelancerProfile.containsKey('onlinePayments'), isFalse);
  });

  test('a row without a version (a server from before 0834) reads as the '
      'first, with no digest', () {
    final kind = BusinessKind.fromJson(const {
      'code': 'freelancer',
      'sort_order': 45,
      'feature_profile': {'placeBooking': false},
    });
    expect(kind.profileVersion, 1);
    expect(kind.profileDigest, '');
    final newer = BusinessKind.fromJson(const {
      'code': 'freelancer',
      'sort_order': 45,
      'feature_profile': {'placeBooking': false},
      'profile_version': 3,
      'profile_digest': 'abc',
    });
    expect(newer.profileVersion, 3);
    expect(newer.sameProfileAs(kind), isFalse);
  });

  test('a save of the reviewed profile writes the kind; a profile that changed '
      'after the review writes nothing and asks for a new review', () async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    final kinds = _Kinds([_freelancer()]);
    final commands = BusinessKindCommands(kinds, workspace, FakeSettingsRepository(const []));
    final reviewed = _freelancer();
    final outcome = await commands.save(
      'ws-1',
      kind: 'freelancer',
      moreKinds: const [],
      flags: const {},
      raw: const {},
      reviewed: reviewed,
    );
    expect(outcome, BusinessKindOutcome.applied);
    expect(kinds.writes.single.$1, 'freelancer');

    kinds
      ..writes.clear()
      ..rows = [_freelancer(version: 2, digest: 'bb')];
    await expectLater(
      commands.save(
        'ws-1',
        kind: 'freelancer',
        moreKinds: const [],
        flags: const {'invoicing': true},
        raw: const {},
        reviewed: reviewed,
      ),
      throwsA(isA<BusinessKindProfileChanged>()),
    );
    expect(kinds.writes, isEmpty);
    expect(workspace.flagWrites, isEmpty);
  });

  test('flags that moved meanwhile: the kind stays saved and the result says '
      'the features were refused', () async {
    final workspace = FakeWorkspaceRepository.withWorkspace(
      featureFlags: const {'invoicing': true},
    );
    final kinds = _Kinds([_freelancer()]);
    final outcome = await BusinessKindCommands(kinds, workspace, FakeSettingsRepository(const [])).save(
      'ws-1',
      kind: 'freelancer',
      moreKinds: const [],
      flags: const {'invoicing': true},
      // planned on a set that no longer matches the stored flags
      raw: const {},
      reviewed: _freelancer(),
    );
    expect(outcome, BusinessKindOutcome.kindSavedFlagsRefused);
    expect(kinds.writes.single.$1, 'freelancer');
    expect(workspace.flagWrites, isEmpty);
  });

  test('a server that records the stages answers for both: the reviewed '
      'profile goes with the request, a refused kind stage asks for a new '
      'review and a refused features stage keeps the kind', () async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    final kinds = _Kinds([_freelancer(version: 2, digest: 'bb')]);
    final commands = BusinessKindCommands(kinds, workspace, FakeSettingsRepository(const []));
    Future<BusinessKindOutcome> save() => commands.save(
      'ws-1',
      kind: 'freelancer',
      moreKinds: const [],
      flags: const {'invoicing': true},
      raw: const {},
      reviewed: _freelancer(version: 2, digest: 'bb'),
    );

    kinds.applied = const BusinessKindApplied(kindStage: 'applied', flagsStage: 'applied');
    expect(await save(), BusinessKindOutcome.applied);
    expect(kinds.applies.single, ('freelancer', 2, 'bb'));
    // the earlier writers are not used when the server records the stages
    expect(kinds.writes, isEmpty);
    expect(workspace.flagWrites, isEmpty);

    kinds.applied = const BusinessKindApplied(kindStage: 'applied', flagsStage: 'refused', refusal: 'DK409');
    expect(await save(), BusinessKindOutcome.kindSavedFlagsRefused);

    kinds.applied = const BusinessKindApplied(kindStage: 'refused', flagsStage: 'none', refusal: 'profile_changed');
    await expectLater(save(), throwsA(isA<BusinessKindProfileChanged>()));
  });
}
