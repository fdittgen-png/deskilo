// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — what the router's route lists and redirect read: the providers
// behind one small object, so a route list takes an environment instead of
// the router's closure over `ref`.
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/workspace/domain/workspace_feature.dart';
import '../features/workspace/domain/workspace_permission.dart';
import '../features/workspace/providers/workspace_providers.dart';
import 'route_access.dart';

/// The router's view of the app: an [AccessContext] over providers, read
/// at the moment a redirect asks (nothing is cached, nothing is written).
class RouteEnv implements AccessContext {
  RouteEnv(this.ref);

  final Ref ref;

  /// A rebuilt router may be asked once more; it answers "stay".
  bool get mounted => ref.mounted;

  @override
  bool featureEnabled(WorkspaceFeature feature) =>
      !ref.mounted || enabledFeatures.contains(feature);

  @override
  Set<WorkspaceFeature> get enabledFeatures =>
      ref.read(enabledFeaturesSyncProvider);

  @override
  Set<WorkspacePermission> get permissions => ref.read(myPermissionsProvider);

  @override
  bool get actsAsOwner =>
      ref.read(myMemberProvider).value?.actsAsOwner ?? false;

  @override
  bool get canAdminister =>
      ref.read(myMemberProvider).value?.canAdminister ?? false;

  @override
  bool get isAdmin => ref.read(myMemberProvider).value?.isAdmin ?? false;

  @override
  bool get hasPairedTwin =>
      ref.read(currentWorkspaceProvider).value?.pairId.isNotEmpty ?? false;

  /// #1085 — the redirect of a route declared with [access]. The door asks
  /// EXACTLY what the entry point's tile asks: `myPermissions` is the one
  /// client-side gate, and a route that reads a role flag instead drifts
  /// from its own menu entry the moment an owner delegates.
  GoRouterRedirect guard(RouteAccess access) =>
      (context, state) => !ref.mounted ? null : access.redirectFor(this);
}
