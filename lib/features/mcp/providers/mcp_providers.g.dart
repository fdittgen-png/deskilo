// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(actionConfirmationRepository)
final actionConfirmationRepositoryProvider =
    ActionConfirmationRepositoryProvider._();

final class ActionConfirmationRepositoryProvider
    extends
        $FunctionalProvider<
          ActionConfirmationRepository,
          ActionConfirmationRepository,
          ActionConfirmationRepository
        >
    with $Provider<ActionConfirmationRepository> {
  ActionConfirmationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'actionConfirmationRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$actionConfirmationRepositoryHash();

  @$internal
  @override
  $ProviderElement<ActionConfirmationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ActionConfirmationRepository create(Ref ref) {
    return actionConfirmationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActionConfirmationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActionConfirmationRepository>(value),
    );
  }
}

String _$actionConfirmationRepositoryHash() =>
    r'a8a9d46d88e5ca5c391da2845f4a314d14a8a98d';

/// One confirmation, as the server answers it now.

@ProviderFor(actionConfirmation)
final actionConfirmationProvider = ActionConfirmationFamily._();

/// One confirmation, as the server answers it now.

final class ActionConfirmationProvider
    extends
        $FunctionalProvider<
          AsyncValue<ActionConfirmation>,
          ActionConfirmation,
          FutureOr<ActionConfirmation>
        >
    with
        $FutureModifier<ActionConfirmation>,
        $FutureProvider<ActionConfirmation> {
  /// One confirmation, as the server answers it now.
  ActionConfirmationProvider._({
    required ActionConfirmationFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'actionConfirmationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$actionConfirmationHash();

  @override
  String toString() {
    return r'actionConfirmationProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ActionConfirmation> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ActionConfirmation> create(Ref ref) {
    final argument = this.argument as String;
    return actionConfirmation(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ActionConfirmationProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$actionConfirmationHash() =>
    r'1446a08934cd8f33ef8aba6dcd0bf78271df3c01';

/// One confirmation, as the server answers it now.

final class ActionConfirmationFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ActionConfirmation>, String> {
  ActionConfirmationFamily._()
    : super(
        retry: null,
        name: r'actionConfirmationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One confirmation, as the server answers it now.

  ActionConfirmationProvider call(String id) =>
      ActionConfirmationProvider._(argument: id, from: this);

  @override
  String toString() => r'actionConfirmationProvider';
}

/// #1615 — the consent RPCs and Auth's OAuth consent API.

@ProviderFor(mcpConnectionRepository)
final mcpConnectionRepositoryProvider = McpConnectionRepositoryProvider._();

/// #1615 — the consent RPCs and Auth's OAuth consent API.

final class McpConnectionRepositoryProvider
    extends
        $FunctionalProvider<
          McpConnectionRepository,
          McpConnectionRepository,
          McpConnectionRepository
        >
    with $Provider<McpConnectionRepository> {
  /// #1615 — the consent RPCs and Auth's OAuth consent API.
  McpConnectionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mcpConnectionRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mcpConnectionRepositoryHash();

  @$internal
  @override
  $ProviderElement<McpConnectionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  McpConnectionRepository create(Ref ref) {
    return mcpConnectionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(McpConnectionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<McpConnectionRepository>(value),
    );
  }
}

String _$mcpConnectionRepositoryHash() =>
    r'd09c38c6df5c2b23be52f316be15892822dc8464';

@ProviderFor(connectAssistant)
final connectAssistantProvider = ConnectAssistantProvider._();

final class ConnectAssistantProvider
    extends
        $FunctionalProvider<
          ConnectAssistant,
          ConnectAssistant,
          ConnectAssistant
        >
    with $Provider<ConnectAssistant> {
  ConnectAssistantProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectAssistantProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectAssistantHash();

  @$internal
  @override
  $ProviderElement<ConnectAssistant> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ConnectAssistant create(Ref ref) {
    return connectAssistant(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConnectAssistant value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConnectAssistant>(value),
    );
  }
}

String _$connectAssistantHash() => r'9a3acc00aa1d8e8281eed7dd0b19a3a72dd39e53';

/// The pending request and what this person may offer, loaded together.

@ProviderFor(mcpConsent)
final mcpConsentProvider = McpConsentFamily._();

/// The pending request and what this person may offer, loaded together.

final class McpConsentProvider
    extends
        $FunctionalProvider<
          AsyncValue<({ConsentOptions options, AuthorizationRequest request})>,
          ({ConsentOptions options, AuthorizationRequest request}),
          FutureOr<({ConsentOptions options, AuthorizationRequest request})>
        >
    with
        $FutureModifier<
          ({ConsentOptions options, AuthorizationRequest request})
        >,
        $FutureProvider<
          ({ConsentOptions options, AuthorizationRequest request})
        > {
  /// The pending request and what this person may offer, loaded together.
  McpConsentProvider._({
    required McpConsentFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'mcpConsentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mcpConsentHash();

  @override
  String toString() {
    return r'mcpConsentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<
    ({ConsentOptions options, AuthorizationRequest request})
  >
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<({ConsentOptions options, AuthorizationRequest request})> create(
    Ref ref,
  ) {
    final argument = this.argument as String;
    return mcpConsent(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is McpConsentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mcpConsentHash() => r'8397e62fedec824d23a62a1c325914f14232563d';

/// The pending request and what this person may offer, loaded together.

final class McpConsentFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<({ConsentOptions options, AuthorizationRequest request})>,
          String
        > {
  McpConsentFamily._()
    : super(
        retry: null,
        name: r'mcpConsentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The pending request and what this person may offer, loaded together.

  McpConsentProvider call(String authorizationId) =>
      McpConsentProvider._(argument: authorizationId, from: this);

  @override
  String toString() => r'mcpConsentProvider';
}

/// The assistants this person connected to this database.

@ProviderFor(myMcpConnections)
final myMcpConnectionsProvider = MyMcpConnectionsProvider._();

/// The assistants this person connected to this database.

final class MyMcpConnectionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<McpConnectionInfo>>,
          List<McpConnectionInfo>,
          FutureOr<List<McpConnectionInfo>>
        >
    with
        $FutureModifier<List<McpConnectionInfo>>,
        $FutureProvider<List<McpConnectionInfo>> {
  /// The assistants this person connected to this database.
  MyMcpConnectionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myMcpConnectionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myMcpConnectionsHash();

  @$internal
  @override
  $FutureProviderElement<List<McpConnectionInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<McpConnectionInfo>> create(Ref ref) {
    return myMcpConnections(ref);
  }
}

String _$myMcpConnectionsHash() => r'eb966cd1b83a624398f00f3fd3364c08d2860a2b';
