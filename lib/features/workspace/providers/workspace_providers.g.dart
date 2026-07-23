// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workspaceRepository)
final workspaceRepositoryProvider = WorkspaceRepositoryProvider._();

final class WorkspaceRepositoryProvider
    extends
        $FunctionalProvider<
          WorkspaceRepository,
          WorkspaceRepository,
          WorkspaceRepository
        >
    with $Provider<WorkspaceRepository> {
  WorkspaceRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorkspaceRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkspaceRepository create(Ref ref) {
    return workspaceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspaceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspaceRepository>(value),
    );
  }
}

String _$workspaceRepositoryHash() =>
    r'e68d1435a2549d439fd19d30e8249162f7849608';

@ProviderFor(myWorkspaces)
final myWorkspacesProvider = MyWorkspacesProvider._();

final class MyWorkspacesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Workspace>>,
          List<Workspace>,
          FutureOr<List<Workspace>>
        >
    with $FutureModifier<List<Workspace>>, $FutureProvider<List<Workspace>> {
  MyWorkspacesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myWorkspacesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myWorkspacesHash();

  @$internal
  @override
  $FutureProviderElement<List<Workspace>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Workspace>> create(Ref ref) {
    return myWorkspaces(ref);
  }
}

String _$myWorkspacesHash() => r'198c8d5a8c8478df79f3177df2af39d009d2c760';

/// The persisted active-profile choice (#89). At START-UP the user's
/// DEFAULT profile wins when one is checked (#322); in-session switches
/// still take effect immediately and last until the next start. Falls
/// back to the first workspace when nothing matches.

@ProviderFor(ActiveWorkspaceId)
final activeWorkspaceIdProvider = ActiveWorkspaceIdProvider._();

/// The persisted active-profile choice (#89). At START-UP the user's
/// DEFAULT profile wins when one is checked (#322); in-session switches
/// still take effect immediately and last until the next start. Falls
/// back to the first workspace when nothing matches.
final class ActiveWorkspaceIdProvider
    extends $AsyncNotifierProvider<ActiveWorkspaceId, String?> {
  /// The persisted active-profile choice (#89). At START-UP the user's
  /// DEFAULT profile wins when one is checked (#322); in-session switches
  /// still take effect immediately and last until the next start. Falls
  /// back to the first workspace when nothing matches.
  ActiveWorkspaceIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeWorkspaceIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeWorkspaceIdHash();

  @$internal
  @override
  ActiveWorkspaceId create() => ActiveWorkspaceId();
}

String _$activeWorkspaceIdHash() => r'56952bcd9ab8f195349204c7f243eaf2b5036f35';

/// The persisted active-profile choice (#89). At START-UP the user's
/// DEFAULT profile wins when one is checked (#322); in-session switches
/// still take effect immediately and last until the next start. Falls
/// back to the first workspace when nothing matches.

abstract class _$ActiveWorkspaceId extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// The user-checked default profile (#322); null = none. Radio
/// semantics: checking one replaces the previous; re-checking the
/// current default clears it.

@ProviderFor(DefaultWorkspaceId)
final defaultWorkspaceIdProvider = DefaultWorkspaceIdProvider._();

/// The user-checked default profile (#322); null = none. Radio
/// semantics: checking one replaces the previous; re-checking the
/// current default clears it.
final class DefaultWorkspaceIdProvider
    extends $AsyncNotifierProvider<DefaultWorkspaceId, String?> {
  /// The user-checked default profile (#322); null = none. Radio
  /// semantics: checking one replaces the previous; re-checking the
  /// current default clears it.
  DefaultWorkspaceIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'defaultWorkspaceIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$defaultWorkspaceIdHash();

  @$internal
  @override
  DefaultWorkspaceId create() => DefaultWorkspaceId();
}

String _$defaultWorkspaceIdHash() =>
    r'69d9dda45e30ec3756d2d8c4af60f301efd19571';

/// The user-checked default profile (#322); null = none. Radio
/// semantics: checking one replaces the previous; re-checking the
/// current default clears it.

abstract class _$DefaultWorkspaceId extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// The active workspace (profile).

@ProviderFor(currentWorkspace)
final currentWorkspaceProvider = CurrentWorkspaceProvider._();

/// The active workspace (profile).

