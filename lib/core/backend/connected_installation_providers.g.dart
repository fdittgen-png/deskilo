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
