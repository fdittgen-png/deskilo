// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1456 — the fixed synthetic identities, spaces and metered providers
// the onboarding recipes run against. Same idea as `workload.dart`: the
// suite's in-memory repositories, with the calls a recipe makes to its
// providers counted at the repository seam as round trips. Nothing here
// is a production hook — every class is a test fake's subclass.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/core/demo/data/identity_binding_repository.dart';
import 'package:deskilo/features/auth/domain/auth_outcome.dart';
import 'package:deskilo/features/auth/domain/identity_binding.dart';
import 'package:deskilo/features/workspace/domain/invitation_answer.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../test/helpers/mock_providers.dart';
import 'workload.dart';

const kRecipeEmail = 'ada@deskilo.test';
const kRecipePassword = 'correct-horse-9';
const kRecipeName = 'Ada';

/// Two spaces the same person belongs to, in different roles: an owner
/// in A, a plain member in B. A result from one rendered in the other is
/// the scoping failure the returning entry must never read as success.
const kSpaceA = Workspace(
  id: 'ws-a',
  name: 'Atelier',
  countryCode: 'DE',
  currencyCode: 'EUR',
  timezone: 'Europe/Berlin',
  inviteCode: 'ATELIER22',
  environment: 'prod',
);
const kSpaceB = Workspace(
  id: 'ws-b',
  name: 'Kraftwerk',
  countryCode: 'DE',
  currencyCode: 'EUR',
  timezone: 'Europe/Berlin',
  inviteCode: 'KRAFTWERK22',
  environment: 'prod',
);
const kOwnerInA = Member(
  id: 'm-a',
  workspaceId: 'ws-a',
  userId: 'user-1',
  isAdmin: true,
  isOwner: true,
  status: MemberStatus.active,
);
const kMemberInB = Member(
  id: 'm-b',
  workspaceId: 'ws-b',
  userId: 'user-1',
  isAdmin: false,
  isOwner: false,
  status: MemberStatus.active,
);

/// A fresh app on its own container, so every sample is a cold mount.
Widget recipeApp(List<Override> overrides) => ProviderScope(
  key: UniqueKey(),
  overrides: overrides,
  child: const DeskiloApp(),
);

/// Sign-in and sign-up, each a round trip to the auth provider.
class MeteredAuth extends FakeAuthRepository {
  MeteredAuth(this.meter, {super.userId});

  final BackendMeter meter;

  @override
  Future<AuthResult> signInWithPassword({
    required String email,
    required String password,
  }) => meter.trip(
    'auth.signIn',
    () => super.signInWithPassword(email: email, password: password),
  );

  @override
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) => meter.trip(
    'auth.signUp',
    () => super.signUp(
      email: email,
      password: password,
      displayName: displayName,
    ),
  );

  @override
  Future<AuthResult> resendSignUpVerification(String email) =>
      meter.trip('auth.resend', () => super.resendSignUpVerification(email));
}

/// The membership reads and the writes onboarding makes.
class MeteredWorkspace extends FakeWorkspaceRepository {
  MeteredWorkspace(this.meter) : super();

  final BackendMeter meter;

  @override
  Future<List<Workspace>> fetchMyWorkspaces() =>
      meter.trip('workspace.fetchMine', super.fetchMyWorkspaces);

  @override
  Future<Member?> fetchMyMember(String workspaceId) => meter.trip(
    'workspace.fetchMyMember',
    () => super.fetchMyMember(workspaceId),
  );

  @override
  Future<String> createWorkspace({
    required String name,
    required String countryCode,
    required String currencyCode,
    required String timezone,
    WorkspaceEnvironment environment = WorkspaceEnvironment.development,
    bool withTwin = true,
    String? requestId,
    String? templateId,
  }) => meter.trip(
    'workspace.create',
    () => super.createWorkspace(
      name: name,
      countryCode: countryCode,
      currencyCode: currencyCode,
      timezone: timezone,
      environment: environment,
      withTwin: withTwin,
      requestId: requestId,
      templateId: templateId,
    ),
  );

  @override
  Future<InvitationAnswer> previewInvitation(String inviteCode) => meter.trip(
    'workspace.previewInvitation',
    () => super.previewInvitation(inviteCode),
  );

  @override
  Future<InvitationAnswer> joinByInvitation(String inviteCode) => meter.trip(
    'workspace.joinByInvitation',
    () => super.joinByInvitation(inviteCode),
  );

  /// Seeds the returning person's two spaces.
  void seedTwoSpaces() {
    workspaces
      ..clear()
      ..addAll(const [kSpaceA, kSpaceB]);
    myMember = kOwnerInA;
    extraMyMemberships
      ..clear()
      ..add(kMemberInB);
    openWeekdays['ws-a'] = const [1, 2, 3, 4, 5, 6, 7];
    openWeekdays['ws-b'] = const [1, 2, 3, 4, 5, 6, 7];
  }
}

/// Assistant eligibility on this database: a read and two writes.
class MeteredIdentity extends FakeIdentityBindingRepository {
  MeteredIdentity(this.meter) {
    capabilities = const DatabaseCapabilities(
      eligibility: McpEligibility.notRequested,
    );
  }

  final BackendMeter meter;

  @override
  Future<DatabaseCapabilities> databaseCapabilities() =>
      meter.trip('identity.capabilities', super.databaseCapabilities);

  @override
  Future<DatabaseCapabilities> requestMcpEligibility() =>
      meter.trip('identity.requestEligibility', super.requestMcpEligibility);

  @override
  Future<DatabaseCapabilities> withdrawMcpEligibility() =>
      meter.trip('identity.withdrawEligibility', super.withdrawMcpEligibility);
}

/// A small plan in each of [workspaces], metered like the journeys'.
MeteredPlans smallPlans(BackendMeter meter, List<String> workspaces) {
  final plans = MeteredPlans(meter);
  for (final ws in workspaces) {
    plans.seedSmallPlan(workspaceId: ws);
  }
  return plans;
}

/// The unmetered plan fake, for recipes whose plan is not what they
/// measure.
FakeFloorPlanRepository emptyPlans() => FakeFloorPlanRepository();
