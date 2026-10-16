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

/// The context of the selected workspace, captured whole: person, verified
/// target, local account, both epochs, settings and time zone. Null while
/// nobody is signed in or no workspace is selected.

@ProviderFor(workspaceContext)
final workspaceContextProvider = WorkspaceContextProvider._();

/// The context of the selected workspace, captured whole: person, verified
/// target, local account, both epochs, settings and time zone. Null while
/// nobody is signed in or no workspace is selected.

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
  /// target, local account, both epochs, settings and time zone. Null while
  /// nobody is signed in or no workspace is selected.
  WorkspaceContextProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
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

String _$workspaceContextHash() => r'ad885bd3716d4d96960045defdc542ed5226f76e';
