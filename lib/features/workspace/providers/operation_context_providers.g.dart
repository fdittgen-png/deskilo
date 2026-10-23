// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operation_context_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Who is signed in at the personal home, or null when nobody is.

@ProviderFor(personalContext)
final personalContextProvider = PersonalContextProvider._();

/// Who is signed in at the personal home, or null when nobody is.

final class PersonalContextProvider
    extends
        $FunctionalProvider<
          AsyncValue<PersonalContext?>,
          PersonalContext?,
          FutureOr<PersonalContext?>
        >
    with $FutureModifier<PersonalContext?>, $FutureProvider<PersonalContext?> {
  /// Who is signed in at the personal home, or null when nobody is.
  PersonalContextProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalContextProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalContextHash();

  @$internal
  @override
  $FutureProviderElement<PersonalContext?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PersonalContext?> create(Ref ref) {
    return personalContext(ref);
  }
}

String _$personalContextHash() => r'a553c3de390357ee6d095aad96353e6bd4aad92c';

@ProviderFor(workspaceCalendarReader)
final workspaceCalendarReaderProvider = WorkspaceCalendarReaderProvider._();

final class WorkspaceCalendarReaderProvider
    extends
        $FunctionalProvider<
          WorkspaceCalendarReader,
          WorkspaceCalendarReader,
          WorkspaceCalendarReader
        >
    with $Provider<WorkspaceCalendarReader> {
  WorkspaceCalendarReaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceCalendarReaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceCalendarReaderHash();

  @$internal
  @override
  $ProviderElement<WorkspaceCalendarReader> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkspaceCalendarReader create(Ref ref) {
    return workspaceCalendarReader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspaceCalendarReader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspaceCalendarReader>(value),
    );
  }
}

String _$workspaceCalendarReaderHash() =>
    r'6ab441740d7ccf37f151d4622344af53f446736b';

/// The context of the selected workspace, captured whole: person, verified
/// target, local account, both epochs, settings, calendar and tax reference.
/// Null while nobody is signed in or no workspace is selected.
///
/// #2561 L4 -- the calendar and the tax reference are read through the
/// resolved host's own client, after the target is fixed: a later selection
/// rebuilds the context, and the answer of the earlier one is dropped with
/// it. An edit of the calendar invalidates this provider.

@ProviderFor(workspaceContext)
final workspaceContextProvider = WorkspaceContextProvider._();

/// The context of the selected workspace, captured whole: person, verified
/// target, local account, both epochs, settings, calendar and tax reference.
/// Null while nobody is signed in or no workspace is selected.
///
/// #2561 L4 -- the calendar and the tax reference are read through the
/// resolved host's own client, after the target is fixed: a later selection
/// rebuilds the context, and the answer of the earlier one is dropped with
/// it. An edit of the calendar invalidates this provider.

final class WorkspaceContextProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkspaceContext?>,
          WorkspaceContext?,
          FutureOr<WorkspaceContext?>
        >
    with
        $FutureModifier<WorkspaceContext?>,
        $FutureProvider<WorkspaceContext?> {
  /// The context of the selected workspace, captured whole: person, verified
  /// target, local account, both epochs, settings, calendar and tax reference.
  /// Null while nobody is signed in or no workspace is selected.
  ///
  /// #2561 L4 -- the calendar and the tax reference are read through the
  /// resolved host's own client, after the target is fixed: a later selection
  /// rebuilds the context, and the answer of the earlier one is dropped with
  /// it. An edit of the calendar invalidates this provider.
  WorkspaceContextProvider._()
    : super(
        from: null,
        argument: null,
        retry: _workspaceContextRetry,
        name: r'workspaceContextProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceContextHash();

  @$internal
  @override
  $FutureProviderElement<WorkspaceContext?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<WorkspaceContext?> create(Ref ref) {
    return workspaceContext(ref);
  }
}

String _$workspaceContextHash() => r'8e2d468d5f131c66b6fe99f574971d19f66de38f';

/// #2561 L4 -- the captured context as a synchronous reader may use it NOW:
/// null while it is being captured for a new selection (the previous
/// workspace's value is not shown under the next one), on a failure, and
/// while there is none. A refresh of the same selection keeps it.

@ProviderFor(readyWorkspaceContext)
final readyWorkspaceContextProvider = ReadyWorkspaceContextProvider._();

/// #2561 L4 -- the captured context as a synchronous reader may use it NOW:
/// null while it is being captured for a new selection (the previous
/// workspace's value is not shown under the next one), on a failure, and
/// while there is none. A refresh of the same selection keeps it.

final class ReadyWorkspaceContextProvider
    extends
        $FunctionalProvider<
          WorkspaceContext?,
          WorkspaceContext?,
          WorkspaceContext?
        >
    with $Provider<WorkspaceContext?> {
  /// #2561 L4 -- the captured context as a synchronous reader may use it NOW:
  /// null while it is being captured for a new selection (the previous
  /// workspace's value is not shown under the next one), on a failure, and
  /// while there is none. A refresh of the same selection keeps it.
  ReadyWorkspaceContextProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readyWorkspaceContextProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readyWorkspaceContextHash();

  @$internal
  @override
  $ProviderElement<WorkspaceContext?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkspaceContext? create(Ref ref) {
    return readyWorkspaceContext(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspaceContext? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspaceContext?>(value),
    );
  }
}

String _$readyWorkspaceContextHash() =>
    r'9957630ad1024ab9d8e987327b76a4306c19a2a5';

/// #2564 O1 -- the client the selected workspace's operations run on: the
/// verified host client of the captured [WorkspaceContext]'s installation.
/// Dependents rebuild only when that installation changes. Until a context exists (signed out, no workspace
/// selected, still resolving) it is the root client -- the combined
/// deployment's one installation, where the two are the same object; a split
/// deployment's resolver (#2562) never yields the root client for a W target.

@ProviderFor(selectedWorkspaceClient)
final selectedWorkspaceClientProvider = SelectedWorkspaceClientProvider._();

/// #2564 O1 -- the client the selected workspace's operations run on: the
/// verified host client of the captured [WorkspaceContext]'s installation.
/// Dependents rebuild only when that installation changes. Until a context exists (signed out, no workspace
/// selected, still resolving) it is the root client -- the combined
/// deployment's one installation, where the two are the same object; a split
/// deployment's resolver (#2562) never yields the root client for a W target.

final class SelectedWorkspaceClientProvider
    extends $FunctionalProvider<SupabaseClient, SupabaseClient, SupabaseClient>
    with $Provider<SupabaseClient> {
  /// #2564 O1 -- the client the selected workspace's operations run on: the
  /// verified host client of the captured [WorkspaceContext]'s installation.
  /// Dependents rebuild only when that installation changes. Until a context exists (signed out, no workspace
  /// selected, still resolving) it is the root client -- the combined
  /// deployment's one installation, where the two are the same object; a split
  /// deployment's resolver (#2562) never yields the root client for a W target.
  SelectedWorkspaceClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedWorkspaceClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedWorkspaceClientHash();

  @$internal
  @override
  $ProviderElement<SupabaseClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SupabaseClient create(Ref ref) {
    return selectedWorkspaceClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupabaseClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SupabaseClient>(value),
    );
  }
}

String _$selectedWorkspaceClientHash() =>
    r'e45e0c85d814573b32e57d8730e5c9c83371a865';
