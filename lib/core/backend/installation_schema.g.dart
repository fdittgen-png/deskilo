// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installation_schema.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(installationSchemaSource)
final installationSchemaSourceProvider = InstallationSchemaSourceProvider._();

final class InstallationSchemaSourceProvider
    extends
        $FunctionalProvider<
          InstallationSchemaSource,
          InstallationSchemaSource,
          InstallationSchemaSource
        >
    with $Provider<InstallationSchemaSource> {
  InstallationSchemaSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installationSchemaSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installationSchemaSourceHash();

  @$internal
  @override
  $ProviderElement<InstallationSchemaSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InstallationSchemaSource create(Ref ref) {
    return installationSchemaSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InstallationSchemaSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InstallationSchemaSource>(value),
    );
  }
}

String _$installationSchemaSourceHash() =>
    r'2c8aec7afc763f8367705cc404f39842e913f122';

@ProviderFor(installationSchemaMemory)
final installationSchemaMemoryProvider = InstallationSchemaMemoryProvider._();

final class InstallationSchemaMemoryProvider
    extends
        $FunctionalProvider<
          InstallationSchemaMemory,
          InstallationSchemaMemory,
          InstallationSchemaMemory
        >
    with $Provider<InstallationSchemaMemory> {
  InstallationSchemaMemoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installationSchemaMemoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installationSchemaMemoryHash();

  @$internal
  @override
  $ProviderElement<InstallationSchemaMemory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InstallationSchemaMemory create(Ref ref) {
    return installationSchemaMemory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InstallationSchemaMemory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InstallationSchemaMemory>(value),
    );
  }
}

String _$installationSchemaMemoryHash() =>
    r'ecb0b635e15040e5dd1e74258c6a1c7ee6a0e0d2';

/// The schema of the installation that hosts [workspaceId].
///
/// - A successful answer decides and is remembered under the installation's
///   id; a host that answers "no marker" is an answer.
/// - A failed read keeps what THAT installation last answered, or is
///   unknown, which withholds nothing.
/// - Asked again each time the app returns to the foreground (an event,
///   never a timer).

@ProviderFor(workspaceSchema)
final workspaceSchemaProvider = WorkspaceSchemaFamily._();

/// The schema of the installation that hosts [workspaceId].
///
/// - A successful answer decides and is remembered under the installation's
///   id; a host that answers "no marker" is an answer.
/// - A failed read keeps what THAT installation last answered, or is
///   unknown, which withholds nothing.
/// - Asked again each time the app returns to the foreground (an event,
///   never a timer).

final class WorkspaceSchemaProvider
    extends
        $FunctionalProvider<
          AsyncValue<InstallationSchema>,
          InstallationSchema,
          FutureOr<InstallationSchema>
        >
    with
        $FutureModifier<InstallationSchema>,
        $FutureProvider<InstallationSchema> {
  /// The schema of the installation that hosts [workspaceId].
  ///
  /// - A successful answer decides and is remembered under the installation's
  ///   id; a host that answers "no marker" is an answer.
  /// - A failed read keeps what THAT installation last answered, or is
  ///   unknown, which withholds nothing.
  /// - Asked again each time the app returns to the foreground (an event,
  ///   never a timer).
  WorkspaceSchemaProvider._({
    required WorkspaceSchemaFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workspaceSchemaProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workspaceSchemaHash();

  @override
  String toString() {
    return r'workspaceSchemaProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<InstallationSchema> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InstallationSchema> create(Ref ref) {
    final argument = this.argument as String;
    return workspaceSchema(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceSchemaProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workspaceSchemaHash() => r'e4e11fbe5921b87f228c3465260df95e323460a8';

/// The schema of the installation that hosts [workspaceId].
///
/// - A successful answer decides and is remembered under the installation's
///   id; a host that answers "no marker" is an answer.
/// - A failed read keeps what THAT installation last answered, or is
///   unknown, which withholds nothing.
/// - Asked again each time the app returns to the foreground (an event,
///   never a timer).

final class WorkspaceSchemaFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<InstallationSchema>, String> {
  WorkspaceSchemaFamily._()
    : super(
        retry: null,
        name: r'workspaceSchemaProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The schema of the installation that hosts [workspaceId].
  ///
  /// - A successful answer decides and is remembered under the installation's
  ///   id; a host that answers "no marker" is an answer.
  /// - A failed read keeps what THAT installation last answered, or is
  ///   unknown, which withholds nothing.
  /// - Asked again each time the app returns to the foreground (an event,
  ///   never a timer).

  WorkspaceSchemaProvider call(String workspaceId) =>
      WorkspaceSchemaProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'workspaceSchemaProvider';
}
