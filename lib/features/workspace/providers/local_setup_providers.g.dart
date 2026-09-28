// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_setup_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #1656 group 5 — the local setup a template needs and a space lacks.

@ProviderFor(localSetupRepository)
final localSetupRepositoryProvider = LocalSetupRepositoryProvider._();

/// #1656 group 5 — the local setup a template needs and a space lacks.

final class LocalSetupRepositoryProvider
    extends
        $FunctionalProvider<
          LocalSetupRepository,
          LocalSetupRepository,
          LocalSetupRepository
        >
    with $Provider<LocalSetupRepository> {
  /// #1656 group 5 — the local setup a template needs and a space lacks.
  LocalSetupRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localSetupRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localSetupRepositoryHash();

  @$internal
  @override
  $ProviderElement<LocalSetupRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LocalSetupRepository create(Ref ref) {
    return localSetupRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalSetupRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalSetupRepository>(value),
    );
  }
}

String _$localSetupRepositoryHash() =>
    r'9c50d47d975baf0b6b8bfd1a262e44cb225c8685';

@ProviderFor(templateLocalNeeds)
final templateLocalNeedsProvider = TemplateLocalNeedsFamily._();

final class TemplateLocalNeedsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LocalSlot>>,
          List<LocalSlot>,
          FutureOr<List<LocalSlot>>
        >
    with $FutureModifier<List<LocalSlot>>, $FutureProvider<List<LocalSlot>> {
  TemplateLocalNeedsProvider._({
    required TemplateLocalNeedsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'templateLocalNeedsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$templateLocalNeedsHash();

  @override
  String toString() {
    return r'templateLocalNeedsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<LocalSlot>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LocalSlot>> create(Ref ref) {
    final argument = this.argument as String;
    return templateLocalNeeds(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TemplateLocalNeedsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$templateLocalNeedsHash() =>
    r'0407151e3cc2de09610ee0df2883324bbfd5e930';

final class TemplateLocalNeedsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<LocalSlot>>, String> {
  TemplateLocalNeedsFamily._()
    : super(
        retry: null,
        name: r'templateLocalNeedsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TemplateLocalNeedsProvider call(String templateId) =>
      TemplateLocalNeedsProvider._(argument: templateId, from: this);

  @override
  String toString() => r'templateLocalNeedsProvider';
}

/// Only the slots still to fill, required first.

@ProviderFor(workspaceLocalGaps)
final workspaceLocalGapsProvider = WorkspaceLocalGapsFamily._();

/// Only the slots still to fill, required first.

final class WorkspaceLocalGapsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LocalSlot>>,
          List<LocalSlot>,
          FutureOr<List<LocalSlot>>
        >
    with $FutureModifier<List<LocalSlot>>, $FutureProvider<List<LocalSlot>> {
  /// Only the slots still to fill, required first.
  WorkspaceLocalGapsProvider._({
    required WorkspaceLocalGapsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workspaceLocalGapsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workspaceLocalGapsHash();

  @override
  String toString() {
    return r'workspaceLocalGapsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<LocalSlot>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LocalSlot>> create(Ref ref) {
    final argument = this.argument as String;
    return workspaceLocalGaps(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceLocalGapsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workspaceLocalGapsHash() =>
    r'551a88568c3af2d6e9da7a7b4e4c42263c81dc27';

/// Only the slots still to fill, required first.

final class WorkspaceLocalGapsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<LocalSlot>>, String> {
  WorkspaceLocalGapsFamily._()
    : super(
        retry: null,
        name: r'workspaceLocalGapsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Only the slots still to fill, required first.

  WorkspaceLocalGapsProvider call(String workspaceId) =>
      WorkspaceLocalGapsProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'workspaceLocalGapsProvider';
}

/// #1658 — every local slot the space's switched-on features need,
/// filled or not: what a space applying its template will need too.

@ProviderFor(workspaceLocalSlots)
final workspaceLocalSlotsProvider = WorkspaceLocalSlotsFamily._();

/// #1658 — every local slot the space's switched-on features need,
/// filled or not: what a space applying its template will need too.

final class WorkspaceLocalSlotsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LocalSlot>>,
          List<LocalSlot>,
          FutureOr<List<LocalSlot>>
        >
    with $FutureModifier<List<LocalSlot>>, $FutureProvider<List<LocalSlot>> {
  /// #1658 — every local slot the space's switched-on features need,
  /// filled or not: what a space applying its template will need too.
  WorkspaceLocalSlotsProvider._({
    required WorkspaceLocalSlotsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workspaceLocalSlotsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workspaceLocalSlotsHash();

  @override
  String toString() {
    return r'workspaceLocalSlotsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<LocalSlot>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LocalSlot>> create(Ref ref) {
    final argument = this.argument as String;
    return workspaceLocalSlots(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceLocalSlotsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workspaceLocalSlotsHash() =>
    r'e31ffae8939ee08a5e60516e93c41fd31767cafa';

/// #1658 — every local slot the space's switched-on features need,
/// filled or not: what a space applying its template will need too.

final class WorkspaceLocalSlotsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<LocalSlot>>, String> {
  WorkspaceLocalSlotsFamily._()
    : super(
        retry: null,
        name: r'workspaceLocalSlotsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #1658 — every local slot the space's switched-on features need,
  /// filled or not: what a space applying its template will need too.

  WorkspaceLocalSlotsProvider call(String workspaceId) =>
      WorkspaceLocalSlotsProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'workspaceLocalSlotsProvider';
}

/// #1636 — every setup section of the space, in the server's order.

@ProviderFor(workspaceReadiness)
final workspaceReadinessProvider = WorkspaceReadinessFamily._();

/// #1636 — every setup section of the space, in the server's order.

final class WorkspaceReadinessProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ReadinessSection>>,
          List<ReadinessSection>,
          FutureOr<List<ReadinessSection>>
        >
    with
        $FutureModifier<List<ReadinessSection>>,
        $FutureProvider<List<ReadinessSection>> {
  /// #1636 — every setup section of the space, in the server's order.
  WorkspaceReadinessProvider._({
    required WorkspaceReadinessFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workspaceReadinessProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workspaceReadinessHash();

  @override
  String toString() {
    return r'workspaceReadinessProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ReadinessSection>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ReadinessSection>> create(Ref ref) {
    final argument = this.argument as String;
    return workspaceReadiness(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceReadinessProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workspaceReadinessHash() =>
    r'12643350eb4294773994fa82357d9d77cf5f078b';

/// #1636 — every setup section of the space, in the server's order.

final class WorkspaceReadinessFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ReadinessSection>>, String> {
  WorkspaceReadinessFamily._()
    : super(
        retry: null,
        name: r'workspaceReadinessProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #1636 — every setup section of the space, in the server's order.

  WorkspaceReadinessProvider call(String workspaceId) =>
      WorkspaceReadinessProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'workspaceReadinessProvider';
}
