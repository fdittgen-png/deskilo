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

/// #1654 — the signed-in account, for scoping a per-account device
/// preference (the Get started dismissal); null while signed out. Read
/// from the session, not from a membership row, so a membership that
/// could not be loaded still has an account to remember its answer for.

@ProviderFor(currentAccountId)
final currentAccountIdProvider = CurrentAccountIdProvider._();

/// #1654 — the signed-in account, for scoping a per-account device
/// preference (the Get started dismissal); null while signed out. Read
/// from the session, not from a membership row, so a membership that
/// could not be loaded still has an account to remember its answer for.

final class CurrentAccountIdProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// #1654 — the signed-in account, for scoping a per-account device
  /// preference (the Get started dismissal); null while signed out. Read
  /// from the session, not from a membership row, so a membership that
  /// could not be loaded still has an account to remember its answer for.
  CurrentAccountIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentAccountIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentAccountIdHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return currentAccountId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$currentAccountIdHash() => r'1f690b2d3a9dd0efc18bbc17c70099a477dbcf87';

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

String _$activeWorkspaceIdHash() => r'192060469f57531a2822f3cb705f72a6b3a74096';

/// The persisted active-profile choice (#89). At START-UP the user's
/// DEFAULT profile wins when one is checked (#322); in-session switches
/// still take effect immediately and last until the next start. Falls
/// back to the first workspace when nothing matches.

abstract class _$ActiveWorkspaceId extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
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
    r'33a0efae5d3f102c9c1816be7383ce2e0c100db6';

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
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
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

/// #1449 — the decisions behind starting a conversation: whether picking
/// a second person makes it a group, and that a name already taken is a
/// correction rather than a failure.

@ProviderFor(startConversationCommand)
final startConversationCommandProvider = StartConversationCommandProvider._();

/// #1449 — the decisions behind starting a conversation: whether picking
/// a second person makes it a group, and that a name already taken is a
/// correction rather than a failure.

final class StartConversationCommandProvider
    extends $FunctionalProvider<Conversations, Conversations, Conversations>
    with $Provider<Conversations> {
  /// #1449 — the decisions behind starting a conversation: whether picking
  /// a second person makes it a group, and that a name already taken is a
  /// correction rather than a failure.
  StartConversationCommandProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'startConversationCommandProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$startConversationCommandHash();

  @$internal
  @override
  $ProviderElement<Conversations> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Conversations create(Ref ref) {
    return startConversationCommand(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Conversations value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Conversations>(value),
    );
  }
}

String _$startConversationCommandHash() =>
    r'942ce4132b6a5f45e51a1913773daa96b0ed5467';

/// #1449 — starting a workspace: what a creation needs before it is one,
/// and the request id that makes a retry the SAME creation.

@ProviderFor(workspaceStart)
final workspaceStartProvider = WorkspaceStartProvider._();

/// #1449 — starting a workspace: what a creation needs before it is one,
/// and the request id that makes a retry the SAME creation.

final class WorkspaceStartProvider
    extends $FunctionalProvider<WorkspaceStart, WorkspaceStart, WorkspaceStart>
    with $Provider<WorkspaceStart> {
  /// #1449 — starting a workspace: what a creation needs before it is one,
  /// and the request id that makes a retry the SAME creation.
  WorkspaceStartProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceStartProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceStartHash();

  @$internal
  @override
  $ProviderElement<WorkspaceStart> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WorkspaceStart create(Ref ref) {
    return workspaceStart(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspaceStart value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspaceStart>(value),
    );
  }
}

String _$workspaceStartHash() => r'f2e03f5b0054327d8a2e39eff27edaf972c37fe1';

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

String _$workspaceMembersHash() => r'70057020bede2169b5f0a0eb60981d23fd535e89';

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
/// The document library (#500) — RLS trims rows to the caller's role.

@ProviderFor(workspaceDocuments)
final workspaceDocumentsProvider = WorkspaceDocumentsProvider._();

/// ISO weekdays (1=Mon..7=Sun) the active workspace is open on (#127).
/// The document library (#500) — RLS trims rows to the caller's role.

