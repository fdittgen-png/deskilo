// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'context_client_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(contextClients)
final contextClientsProvider = ContextClientsProvider._();

final class ContextClientsProvider
    extends $FunctionalProvider<ContextClients, ContextClients, ContextClients>
    with $Provider<ContextClients> {
  ContextClientsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contextClientsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contextClientsHash();

  @$internal
  @override
  $ProviderElement<ContextClients> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ContextClients create(Ref ref) {
    return contextClients(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContextClients value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContextClients>(value),
    );
  }
}

String _$contextClientsHash() => r'ba9ad6a17c015e5f4ec01555c0db6f1d5f1eb836';

/// The long-lived client of the personal home (P).

@ProviderFor(personalClient)
final personalClientProvider = PersonalClientProvider._();

/// The long-lived client of the personal home (P).

final class PersonalClientProvider
    extends $FunctionalProvider<SupabaseClient, SupabaseClient, SupabaseClient>
    with $Provider<SupabaseClient> {
  /// The long-lived client of the personal home (P).
  PersonalClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalClientHash();

  @$internal
  @override
  $ProviderElement<SupabaseClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SupabaseClient create(Ref ref) {
    return personalClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupabaseClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SupabaseClient>(value),
    );
  }
}

String _$personalClientHash() => r'683462ebc4cc10eaf71d6f76afbd880313462401';

/// The client of the verified workspace installation [installationId].
/// Throws [UnverifiedInstallation] for an id no context has verified.

@ProviderFor(workspaceClient)
final workspaceClientProvider = WorkspaceClientFamily._();

/// The client of the verified workspace installation [installationId].
/// Throws [UnverifiedInstallation] for an id no context has verified.

final class WorkspaceClientProvider
    extends $FunctionalProvider<SupabaseClient, SupabaseClient, SupabaseClient>
    with $Provider<SupabaseClient> {
  /// The client of the verified workspace installation [installationId].
  /// Throws [UnverifiedInstallation] for an id no context has verified.
  WorkspaceClientProvider._({
    required WorkspaceClientFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workspaceClientProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workspaceClientHash();

  @override
  String toString() {
    return r'workspaceClientProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<SupabaseClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SupabaseClient create(Ref ref) {
    final argument = this.argument as String;
    return workspaceClient(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupabaseClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SupabaseClient>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceClientProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workspaceClientHash() => r'62e56615a8bd2abd30173c0567fdce0fcc91fb39';

/// The client of the verified workspace installation [installationId].
/// Throws [UnverifiedInstallation] for an id no context has verified.

final class WorkspaceClientFamily extends $Family
    with $FunctionalFamilyOverride<SupabaseClient, String> {
  WorkspaceClientFamily._()
    : super(
        retry: null,
        name: r'workspaceClientProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The client of the verified workspace installation [installationId].
  /// Throws [UnverifiedInstallation] for an id no context has verified.

  WorkspaceClientProvider call(String installationId) =>
      WorkspaceClientProvider._(argument: installationId, from: this);

  @override
  String toString() => r'workspaceClientProvider';
}

@ProviderFor(installationIdReader)
final installationIdReaderProvider = InstallationIdReaderProvider._();

final class InstallationIdReaderProvider
    extends
        $FunctionalProvider<
          InstallationIdReader,
          InstallationIdReader,
          InstallationIdReader
        >
    with $Provider<InstallationIdReader> {
  InstallationIdReaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installationIdReaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installationIdReaderHash();

  @$internal
  @override
  $ProviderElement<InstallationIdReader> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InstallationIdReader create(Ref ref) {
    return installationIdReader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InstallationIdReader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InstallationIdReader>(value),
    );
  }
}

String _$installationIdReaderHash() =>
    r'd8d48f09f2d1cf903d09ce3286fd897ab3a4ff91';

/// Finds the host of a workspace; the combined deployment's is the
/// installation the app is signed in to.

@ProviderFor(workspaceHostResolver)
final workspaceHostResolverProvider = WorkspaceHostResolverProvider._();

/// Finds the host of a workspace; the combined deployment's is the
/// installation the app is signed in to.

final class WorkspaceHostResolverProvider
    extends
        $FunctionalProvider<
          WorkspaceHostResolver,
          WorkspaceHostResolver,
          WorkspaceHostResolver
        >
    with $Provider<WorkspaceHostResolver> {
  /// Finds the host of a workspace; the combined deployment's is the
  /// installation the app is signed in to.
  WorkspaceHostResolverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceHostResolverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceHostResolverHash();

  @$internal
  @override
  $ProviderElement<WorkspaceHostResolver> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkspaceHostResolver create(Ref ref) {
    return workspaceHostResolver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspaceHostResolver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspaceHostResolver>(value),
    );
  }
}

String _$workspaceHostResolverHash() =>
    r'241caa89dea353f71c86a026cdc2840a45fb9a6e';

@ProviderFor(epochLedger)
final epochLedgerProvider = EpochLedgerProvider._();

final class EpochLedgerProvider
    extends $FunctionalProvider<EpochLedger, EpochLedger, EpochLedger>
    with $Provider<EpochLedger> {
  EpochLedgerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'epochLedgerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$epochLedgerHash();

  @$internal
  @override
  $ProviderElement<EpochLedger> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EpochLedger create(Ref ref) {
    return epochLedger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EpochLedger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EpochLedger>(value),
    );
  }
}

String _$epochLedgerHash() => r'5d415ff932a5d453bdfcdefe4246e4f49ba81e2b';