final class CurrentWorkspaceProvider
    extends
        $FunctionalProvider<
          AsyncValue<Workspace?>,
          Workspace?,
          FutureOr<Workspace?>
        >
    with $FutureModifier<Workspace?>, $FutureProvider<Workspace?> {
  /// The active workspace (profile).
  CurrentWorkspaceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentWorkspaceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentWorkspaceHash();

  @$internal
  @override
  $FutureProviderElement<Workspace?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Workspace?> create(Ref ref) {
    return currentWorkspace(ref);
  }
}

String _$currentWorkspaceHash() => r'e6a8c0bd37a3bab95967196d4286dfc44dc132a6';

/// All memberships of the active workspace (owner management + event
/// decider computation, #107).

@ProviderFor(workspaceMembers)
final workspaceMembersProvider = WorkspaceMembersProvider._();

/// All memberships of the active workspace (owner management + event
/// decider computation, #107).

final class WorkspaceMembersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Member>>,
          List<Member>,
          FutureOr<List<Member>>
        >
    with $FutureModifier<List<Member>>, $FutureProvider<List<Member>> {
  /// All memberships of the active workspace (owner management + event
  /// decider computation, #107).
  WorkspaceMembersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceMembersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceMembersHash();

  @$internal
  @override
  $FutureProviderElement<List<Member>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Member>> create(Ref ref) {
    return workspaceMembers(ref);
  }
}

String _$workspaceMembersHash() => r'22591de7638efc1d8b8ae3991143235e160da403';

/// All my membership rows across workspaces — one per profile (#89).

@ProviderFor(myMemberships)
final myMembershipsProvider = MyMembershipsProvider._();

/// All my membership rows across workspaces — one per profile (#89).

final class MyMembershipsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Member>>,
          List<Member>,
          FutureOr<List<Member>>
        >
    with $FutureModifier<List<Member>>, $FutureProvider<List<Member>> {
  /// All my membership rows across workspaces — one per profile (#89).
  MyMembershipsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myMembershipsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myMembershipsHash();

  @$internal
  @override
  $FutureProviderElement<List<Member>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Member>> create(Ref ref) {
    return myMemberships(ref);
  }
}

String _$myMembershipsHash() => r'addc53f1469bfa1a4b4c485af129c830dd2b49c2';

/// ISO weekdays (1=Mon..7=Sun) the active workspace is open on (#127).

@ProviderFor(openWeekdays)
final openWeekdaysProvider = OpenWeekdaysProvider._();

/// ISO weekdays (1=Mon..7=Sun) the active workspace is open on (#127).

final class OpenWeekdaysProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<int>>,
          List<int>,
          FutureOr<List<int>>
        >
    with $FutureModifier<List<int>>, $FutureProvider<List<int>> {
  /// ISO weekdays (1=Mon..7=Sun) the active workspace is open on (#127).
  OpenWeekdaysProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openWeekdaysProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openWeekdaysHash();

  @$internal
  @override
  $FutureProviderElement<List<int>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<int>> create(Ref ref) {
    return openWeekdays(ref);
  }
}

String _$openWeekdaysHash() => r'a009dd9b0d56fe04f6fd083a0511371e97097a80';

/// Booking-granularity rule of the active workspace (#200); flexible
/// while no workspace is selected or the key is absent.

@ProviderFor(bookingGranularity)
final bookingGranularityProvider = BookingGranularityProvider._();

/// Booking-granularity rule of the active workspace (#200); flexible
/// while no workspace is selected or the key is absent.

final class BookingGranularityProvider
    extends
        $FunctionalProvider<
          AsyncValue<BookingGranularity>,
          BookingGranularity,
          FutureOr<BookingGranularity>
        >
    with
        $FutureModifier<BookingGranularity>,
        $FutureProvider<BookingGranularity> {
  /// Booking-granularity rule of the active workspace (#200); flexible
  /// while no workspace is selected or the key is absent.
  BookingGranularityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookingGranularityProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookingGranularityHash();

  @$internal
  @override
  $FutureProviderElement<BookingGranularity> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BookingGranularity> create(Ref ref) {
    return bookingGranularity(ref);
  }
}

String _$bookingGranularityHash() =>
    r'bf5e00802791de2482d6dd476a2a5ab5c4a698b2';

/// One-off closure days of the active workspace, ordered by day (#127).

@ProviderFor(closureDays)
final closureDaysProvider = ClosureDaysProvider._();

/// One-off closure days of the active workspace, ordered by day (#127).

