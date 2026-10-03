// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connected_installation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(connectedInstallations)
final connectedInstallationsProvider = ConnectedInstallationsProvider._();

final class ConnectedInstallationsProvider
    extends
        $FunctionalProvider<
          ConnectedInstallations,
          ConnectedInstallations,
          ConnectedInstallations
        >
    with $Provider<ConnectedInstallations> {
  ConnectedInstallationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectedInstallationsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectedInstallationsHash();

  @$internal
  @override
  $ProviderElement<ConnectedInstallations> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConnectedInstallations create(Ref ref) {
    return connectedInstallations(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConnectedInstallations value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConnectedInstallations>(value),
    );
  }
}

String _$connectedInstallationsHash() =>
    r'2dfd1252b2f6fb7b0dccbcbfdccc5810cf975330';

@ProviderFor(connectedSources)
final connectedSourcesProvider = ConnectedSourcesProvider._();

final class ConnectedSourcesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ConnectedInstallation>>,
          List<ConnectedInstallation>,
          FutureOr<List<ConnectedInstallation>>
        >
    with
        $FutureModifier<List<ConnectedInstallation>>,
        $FutureProvider<List<ConnectedInstallation>> {
  ConnectedSourcesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectedSourcesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectedSourcesHash();

  @$internal
  @override
  $FutureProviderElement<List<ConnectedInstallation>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ConnectedInstallation>> create(Ref ref) {
    return connectedSources(ref);
  }
}

String _$connectedSourcesHash() => r'0bae75747ba3a36a393ef4ffe496c133483df4e9';

/// #1832 A — whether one connected target can be used now, and if not,
/// the typed reason; null means usable. Each target is asked on its own,
/// so one that is down leaves the others' rows usable.

@ProviderFor(connectionHealth)
final connectionHealthProvider = ConnectionHealthFamily._();

/// #1832 A — whether one connected target can be used now, and if not,
/// the typed reason; null means usable. Each target is asked on its own,
/// so one that is down leaves the others' rows usable.

final class ConnectionHealthProvider
    extends
        $FunctionalProvider<
          AsyncValue<ConnectionFailure?>,
          ConnectionFailure?,
          FutureOr<ConnectionFailure?>
        >
    with
        $FutureModifier<ConnectionFailure?>,
        $FutureProvider<ConnectionFailure?> {
  /// #1832 A — whether one connected target can be used now, and if not,
  /// the typed reason; null means usable. Each target is asked on its own,
  /// so one that is down leaves the others' rows usable.
  ConnectionHealthProvider._({
    required ConnectionHealthFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'connectionHealthProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$connectionHealthHash();

  @override
  String toString() {
    return r'connectionHealthProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ConnectionFailure?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ConnectionFailure?> create(Ref ref) {
    final argument = this.argument as String;
    return connectionHealth(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionHealthProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$connectionHealthHash() => r'1321207baf93dba078b6ca14d250475cd1773702';

/// #1832 A — whether one connected target can be used now, and if not,
/// the typed reason; null means usable. Each target is asked on its own,
/// so one that is down leaves the others' rows usable.

final class ConnectionHealthFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ConnectionFailure?>, String> {
  ConnectionHealthFamily._()
    : super(
        retry: null,
        name: r'connectionHealthProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #1832 A — whether one connected target can be used now, and if not,
  /// the typed reason; null means usable. Each target is asked on its own,
  /// so one that is down leaves the others' rows usable.

  ConnectionHealthProvider call(String source) =>
      ConnectionHealthProvider._(argument: source, from: this);

  @override
  String toString() => r'connectionHealthProvider';
}

/// #1834 — connecting another installation with the person's identity:
/// that server's own sign-in, its verified binding, the session kept in
/// the registry above. The one callback owner routes the browser return.

@ProviderFor(identityConnector)
final identityConnectorProvider = IdentityConnectorProvider._();

/// #1834 — connecting another installation with the person's identity:
/// that server's own sign-in, its verified binding, the session kept in
/// the registry above. The one callback owner routes the browser return.

final class IdentityConnectorProvider
    extends
        $FunctionalProvider<
          IdentityConnector,
          IdentityConnector,
          IdentityConnector
        >
    with $Provider<IdentityConnector> {
  /// #1834 — connecting another installation with the person's identity:
  /// that server's own sign-in, its verified binding, the session kept in
  /// the registry above. The one callback owner routes the browser return.
  IdentityConnectorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'identityConnectorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$identityConnectorHash();

  @$internal
  @override
  $ProviderElement<IdentityConnector> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IdentityConnector create(Ref ref) {
    return identityConnector(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IdentityConnector value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IdentityConnector>(value),
    );
  }
}

String _$identityConnectorHash() => r'5164465c021db49e8d8098c78f931db0679a0605';
