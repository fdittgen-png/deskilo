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

String _$activeWorkspaceIdHash() => r'a20b1251dc4ecb22f7d4d06c42ba829907901984';

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
///
/// SERVER-FIRST since #458: the choice lives on the profile row, so it
/// survives reinstalls and follows the user across platforms. The
/// local store is demoted to an offline cache, written through on
/// every successful read and toggle.

@ProviderFor(DefaultWorkspaceId)
final defaultWorkspaceIdProvider = DefaultWorkspaceIdProvider._();

/// The user-checked default profile (#322); null = none. Radio
/// semantics: checking one replaces the previous; re-checking the
/// current default clears it.
///
/// SERVER-FIRST since #458: the choice lives on the profile row, so it
/// survives reinstalls and follows the user across platforms. The
/// local store is demoted to an offline cache, written through on
/// every successful read and toggle.
final class DefaultWorkspaceIdProvider
    extends $AsyncNotifierProvider<DefaultWorkspaceId, String?> {
  /// The user-checked default profile (#322); null = none. Radio
  /// semantics: checking one replaces the previous; re-checking the
  /// current default clears it.
  ///
  /// SERVER-FIRST since #458: the choice lives on the profile row, so it
  /// survives reinstalls and follows the user across platforms. The
  /// local store is demoted to an offline cache, written through on
  /// every successful read and toggle.
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
    r'ca36be9bb7271ac5f009a2c531e9ce328acb18bd';

/// The user-checked default profile (#322); null = none. Radio
/// semantics: checking one replaces the previous; re-checking the
/// current default clears it.
///
/// SERVER-FIRST since #458: the choice lives on the profile row, so it
/// survives reinstalls and follows the user across platforms. The
/// local store is demoted to an offline cache, written through on
/// every successful read and toggle.

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

/// Working day of the active workspace (#446); [WorkHours.defaults]
/// while no workspace is selected or the keys are absent.

@ProviderFor(workHours)
final workHoursProvider = WorkHoursProvider._();

/// Working day of the active workspace (#446); [WorkHours.defaults]
/// while no workspace is selected or the keys are absent.

final class WorkHoursProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkHours>,
          WorkHours,
          FutureOr<WorkHours>
        >
    with $FutureModifier<WorkHours>, $FutureProvider<WorkHours> {
  /// Working day of the active workspace (#446); [WorkHours.defaults]
  /// while no workspace is selected or the keys are absent.
  WorkHoursProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workHoursProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workHoursHash();

  @$internal
  @override
  $FutureProviderElement<WorkHours> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<WorkHours> create(Ref ref) {
    return workHours(ref);
  }
}

String _$workHoursHash() => r'0089026f25376d6ab096cad781591258c48d9c86';

/// Notes visible to me in the active workspace (#456), newest first —
/// the shell listens and surfaces arrivals as local notifications.

@ProviderFor(myNotes)
final myNotesProvider = MyNotesProvider._();

/// Notes visible to me in the active workspace (#456), newest first —
/// the shell listens and surfaces arrivals as local notifications.

final class MyNotesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MemberNote>>,
          List<MemberNote>,
          FutureOr<List<MemberNote>>
        >
    with $FutureModifier<List<MemberNote>>, $FutureProvider<List<MemberNote>> {
  /// Notes visible to me in the active workspace (#456), newest first —
  /// the shell listens and surfaces arrivals as local notifications.
  MyNotesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myNotesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myNotesHash();

  @$internal
  @override
  $FutureProviderElement<List<MemberNote>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MemberNote>> create(Ref ref) {
    return myNotes(ref);
  }
}

String _$myNotesHash() => r'd6e2756b52ed2e4dd8aaf427eb15c34a4162d278';

/// Unread member notes (#464): notes from someone else, newer than the
/// device's SEEN stamp — the bell and the app-icon badge count them,
/// the Events screen clears them on open.

@ProviderFor(UnreadNoteCount)
final unreadNoteCountProvider = UnreadNoteCountProvider._();

/// Unread member notes (#464): notes from someone else, newer than the
/// device's SEEN stamp — the bell and the app-icon badge count them,
/// the Events screen clears them on open.
final class UnreadNoteCountProvider
    extends $AsyncNotifierProvider<UnreadNoteCount, int> {
  /// Unread member notes (#464): notes from someone else, newer than the
  /// device's SEEN stamp — the bell and the app-icon badge count them,
  /// the Events screen clears them on open.
  UnreadNoteCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unreadNoteCountProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unreadNoteCountHash();

  @$internal
  @override
  UnreadNoteCount create() => UnreadNoteCount();
}

String _$unreadNoteCountHash() => r'61e351ac783100c73aa7f576b72d69dd3d261798';

/// Unread member notes (#464): notes from someone else, newer than the
/// device's SEEN stamp — the bell and the app-icon badge count them,
/// the Events screen clears them on open.

abstract class _$UnreadNoteCount extends $AsyncNotifier<int> {
  FutureOr<int> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<int>, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<int>, int>,
              AsyncValue<int>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

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

String _$enabledFeaturesHash() => r'838e424e27423aebcbb620c0d2d369b6347f995c';

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
    r'c52b3f67c83044e46408ec70a8fcdfda35485b80';

/// Workspace-wide developer mode (#419, 0081): admin/owner-set, applies
/// to EVERY member — gates the e-invoice test environments and the
/// Developer screen. Realtime (0080) pushes a flip to all devices live.

@ProviderFor(devMode)
final devModeProvider = DevModeProvider._();

/// Workspace-wide developer mode (#419, 0081): admin/owner-set, applies
/// to EVERY member — gates the e-invoice test environments and the
/// Developer screen. Realtime (0080) pushes a flip to all devices live.

final class DevModeProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Workspace-wide developer mode (#419, 0081): admin/owner-set, applies
  /// to EVERY member — gates the e-invoice test environments and the
  /// Developer screen. Realtime (0080) pushes a flip to all devices live.
  DevModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devModeHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return devMode(ref);
  }
}

String _$devModeHash() => r'8c3eeb91c9bba4c0dc5bd44e790811c08412aced';

/// member id → email of the active workspace's members (#410). ADMIN
/// surface: short-circuits to {} for viewers who cannot administer (no
/// wasted RPC) — and the server enforces the same gate regardless.

@ProviderFor(memberEmails)
final memberEmailsProvider = MemberEmailsProvider._();

/// member id → email of the active workspace's members (#410). ADMIN
/// surface: short-circuits to {} for viewers who cannot administer (no
/// wasted RPC) — and the server enforces the same gate regardless.

final class MemberEmailsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, String>>,
          Map<String, String>,
          FutureOr<Map<String, String>>
        >
    with
        $FutureModifier<Map<String, String>>,
        $FutureProvider<Map<String, String>> {
  /// member id → email of the active workspace's members (#410). ADMIN
  /// surface: short-circuits to {} for viewers who cannot administer (no
  /// wasted RPC) — and the server enforces the same gate regardless.
  MemberEmailsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memberEmailsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memberEmailsHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, String>> create(Ref ref) {
    return memberEmails(ref);
  }
}

String _$memberEmailsHash() => r'cfccc637ccb06a0ea7e993be57e21be4324c5ac7';

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