final class WorkspaceDocumentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WorkspaceDocument>>,
          List<WorkspaceDocument>,
          FutureOr<List<WorkspaceDocument>>
        >
    with
        $FutureModifier<List<WorkspaceDocument>>,
        $FutureProvider<List<WorkspaceDocument>> {
  /// ISO weekdays (1=Mon..7=Sun) the active workspace is open on (#127).
  /// The document library (#500) — RLS trims rows to the caller's role.
  WorkspaceDocumentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceDocumentsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceDocumentsHash();

  @$internal
  @override
  $FutureProviderElement<List<WorkspaceDocument>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<WorkspaceDocument>> create(Ref ref) {
    return workspaceDocuments(ref);
  }
}

String _$workspaceDocumentsHash() =>
    r'bdab372d7600470af319834cb90cb4d237bf51bb';

@ProviderFor(openWeekdays)
final openWeekdaysProvider = OpenWeekdaysProvider._();

final class OpenWeekdaysProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<int>>,
          List<int>,
          FutureOr<List<int>>
        >
    with $FutureModifier<List<int>>, $FutureProvider<List<int>> {
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

/// The #600 booking-policy switches of the active workspace; all OFF
/// while no workspace is selected or the keys are absent.

@ProviderFor(bookingPolicies)
final bookingPoliciesProvider = BookingPoliciesProvider._();

/// The #600 booking-policy switches of the active workspace; all OFF
/// while no workspace is selected or the keys are absent.

final class BookingPoliciesProvider
    extends
        $FunctionalProvider<
          AsyncValue<BookingPolicies>,
          BookingPolicies,
          FutureOr<BookingPolicies>
        >
    with $FutureModifier<BookingPolicies>, $FutureProvider<BookingPolicies> {
  /// The #600 booking-policy switches of the active workspace; all OFF
  /// while no workspace is selected or the keys are absent.
  BookingPoliciesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookingPoliciesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookingPoliciesHash();

  @$internal
  @override
  $FutureProviderElement<BookingPolicies> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BookingPolicies> create(Ref ref) {
    return bookingPolicies(ref);
  }
}

String _$bookingPoliciesHash() => r'fbcb72f764ca9790de2ffcdc3be5e3ef1499084f';

/// #1294 — how a newly joining member starts, as the active workspace
/// says. The product defaults (100 %, blocked) while nothing is
/// configured, which is what the server applies too.

@ProviderFor(newMemberDefaults)
final newMemberDefaultsProvider = NewMemberDefaultsProvider._();

/// #1294 — how a newly joining member starts, as the active workspace
/// says. The product defaults (100 %, blocked) while nothing is
/// configured, which is what the server applies too.

final class NewMemberDefaultsProvider
    extends
        $FunctionalProvider<
          AsyncValue<NewMemberDefaults>,
          NewMemberDefaults,
          FutureOr<NewMemberDefaults>
        >
    with
        $FutureModifier<NewMemberDefaults>,
        $FutureProvider<NewMemberDefaults> {
  /// #1294 — how a newly joining member starts, as the active workspace
  /// says. The product defaults (100 %, blocked) while nothing is
  /// configured, which is what the server applies too.
  NewMemberDefaultsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'newMemberDefaultsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$newMemberDefaultsHash();

  @$internal
  @override
  $FutureProviderElement<NewMemberDefaults> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<NewMemberDefaults> create(Ref ref) {
    return newMemberDefaults(ref);
  }
}

String _$newMemberDefaultsHash() => r'ca69daf6ac603005a39a35abc07cee26d32c0f91';

/// #1277 S3 — renaming a word, as a decision rather than a repository
/// call (ADR 0024).
///
/// The wording editor is a ROUTE, so nothing can hand it a command the
/// way `availability_screen` hands one to the holidays sheet. This is
/// the seam instead: the provider owns the wiring, the widget says what
/// the owner asked for, and `WordingTerms` decides which write that is.

@ProviderFor(wordingTerms)
final wordingTermsProvider = WordingTermsProvider._();

/// #1277 S3 — renaming a word, as a decision rather than a repository
/// call (ADR 0024).
///
/// The wording editor is a ROUTE, so nothing can hand it a command the
/// way `availability_screen` hands one to the holidays sheet. This is
/// the seam instead: the provider owns the wiring, the widget says what
/// the owner asked for, and `WordingTerms` decides which write that is.

final class WordingTermsProvider
    extends $FunctionalProvider<WordingTerms, WordingTerms, WordingTerms>
    with $Provider<WordingTerms> {
  /// #1277 S3 — renaming a word, as a decision rather than a repository
  /// call (ADR 0024).
  ///
  /// The wording editor is a ROUTE, so nothing can hand it a command the
  /// way `availability_screen` hands one to the holidays sheet. This is
  /// the seam instead: the provider owns the wiring, the widget says what
  /// the owner asked for, and `WordingTerms` decides which write that is.
  WordingTermsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wordingTermsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wordingTermsHash();

  @$internal
  @override
  $ProviderElement<WordingTerms> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WordingTerms create(Ref ref) {
    return wordingTerms(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WordingTerms value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WordingTerms>(value),
    );
  }
}

String _$wordingTermsHash() => r'0679271af9729a2b06ad2b402ec8316756281bfd';

/// #1289 — the decision to give this space its own colour. The contrast
/// check is the app's one implementation (`DeskiloTheme.refusals`),
/// handed in here so `application/` stays pure Dart.

@ProviderFor(workspaceColours)
final workspaceColoursProvider = WorkspaceColoursProvider._();

/// #1289 — the decision to give this space its own colour. The contrast
/// check is the app's one implementation (`DeskiloTheme.refusals`),
/// handed in here so `application/` stays pure Dart.

final class WorkspaceColoursProvider
    extends
        $FunctionalProvider<
          WorkspaceColours,
          WorkspaceColours,
          WorkspaceColours
        >
    with $Provider<WorkspaceColours> {
  /// #1289 — the decision to give this space its own colour. The contrast
  /// check is the app's one implementation (`DeskiloTheme.refusals`),
  /// handed in here so `application/` stays pure Dart.
  WorkspaceColoursProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceColoursProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceColoursHash();

  @$internal
  @override
  $ProviderElement<WorkspaceColours> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WorkspaceColours create(Ref ref) {
    return workspaceColours(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspaceColours value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspaceColours>(value),
    );
  }
}

String _$workspaceColoursHash() => r'46fc158f4b53c1b99d72050628f81618ae6f4361';

/// #1277 — the active workspace's own words for allow-listed product
/// terms, `{locale: {key: text}}`.
///
/// Empty in three cases, all of which render the product's own wording:
/// the feature is off, no workspace is selected, or the space renamed
/// nothing. The FLAG is checked here rather than at the 33 call sites —
/// a gate threaded through every legend label and tab title would be a
/// gate nobody could see.

@ProviderFor(lexicon)
final lexiconProvider = LexiconProvider._();

/// #1277 — the active workspace's own words for allow-listed product
/// terms, `{locale: {key: text}}`.
///
/// Empty in three cases, all of which render the product's own wording:
/// the feature is off, no workspace is selected, or the space renamed
/// nothing. The FLAG is checked here rather than at the 33 call sites —
/// a gate threaded through every legend label and tab title would be a
/// gate nobody could see.

final class LexiconProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, dynamic>>,
          Map<String, dynamic>,
          FutureOr<Map<String, dynamic>>
        >
    with
        $FutureModifier<Map<String, dynamic>>,
        $FutureProvider<Map<String, dynamic>> {
  /// #1277 — the active workspace's own words for allow-listed product
  /// terms, `{locale: {key: text}}`.
  ///
  /// Empty in three cases, all of which render the product's own wording:
  /// the feature is off, no workspace is selected, or the space renamed
  /// nothing. The FLAG is checked here rather than at the 33 call sites —
  /// a gate threaded through every legend label and tab title would be a
  /// gate nobody could see.
  LexiconProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lexiconProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lexiconHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, dynamic>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, dynamic>> create(Ref ref) {
    return lexicon(ref);
  }
}

String _$lexiconHash() => r'5974dd4ea3c1d3d39e53969807af999a7ebe5fc3';

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

String _$workHoursHash() => r'3633e9e8c3605565e56f1c45673591d292c221de';

/// #1307 S4 — where the active workspace's working day came from. Watches
/// [workHoursProvider], so an edit or a reset re-asks.

@ProviderFor(workHoursProvenance)
final workHoursProvenanceProvider = WorkHoursProvenanceProvider._();

/// #1307 S4 — where the active workspace's working day came from. Watches
/// [workHoursProvider], so an edit or a reset re-asks.

final class WorkHoursProvenanceProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkHoursProvenance>,
          WorkHoursProvenance,
          FutureOr<WorkHoursProvenance>
        >
    with
        $FutureModifier<WorkHoursProvenance>,
        $FutureProvider<WorkHoursProvenance> {
  /// #1307 S4 — where the active workspace's working day came from. Watches
  /// [workHoursProvider], so an edit or a reset re-asks.
  WorkHoursProvenanceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workHoursProvenanceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workHoursProvenanceHash();

  @$internal
  @override
  $FutureProviderElement<WorkHoursProvenance> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<WorkHoursProvenance> create(Ref ref) {
    return workHoursProvenance(ref);
  }
}

String _$workHoursProvenanceHash() =>
    r'01abb85fafea3f0a30700a038ad0464844a0a61c';

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

String _$myNotesHash() => r'8ca767ec88da938ddc1c772f4a76256eb64c3ccd';

/// The ids of my UNREAD received notes (#539): a direct note is unread
/// until its read receipt lands (0105 — stamped when its CONVERSATION
/// opens, 0108); a broadcast has no per-reader server state, so it
/// counts until the Events screen has been opened (the device stamp).
/// Rows bold on it, the bell counts it, the Unread filter shows it.

@ProviderFor(unreadNoteIds)
final unreadNoteIdsProvider = UnreadNoteIdsProvider._();

/// The ids of my UNREAD received notes (#539): a direct note is unread
/// until its read receipt lands (0105 — stamped when its CONVERSATION
/// opens, 0108); a broadcast has no per-reader server state, so it
/// counts until the Events screen has been opened (the device stamp).
/// Rows bold on it, the bell counts it, the Unread filter shows it.

final class UnreadNoteIdsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<String>>,
          Set<String>,
          FutureOr<Set<String>>
        >
    with $FutureModifier<Set<String>>, $FutureProvider<Set<String>> {
  /// The ids of my UNREAD received notes (#539): a direct note is unread
  /// until its read receipt lands (0105 — stamped when its CONVERSATION
  /// opens, 0108); a broadcast has no per-reader server state, so it
  /// counts until the Events screen has been opened (the device stamp).
  /// Rows bold on it, the bell counts it, the Unread filter shows it.
  UnreadNoteIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unreadNoteIdsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unreadNoteIdsHash();

  @$internal
  @override
  $FutureProviderElement<Set<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Set<String>> create(Ref ref) {
    return unreadNoteIds(ref);
  }
}

String _$unreadNoteIdsHash() => r'6edef797a043bcafc79a7a635c8b1695fbca352f';

/// Unread member notes (#464, reworked #539): the bell and the
/// app-icon badge count [unreadNoteIds]. Direct notes clear when their
/// conversation is opened; broadcasts when the Events screen is.

@ProviderFor(UnreadNoteCount)
final unreadNoteCountProvider = UnreadNoteCountProvider._();

/// Unread member notes (#464, reworked #539): the bell and the
/// app-icon badge count [unreadNoteIds]. Direct notes clear when their
/// conversation is opened; broadcasts when the Events screen is.
final class UnreadNoteCountProvider
    extends $AsyncNotifierProvider<UnreadNoteCount, int> {
  /// Unread member notes (#464, reworked #539): the bell and the
  /// app-icon badge count [unreadNoteIds]. Direct notes clear when their
  /// conversation is opened; broadcasts when the Events screen is.
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

String _$unreadNoteCountHash() => r'cce3ecd7115d752d28443cfe63bd94fde8b2dfa3';

/// Unread member notes (#464, reworked #539): the bell and the
/// app-icon badge count [unreadNoteIds]. Direct notes clear when their
/// conversation is opened; broadcasts when the Events screen is.

abstract class _$UnreadNoteCount extends $AsyncNotifier<int> {
  FutureOr<int> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<int>, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<int>, int>,
              AsyncValue<int>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
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

/// #1289 — the active workspace's brand seed (opaque ARGB), or null for
/// the product's own palette: null while the flag is off, while nothing
/// is loaded yet, and for a workspace that chose nothing. The theme reads
/// this and nothing else, so a test that injects no workspace sees the
/// product colours — branding is off by default in tests by construction.

@ProviderFor(workspaceBrandSeed)
final workspaceBrandSeedProvider = WorkspaceBrandSeedProvider._();

/// #1289 — the active workspace's brand seed (opaque ARGB), or null for
/// the product's own palette: null while the flag is off, while nothing
/// is loaded yet, and for a workspace that chose nothing. The theme reads
/// this and nothing else, so a test that injects no workspace sees the
/// product colours — branding is off by default in tests by construction.

final class WorkspaceBrandSeedProvider
    extends $FunctionalProvider<int?, int?, int?>
    with $Provider<int?> {
  /// #1289 — the active workspace's brand seed (opaque ARGB), or null for
  /// the product's own palette: null while the flag is off, while nothing
  /// is loaded yet, and for a workspace that chose nothing. The theme reads
  /// this and nothing else, so a test that injects no workspace sees the
  /// product colours — branding is off by default in tests by construction.
  WorkspaceBrandSeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceBrandSeedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceBrandSeedHash();

  @$internal
  @override
  $ProviderElement<int?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int? create(Ref ref) {
    return workspaceBrandSeed(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }
}

String _$workspaceBrandSeedHash() =>
    r'2c79ad4af1690dfc3228e144aa89ec9c4729ec19';

/// #1289 — the workspace's own office fills, empty for the product's
/// palette. Same gate as the seed: off the flag, and off a workspace
/// that chose nothing, the plan paints exactly as it always has.

@ProviderFor(workspaceOfficePalette)
final workspaceOfficePaletteProvider = WorkspaceOfficePaletteProvider._();

/// #1289 — the workspace's own office fills, empty for the product's
/// palette. Same gate as the seed: off the flag, and off a workspace
/// that chose nothing, the plan paints exactly as it always has.

final class WorkspaceOfficePaletteProvider
    extends $FunctionalProvider<List<Color>, List<Color>, List<Color>>
    with $Provider<List<Color>> {
  /// #1289 — the workspace's own office fills, empty for the product's
  /// palette. Same gate as the seed: off the flag, and off a workspace
  /// that chose nothing, the plan paints exactly as it always has.
  WorkspaceOfficePaletteProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceOfficePaletteProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceOfficePaletteHash();

  @$internal
  @override
  $ProviderElement<List<Color>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Color> create(Ref ref) {
    return workspaceOfficePalette(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Color> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Color>>(value),
    );
  }
}

String _$workspaceOfficePaletteHash() =>
    r'779fc713f7248d5558aa6e267ff4b154c2c53f86';

/// #1289 — one workspace's emblem, or null when it has none or the flag
/// is off. Kept alive and keyed, so the drawer and the switcher share
/// one download per space rather than one per widget.

@ProviderFor(workspaceEmblemOf)
final workspaceEmblemOfProvider = WorkspaceEmblemOfFamily._();

/// #1289 — one workspace's emblem, or null when it has none or the flag
/// is off. Kept alive and keyed, so the drawer and the switcher share
/// one download per space rather than one per widget.

final class WorkspaceEmblemOfProvider
    extends
        $FunctionalProvider<
          AsyncValue<Uint8List?>,
          Uint8List?,
          FutureOr<Uint8List?>
        >
    with $FutureModifier<Uint8List?>, $FutureProvider<Uint8List?> {
  /// #1289 — one workspace's emblem, or null when it has none or the flag
  /// is off. Kept alive and keyed, so the drawer and the switcher share
  /// one download per space rather than one per widget.
  WorkspaceEmblemOfProvider._({
    required WorkspaceEmblemOfFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workspaceEmblemOfProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workspaceEmblemOfHash();

  @override
  String toString() {
    return r'workspaceEmblemOfProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Uint8List?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Uint8List?> create(Ref ref) {
    final argument = this.argument as String;
    return workspaceEmblemOf(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceEmblemOfProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workspaceEmblemOfHash() => r'75727ddccede0b9c87bd64738cc7ebea877f7d3f';

/// #1289 — one workspace's emblem, or null when it has none or the flag
/// is off. Kept alive and keyed, so the drawer and the switcher share
/// one download per space rather than one per widget.

final class WorkspaceEmblemOfFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Uint8List?>, String> {
  WorkspaceEmblemOfFamily._()
    : super(
        retry: null,
        name: r'workspaceEmblemOfProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// #1289 — one workspace's emblem, or null when it has none or the flag
  /// is off. Kept alive and keyed, so the drawer and the switcher share
  /// one download per space rather than one per widget.

  WorkspaceEmblemOfProvider call(String workspaceId) =>
      WorkspaceEmblemOfProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'workspaceEmblemOfProvider';
}

/// The active workspace's emblem; null while nothing is loaded.

@ProviderFor(workspaceEmblem)
final workspaceEmblemProvider = WorkspaceEmblemProvider._();

/// The active workspace's emblem; null while nothing is loaded.

final class WorkspaceEmblemProvider
    extends
        $FunctionalProvider<
          AsyncValue<Uint8List?>,
          Uint8List?,
          FutureOr<Uint8List?>
        >
    with $FutureModifier<Uint8List?>, $FutureProvider<Uint8List?> {
  /// The active workspace's emblem; null while nothing is loaded.
  WorkspaceEmblemProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceEmblemProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceEmblemHash();

  @$internal
  @override
  $FutureProviderElement<Uint8List?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Uint8List?> create(Ref ref) {
    return workspaceEmblem(ref);
  }
}

String _$workspaceEmblemHash() => r'216e6c69ac9db8f25ac6dfae0ca62c30d2d9f8cc';

/// #1289 — the decision behind choosing an emblem. The re-encode needs
/// the engine, so it is handed in here and `application/` stays pure.

@ProviderFor(emblems)
final emblemsProvider = EmblemsProvider._();

/// #1289 — the decision behind choosing an emblem. The re-encode needs
/// the engine, so it is handed in here and `application/` stays pure.

final class EmblemsProvider
    extends $FunctionalProvider<Emblems, Emblems, Emblems>
    with $Provider<Emblems> {
  /// #1289 — the decision behind choosing an emblem. The re-encode needs
  /// the engine, so it is handed in here and `application/` stays pure.
  EmblemsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emblemsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$emblemsHash();

  @$internal
  @override
  $ProviderElement<Emblems> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Emblems create(Ref ref) {
    return emblems(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Emblems value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Emblems>(value),
    );
  }
}

String _$emblemsHash() => r'10e3bfbef40c8ee6018446dbb61c415e2109a784';

/// #513 — MY effective permissions under the workspace's role matrix.
/// The one client-side gate: screens ask for a permission, never for a
/// role flag. Falls back to {} while member/workspace load.

@ProviderFor(myPermissions)
final myPermissionsProvider = MyPermissionsProvider._();

/// #513 — MY effective permissions under the workspace's role matrix.
/// The one client-side gate: screens ask for a permission, never for a
/// role flag. Falls back to {} while member/workspace load.

final class MyPermissionsProvider
    extends
        $FunctionalProvider<
          Set<WorkspacePermission>,
          Set<WorkspacePermission>,
          Set<WorkspacePermission>
        >
    with $Provider<Set<WorkspacePermission>> {
  /// #513 — MY effective permissions under the workspace's role matrix.
  /// The one client-side gate: screens ask for a permission, never for a
  /// role flag. Falls back to {} while member/workspace load.
  MyPermissionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myPermissionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myPermissionsHash();

  @$internal
  @override
  $ProviderElement<Set<WorkspacePermission>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Set<WorkspacePermission> create(Ref ref) {
    return myPermissions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<WorkspacePermission> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<WorkspacePermission>>(value),
    );
  }
}

String _$myPermissionsHash() => r'54909a43d3e7193da3d9f3f1f5b811ce3eb27d74';

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

String _$memberEmailsHash() => r'b3ed673c90c64b8b4d394a2b490e510e598238a0';

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

String _$myMemberHash() => r'08e79acaed8f2f29f630ee1a1732f2f25fbeddf4';

/// #915 — one managed profile's identity, from behind the access rule.
///
/// Reading it is an ACCESS: the server refuses when the rule does not
/// name the caller, and writes the read down when it does, so the person
/// sees who looked once they claim the profile. That is why this is a
/// call and not a field on the member row — the row carries only the
/// name a co-member legitimately sees.
///
/// #1561 — a refusal reads as refused; any other failure stays an error,
/// so no form opens blank on a dropped connection and saves the blanks.

@ProviderFor(managedIdentity)
final managedIdentityProvider = ManagedIdentityFamily._();

/// #915 — one managed profile's identity, from behind the access rule.
///
/// Reading it is an ACCESS: the server refuses when the rule does not
/// name the caller, and writes the read down when it does, so the person
/// sees who looked once they claim the profile. That is why this is a
/// call and not a field on the member row — the row carries only the
/// name a co-member legitimately sees.
///
/// #1561 — a refusal reads as refused; any other failure stays an error,
/// so no form opens blank on a dropped connection and saves the blanks.

final class ManagedIdentityProvider
    extends
        $FunctionalProvider<
          AsyncValue<ManagedIdentityRead>,
          ManagedIdentityRead,
          FutureOr<ManagedIdentityRead>
        >
    with
        $FutureModifier<ManagedIdentityRead>,
        $FutureProvider<ManagedIdentityRead> {
  /// #915 — one managed profile's identity, from behind the access rule.
  ///
  /// Reading it is an ACCESS: the server refuses when the rule does not
  /// name the caller, and writes the read down when it does, so the person
  /// sees who looked once they claim the profile. That is why this is a
  /// call and not a field on the member row — the row carries only the
  /// name a co-member legitimately sees.
  ///
  /// #1561 — a refusal reads as refused; any other failure stays an error,
  /// so no form opens blank on a dropped connection and saves the blanks.
  ManagedIdentityProvider._({
    required ManagedIdentityFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'managedIdentityProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$managedIdentityHash();

  @override
  String toString() {
    return r'managedIdentityProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ManagedIdentityRead> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ManagedIdentityRead> create(Ref ref) {
    final argument = this.argument as String;
    return managedIdentity(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ManagedIdentityProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$managedIdentityHash() => r'a5c00d0aca2d3fa4c3d5961eb7b155fc51c7414e';

/// #915 — one managed profile's identity, from behind the access rule.
///
/// Reading it is an ACCESS: the server refuses when the rule does not
/// name the caller, and writes the read down when it does, so the person
/// sees who looked once they claim the profile. That is why this is a
/// call and not a field on the member row — the row carries only the
/// name a co-member legitimately sees.
///
/// #1561 — a refusal reads as refused; any other failure stays an error,
/// so no form opens blank on a dropped connection and saves the blanks.

final class ManagedIdentityFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ManagedIdentityRead>, String> {
  ManagedIdentityFamily._()
    : super(
        retry: null,
        name: r'managedIdentityProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #915 — one managed profile's identity, from behind the access rule.
  ///
  /// Reading it is an ACCESS: the server refuses when the rule does not
  /// name the caller, and writes the read down when it does, so the person
  /// sees who looked once they claim the profile. That is why this is a
  /// call and not a field on the member row — the row carries only the
  /// name a co-member legitimately sees.
  ///
  /// #1561 — a refusal reads as refused; any other failure stays an error,
  /// so no form opens blank on a dropped connection and saves the blanks.

  ManagedIdentityProvider call(String memberId) =>
      ManagedIdentityProvider._(argument: memberId, from: this);

  @override
  String toString() => r'managedIdentityProvider';
}

/// #937 — whether the signed-in user operates the deployment.

@ProviderFor(isPlatformOwner)
final isPlatformOwnerProvider = IsPlatformOwnerProvider._();

/// #937 — whether the signed-in user operates the deployment.

final class IsPlatformOwnerProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// #937 — whether the signed-in user operates the deployment.
  IsPlatformOwnerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isPlatformOwnerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isPlatformOwnerHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return isPlatformOwner(ref);
  }
}

String _$isPlatformOwnerHash() => r'4df8df63bc163ded458557e8d9f0c02773f64cbb';

/// #937 — every workspace in the database; empty for anyone who is not
/// the platform owner (the RPC would refuse, so it is not even asked).

@ProviderFor(allWorkspaces)
final allWorkspacesProvider = AllWorkspacesProvider._();

/// #937 — every workspace in the database; empty for anyone who is not
/// the platform owner (the RPC would refuse, so it is not even asked).

final class AllWorkspacesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WorkspaceOverview>>,
          List<WorkspaceOverview>,
          FutureOr<List<WorkspaceOverview>>
        >
    with
        $FutureModifier<List<WorkspaceOverview>>,
        $FutureProvider<List<WorkspaceOverview>> {
  /// #937 — every workspace in the database; empty for anyone who is not
  /// the platform owner (the RPC would refuse, so it is not even asked).
  AllWorkspacesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allWorkspacesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allWorkspacesHash();

  @$internal
  @override
  $FutureProviderElement<List<WorkspaceOverview>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<WorkspaceOverview>> create(Ref ref) {
    return allWorkspaces(ref);
  }
}

String _$allWorkspacesHash() => r'6bdb2278e547e87792ad963c71990a99b6e83a1b';

/// #945 — the workspace's sites, default first.

@ProviderFor(sites)
final sitesProvider = SitesProvider._();

/// #945 — the workspace's sites, default first.

final class SitesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Site>>,
          List<Site>,
          FutureOr<List<Site>>
        >
    with $FutureModifier<List<Site>>, $FutureProvider<List<Site>> {
  /// #945 — the workspace's sites, default first.
  SitesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sitesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sitesHash();

  @$internal
  @override
  $FutureProviderElement<List<Site>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Site>> create(Ref ref) {
    return sites(ref);
  }
}

String _$sitesHash() => r'9ec2f563e2d13a4c811088f8286ba63cb41148a5';

/// #974 — the sites of one workspace the person belongs to, for the
/// profiles list (which spans every workspace, not only the active one).

@ProviderFor(sitesOf)
final sitesOfProvider = SitesOfFamily._();

/// #974 — the sites of one workspace the person belongs to, for the
/// profiles list (which spans every workspace, not only the active one).

final class SitesOfProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Site>>,
          List<Site>,
          FutureOr<List<Site>>
        >
    with $FutureModifier<List<Site>>, $FutureProvider<List<Site>> {
  /// #974 — the sites of one workspace the person belongs to, for the
  /// profiles list (which spans every workspace, not only the active one).
  SitesOfProvider._({
    required SitesOfFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'sitesOfProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sitesOfHash();

  @override
  String toString() {
    return r'sitesOfProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Site>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Site>> create(Ref ref) {
    final argument = this.argument as String;
    return sitesOf(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SitesOfProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sitesOfHash() => r'0b8ce05ad10af9d1a709455e3a8e13e5fc258af6';

/// #974 — the sites of one workspace the person belongs to, for the
/// profiles list (which spans every workspace, not only the active one).

final class SitesOfFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Site>>, String> {
  SitesOfFamily._()
    : super(
        retry: null,
        name: r'sitesOfProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #974 — the sites of one workspace the person belongs to, for the
  /// profiles list (which spans every workspace, not only the active one).

  SitesOfProvider call(String workspaceId) =>
      SitesOfProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'sitesOfProvider';
}

/// #1120 — every template the member may read. Invalidated by the
/// library screen after a save, a share or a delete.

@ProviderFor(workspaceTemplates)
final workspaceTemplatesProvider = WorkspaceTemplatesProvider._();

/// #1120 — every template the member may read. Invalidated by the
/// library screen after a save, a share or a delete.

final class WorkspaceTemplatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WorkspaceTemplate>>,
          List<WorkspaceTemplate>,
          FutureOr<List<WorkspaceTemplate>>
        >
    with
        $FutureModifier<List<WorkspaceTemplate>>,
        $FutureProvider<List<WorkspaceTemplate>> {
  /// #1120 — every template the member may read. Invalidated by the
  /// library screen after a save, a share or a delete.
  WorkspaceTemplatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceTemplatesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceTemplatesHash();

  @$internal
  @override
  $FutureProviderElement<List<WorkspaceTemplate>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<WorkspaceTemplate>> create(Ref ref) {
    return workspaceTemplates(ref);
  }
}

String _$workspaceTemplatesHash() =>
    r'a11de99e16f7949050568c1162d1f463a0e42836';