final class ClosureDaysProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ClosureDay>>,
          List<ClosureDay>,
          FutureOr<List<ClosureDay>>
        >
    with $FutureModifier<List<ClosureDay>>, $FutureProvider<List<ClosureDay>> {
  /// One-off closure days of the active workspace, ordered by day (#127).
  ClosureDaysProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'closureDaysProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$closureDaysHash();

  @$internal
  @override
  $FutureProviderElement<List<ClosureDay>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ClosureDay>> create(Ref ref) {
    return closureDays(ref);
  }
}

String _$closureDaysHash() => r'b4ec3e79a97e7a47c0340ece344f8b12625f590a';

/// Features enabled for the active workspace (#146). Deriving from
/// [currentWorkspace] is what makes flags "apply on connect": switching
/// profiles (#89) or refetching workspaces recomputes the set with the
/// new workspace's flags — no extra plumbing. No workspace = defaults.

@ProviderFor(enabledFeatures)
final enabledFeaturesProvider = EnabledFeaturesProvider._();

/// Features enabled for the active workspace (#146). Deriving from
/// [currentWorkspace] is what makes flags "apply on connect": switching
/// profiles (#89) or refetching workspaces recomputes the set with the
/// new workspace's flags — no extra plumbing. No workspace = defaults.

final class EnabledFeaturesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<WorkspaceFeature>>,
          Set<WorkspaceFeature>,
          FutureOr<Set<WorkspaceFeature>>
        >
    with
        $FutureModifier<Set<WorkspaceFeature>>,
        $FutureProvider<Set<WorkspaceFeature>> {
  /// Features enabled for the active workspace (#146). Deriving from
  /// [currentWorkspace] is what makes flags "apply on connect": switching
  /// profiles (#89) or refetching workspaces recomputes the set with the
  /// new workspace's flags — no extra plumbing. No workspace = defaults.
  EnabledFeaturesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'enabledFeaturesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$enabledFeaturesHash();

  @$internal
  @override
  $FutureProviderElement<Set<WorkspaceFeature>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Set<WorkspaceFeature>> create(Ref ref) {
    return enabledFeatures(ref);
  }
}

String _$enabledFeaturesHash() => r'e00f205c90b700b3e55fd58ecb417ad0ed1b03fb';

/// Sync convenience over [enabledFeatures] for build methods and router
/// redirects. While the workspace is still loading it falls back to ALL
/// registry defaults (everything ON) so the shell never flashes a
/// reduced tab bar.

@ProviderFor(enabledFeaturesSync)
final enabledFeaturesSyncProvider = EnabledFeaturesSyncProvider._();

/// Sync convenience over [enabledFeatures] for build methods and router
/// redirects. While the workspace is still loading it falls back to ALL
/// registry defaults (everything ON) so the shell never flashes a
/// reduced tab bar.

final class EnabledFeaturesSyncProvider
    extends
        $FunctionalProvider<
          Set<WorkspaceFeature>,
          Set<WorkspaceFeature>,
          Set<WorkspaceFeature>
        >
    with $Provider<Set<WorkspaceFeature>> {
  /// Sync convenience over [enabledFeatures] for build methods and router
  /// redirects. While the workspace is still loading it falls back to ALL
  /// registry defaults (everything ON) so the shell never flashes a
  /// reduced tab bar.
  EnabledFeaturesSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'enabledFeaturesSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$enabledFeaturesSyncHash();

  @$internal
  @override
  $ProviderElement<Set<WorkspaceFeature>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Set<WorkspaceFeature> create(Ref ref) {
    return enabledFeaturesSync(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<WorkspaceFeature> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<WorkspaceFeature>>(value),
    );
  }
}

String _$enabledFeaturesSyncHash() =>
    r'e00a472e646ad2f10612458cdd9653fa46b4e429';

/// The signed-in user's membership (roles!) in the active workspace.

@ProviderFor(myMember)
final myMemberProvider = MyMemberProvider._();

/// The signed-in user's membership (roles!) in the active workspace.

final class MyMemberProvider
    extends $FunctionalProvider<AsyncValue<Member?>, Member?, FutureOr<Member?>>
    with $FutureModifier<Member?>, $FutureProvider<Member?> {
  /// The signed-in user's membership (roles!) in the active workspace.
  MyMemberProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myMemberProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myMemberHash();

  @$internal
  @override
  $FutureProviderElement<Member?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Member?> create(Ref ref) {
    return myMember(ref);
  }
}

String _$myMemberHash() => r'4490381a6cf73ba9a3eb496d8d705538aaddcc41';
