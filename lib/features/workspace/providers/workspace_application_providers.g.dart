// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_application_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workspaceApplicationRepository)
final workspaceApplicationRepositoryProvider =
    WorkspaceApplicationRepositoryProvider._();

final class WorkspaceApplicationRepositoryProvider
    extends
        $FunctionalProvider<
          WorkspaceApplicationRepository,
          WorkspaceApplicationRepository,
          WorkspaceApplicationRepository
        >
    with $Provider<WorkspaceApplicationRepository> {
  WorkspaceApplicationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceApplicationRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceApplicationRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorkspaceApplicationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkspaceApplicationRepository create(Ref ref) {
    return workspaceApplicationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspaceApplicationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspaceApplicationRepository>(
        value,
      ),
    );
  }
}

String _$workspaceApplicationRepositoryHash() =>
    r'b7255825478e5af1e6f3fb9479968019ae53a83f';

@ProviderFor(applicationReplies)
final applicationRepliesProvider = ApplicationRepliesProvider._();

final class ApplicationRepliesProvider
    extends
        $FunctionalProvider<
          ApplicationReplies,
          ApplicationReplies,
          ApplicationReplies
        >
    with $Provider<ApplicationReplies> {
  ApplicationRepliesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'applicationRepliesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$applicationRepliesHash();

  @$internal
  @override
  $ProviderElement<ApplicationReplies> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ApplicationReplies create(Ref ref) {
    return applicationReplies(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ApplicationReplies value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ApplicationReplies>(value),
    );
  }
}

String _$applicationRepliesHash() =>
    r'654fcf6b1f4a8266dab09e7031e0e755871eddba';

@ProviderFor(workspaceApplications)
final workspaceApplicationsProvider = WorkspaceApplicationsFamily._();

final class WorkspaceApplicationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WorkspaceApplication>>,
          List<WorkspaceApplication>,
          FutureOr<List<WorkspaceApplication>>
        >
    with
        $FutureModifier<List<WorkspaceApplication>>,
        $FutureProvider<List<WorkspaceApplication>> {
  WorkspaceApplicationsProvider._({
    required WorkspaceApplicationsFamily super.from,
    required ApplicationCursor? super.argument,
  }) : super(
         retry: null,
         name: r'workspaceApplicationsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workspaceApplicationsHash();

  @override
  String toString() {
    return r'workspaceApplicationsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<WorkspaceApplication>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<WorkspaceApplication>> create(Ref ref) {
    final argument = this.argument as ApplicationCursor?;
    return workspaceApplications(ref, before: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceApplicationsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workspaceApplicationsHash() =>
    r'9c8930917b07a29d892b8d0d8b05ba08c2328207';

final class WorkspaceApplicationsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<WorkspaceApplication>>,
          ApplicationCursor?
        > {
  WorkspaceApplicationsFamily._()
    : super(
        retry: null,
        name: r'workspaceApplicationsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WorkspaceApplicationsProvider call({ApplicationCursor? before}) =>
      WorkspaceApplicationsProvider._(argument: before, from: this);

  @override
  String toString() => r'workspaceApplicationsProvider';
}

@ProviderFor(workspaceApplicationThread)
final workspaceApplicationThreadProvider = WorkspaceApplicationThreadFamily._();

final class WorkspaceApplicationThreadProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ApplicationMessage>>,
          List<ApplicationMessage>,
          FutureOr<List<ApplicationMessage>>
        >
    with
        $FutureModifier<List<ApplicationMessage>>,
        $FutureProvider<List<ApplicationMessage>> {
  WorkspaceApplicationThreadProvider._({
    required WorkspaceApplicationThreadFamily super.from,
    required (String, {ApplicationCursor? before}) super.argument,
  }) : super(
         retry: null,
         name: r'workspaceApplicationThreadProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workspaceApplicationThreadHash();

  @override
  String toString() {
    return r'workspaceApplicationThreadProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<ApplicationMessage>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ApplicationMessage>> create(Ref ref) {
    final argument = this.argument as (String, {ApplicationCursor? before});
    return workspaceApplicationThread(
      ref,
      argument.$1,
      before: argument.before,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceApplicationThreadProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workspaceApplicationThreadHash() =>
    r'84999fddc4c840a8b3bde3425559e4acd9c9bdc4';

final class WorkspaceApplicationThreadFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<ApplicationMessage>>,
          (String, {ApplicationCursor? before})
        > {
  WorkspaceApplicationThreadFamily._()
    : super(
        retry: null,
        name: r'workspaceApplicationThreadProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WorkspaceApplicationThreadProvider call(
    String id, {
    ApplicationCursor? before,
  }) => WorkspaceApplicationThreadProvider._(
    argument: (id, before: before),
    from: this,
  );

  @override
  String toString() => r'workspaceApplicationThreadProvider';
}
