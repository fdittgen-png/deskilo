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

/// #1625 — the active backend's own repositories, as one target bundle.

@ProviderFor(activeMcpRepositories)
final activeMcpRepositoriesProvider = ActiveMcpRepositoriesProvider._();

/// #1625 — the active backend's own repositories, as one target bundle.

final class ActiveMcpRepositoriesProvider
    extends
        $FunctionalProvider<McpRepositories, McpRepositories, McpRepositories>
    with $Provider<McpRepositories> {
  /// #1625 — the active backend's own repositories, as one target bundle.
  ActiveMcpRepositoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeMcpRepositoriesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeMcpRepositoriesHash();

  @$internal
  @override
  $ProviderElement<McpRepositories> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  McpRepositories create(Ref ref) {
    return activeMcpRepositories(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(McpRepositories value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<McpRepositories>(value),
    );
  }
}

String _$activeMcpRepositoriesHash() =>
    r'171b4a9ab637a313b1c4b1f9eb9513df6675f493';

/// #1625 — one native client per verified installation + issuer + account
/// + purpose. The active backend borrows the app's session; a connected
/// installation runs through its own isolated record. A sign-in change
/// retires every client, with one outcome per target.

@ProviderFor(mcpClientRegistry)
final mcpClientRegistryProvider = McpClientRegistryProvider._();

/// #1625 — one native client per verified installation + issuer + account
/// + purpose. The active backend borrows the app's session; a connected
/// installation runs through its own isolated record. A sign-in change
/// retires every client, with one outcome per target.

final class McpClientRegistryProvider
    extends
        $FunctionalProvider<
          McpClientRegistry,
          McpClientRegistry,
          McpClientRegistry
        >
    with $Provider<McpClientRegistry> {
  /// #1625 — one native client per verified installation + issuer + account
  /// + purpose. The active backend borrows the app's session; a connected
  /// installation runs through its own isolated record. A sign-in change
  /// retires every client, with one outcome per target.
  McpClientRegistryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mcpClientRegistryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mcpClientRegistryHash();

  @$internal
  @override
  $ProviderElement<McpClientRegistry> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  McpClientRegistry create(Ref ref) {
    return mcpClientRegistry(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(McpClientRegistry value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<McpClientRegistry>(value),
    );
  }
}

String _$mcpClientRegistryHash() => r'5325e89d66a67b45d016ebbe14b48b018058605d';

@ProviderFor(mcpCommands)
final mcpCommandsProvider = McpCommandsProvider._();

final class McpCommandsProvider
    extends $FunctionalProvider<McpCommands, McpCommands, McpCommands>
    with $Provider<McpCommands> {
  McpCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mcpCommandsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mcpCommandsHash();

  @$internal
  @override
  $ProviderElement<McpCommands> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  McpCommands create(Ref ref) {
    return mcpCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(McpCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<McpCommands>(value),
    );
  }
}

String _$mcpCommandsHash() => r'a277b2b84ce6b90ba91763d6233cec4e4927aaf8';

/// #1625 — the active backend as a verified target: the installation id
/// its own server answers for the signed-in account. Registered in the
/// registry before anything is asked of it.

@ProviderFor(activeMcpTarget)
final activeMcpTargetProvider = ActiveMcpTargetProvider._();

/// #1625 — the active backend as a verified target: the installation id
/// its own server answers for the signed-in account. Registered in the
/// registry before anything is asked of it.

final class ActiveMcpTargetProvider
    extends
        $FunctionalProvider<
          AsyncValue<VerifiedMcpTarget>,
          VerifiedMcpTarget,
          FutureOr<VerifiedMcpTarget>
        >
    with
        $FutureModifier<VerifiedMcpTarget>,
        $FutureProvider<VerifiedMcpTarget> {
  /// #1625 — the active backend as a verified target: the installation id
  /// its own server answers for the signed-in account. Registered in the
  /// registry before anything is asked of it.
  ActiveMcpTargetProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeMcpTargetProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeMcpTargetHash();

  @$internal
  @override
  $FutureProviderElement<VerifiedMcpTarget> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<VerifiedMcpTarget> create(Ref ref) {
    return activeMcpTarget(ref);
  }
}

String _$activeMcpTargetHash() => r'111e813975fe7c63466273871c954218b221b4de';

/// One confirmation, as the server answers it now.

@ProviderFor(confirmationAnswers)
final confirmationAnswersProvider = ConfirmationAnswersProvider._();

/// One confirmation, as the server answers it now.

final class ConfirmationAnswersProvider
    extends
        $FunctionalProvider<
          ConfirmationAnswers,
          ConfirmationAnswers,
          ConfirmationAnswers
        >
    with $Provider<ConfirmationAnswers> {
  /// One confirmation, as the server answers it now.
  ConfirmationAnswersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'confirmationAnswersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$confirmationAnswersHash();

  @$internal
  @override
  $ProviderElement<ConfirmationAnswers> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConfirmationAnswers create(Ref ref) {
    return confirmationAnswers(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConfirmationAnswers value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConfirmationAnswers>(value),
    );
  }
}

String _$confirmationAnswersHash() =>
    r'7c4e8ac50effea2d2b70aa7c550c90d7ed5f574a';

/// #1625 — read through the active target's confirmation client; an
/// answer for another confirmation is refused, not shown, and one that
/// arrives after a switch or sign-out is discarded.

@ProviderFor(actionConfirmation)
final actionConfirmationProvider = ActionConfirmationFamily._();

/// #1625 — read through the active target's confirmation client; an
/// answer for another confirmation is refused, not shown, and one that
/// arrives after a switch or sign-out is discarded.

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
  /// #1625 — read through the active target's confirmation client; an
  /// answer for another confirmation is refused, not shown, and one that
  /// arrives after a switch or sign-out is discarded.
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
    r'6e33c5a54810ac2dbf1a06a97accea7c9e0f4de2';

/// #1625 — read through the active target's confirmation client; an
/// answer for another confirmation is refused, not shown, and one that
/// arrives after a switch or sign-out is discarded.

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

  /// #1625 — read through the active target's confirmation client; an
  /// answer for another confirmation is refused, not shown, and one that
  /// arrives after a switch or sign-out is discarded.

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

String _$connectAssistantHash() => r'9b131ce9d1d178d657b3dc9381bdd4a8e9fc7443';

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

String _$myMcpConnectionsHash() => r'd437b0beba6804db52282f00cbe5c46573d708de';

/// #1626/#1627 — owner policy and database eligibility review.

@ProviderFor(mcpAdminRepository)
final mcpAdminRepositoryProvider = McpAdminRepositoryProvider._();

/// #1626/#1627 — owner policy and database eligibility review.

final class McpAdminRepositoryProvider
    extends
        $FunctionalProvider<
          McpAdminRepository,
          McpAdminRepository,
          McpAdminRepository
        >
    with $Provider<McpAdminRepository> {
  /// #1626/#1627 — owner policy and database eligibility review.
  McpAdminRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mcpAdminRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mcpAdminRepositoryHash();

  @$internal
  @override
  $ProviderElement<McpAdminRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  McpAdminRepository create(Ref ref) {
    return mcpAdminRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(McpAdminRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<McpAdminRepository>(value),
    );
  }
}

String _$mcpAdminRepositoryHash() =>
    r'd78751f105599de23ce6bd057e3a900468df1ba5';

/// The owner's policy for one workspace, as the server holds it now.
/// #1625 — keyed by installation, account and workspace; an answer for
/// another workspace is refused, and one that arrives after the context
/// was switched, signed out of or revoked is discarded.

@ProviderFor(mcpPolicy)
final mcpPolicyProvider = McpPolicyFamily._();

/// The owner's policy for one workspace, as the server holds it now.
/// #1625 — keyed by installation, account and workspace; an answer for
/// another workspace is refused, and one that arrives after the context
/// was switched, signed out of or revoked is discarded.

final class McpPolicyProvider
    extends
        $FunctionalProvider<
          AsyncValue<McpPolicy>,
          McpPolicy,
          FutureOr<McpPolicy>
        >
    with $FutureModifier<McpPolicy>, $FutureProvider<McpPolicy> {
  /// The owner's policy for one workspace, as the server holds it now.
  /// #1625 — keyed by installation, account and workspace; an answer for
  /// another workspace is refused, and one that arrives after the context
  /// was switched, signed out of or revoked is discarded.
  McpPolicyProvider._({
    required McpPolicyFamily super.from,
    required McpContextRef super.argument,
  }) : super(
         retry: null,
         name: r'mcpPolicyProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mcpPolicyHash();

  @override
  String toString() {
    return r'mcpPolicyProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<McpPolicy> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<McpPolicy> create(Ref ref) {
    final argument = this.argument as McpContextRef;
    return mcpPolicy(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is McpPolicyProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mcpPolicyHash() => r'169d22cec9725ca611ef0064fb5e6a8d2a59b40a';

/// The owner's policy for one workspace, as the server holds it now.
/// #1625 — keyed by installation, account and workspace; an answer for
/// another workspace is refused, and one that arrives after the context
/// was switched, signed out of or revoked is discarded.

final class McpPolicyFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<McpPolicy>, McpContextRef> {
  McpPolicyFamily._()
    : super(
        retry: null,
        name: r'mcpPolicyProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The owner's policy for one workspace, as the server holds it now.
  /// #1625 — keyed by installation, account and workspace; an answer for
  /// another workspace is refused, and one that arrives after the context
  /// was switched, signed out of or revoked is discarded.

  McpPolicyProvider call(McpContextRef context) =>
      McpPolicyProvider._(argument: context, from: this);

  @override
  String toString() => r'mcpPolicyProvider';
}

/// #1625 — the six separate facts for one person on one workspace.

@ProviderFor(mcpAccessStatus)
final mcpAccessStatusProvider = McpAccessStatusFamily._();

/// #1625 — the six separate facts for one person on one workspace.

final class McpAccessStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<McpAccessStatus>,
          McpAccessStatus,
          FutureOr<McpAccessStatus>
        >
    with $FutureModifier<McpAccessStatus>, $FutureProvider<McpAccessStatus> {
  /// #1625 — the six separate facts for one person on one workspace.
  McpAccessStatusProvider._({
    required McpAccessStatusFamily super.from,
    required McpContextRef super.argument,
  }) : super(
         retry: null,
         name: r'mcpAccessStatusProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mcpAccessStatusHash();

  @override
  String toString() {
    return r'mcpAccessStatusProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<McpAccessStatus> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<McpAccessStatus> create(Ref ref) {
    final argument = this.argument as McpContextRef;
    return mcpAccessStatus(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is McpAccessStatusProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mcpAccessStatusHash() => r'cb48ecb641949fa1b8cae426601efd3e881e636e';

/// #1625 — the six separate facts for one person on one workspace.

final class McpAccessStatusFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<McpAccessStatus>, McpContextRef> {
  McpAccessStatusFamily._()
    : super(
        retry: null,
        name: r'mcpAccessStatusProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #1625 — the six separate facts for one person on one workspace.

  McpAccessStatusProvider call(McpContextRef context) =>
      McpAccessStatusProvider._(argument: context, from: this);

  @override
  String toString() => r'mcpAccessStatusProvider';
}

/// #1630 — the workspace's assistant usage over 30 days, counts only.
/// An answer for another workspace is refused, not shown.

@ProviderFor(mcpWorkspaceUsage)
final mcpWorkspaceUsageProvider = McpWorkspaceUsageFamily._();

/// #1630 — the workspace's assistant usage over 30 days, counts only.
/// An answer for another workspace is refused, not shown.

final class McpWorkspaceUsageProvider
    extends
        $FunctionalProvider<
          AsyncValue<McpWorkspaceUsage>,
          McpWorkspaceUsage,
          FutureOr<McpWorkspaceUsage>
        >
    with
        $FutureModifier<McpWorkspaceUsage>,
        $FutureProvider<McpWorkspaceUsage> {
  /// #1630 — the workspace's assistant usage over 30 days, counts only.
  /// An answer for another workspace is refused, not shown.
  McpWorkspaceUsageProvider._({
    required McpWorkspaceUsageFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'mcpWorkspaceUsageProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mcpWorkspaceUsageHash();

  @override
  String toString() {
    return r'mcpWorkspaceUsageProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<McpWorkspaceUsage> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<McpWorkspaceUsage> create(Ref ref) {
    final argument = this.argument as String;
    return mcpWorkspaceUsage(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is McpWorkspaceUsageProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mcpWorkspaceUsageHash() => r'c4e7b93ab6adddb709f87f23dba15e3f52657ba4';

/// #1630 — the workspace's assistant usage over 30 days, counts only.
/// An answer for another workspace is refused, not shown.

final class McpWorkspaceUsageFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<McpWorkspaceUsage>, String> {
  McpWorkspaceUsageFamily._()
    : super(
        retry: null,
        name: r'mcpWorkspaceUsageProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #1630 — the workspace's assistant usage over 30 days, counts only.
  /// An answer for another workspace is refused, not shown.

  McpWorkspaceUsageProvider call(String workspaceId) =>
      McpWorkspaceUsageProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'mcpWorkspaceUsageProvider';
}

/// #1630 — this person's own assistant usage today.

@ProviderFor(myMcpUsage)
final myMcpUsageProvider = MyMcpUsageProvider._();

/// #1630 — this person's own assistant usage today.

final class MyMcpUsageProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<McpClientUsage>>,
          List<McpClientUsage>,
          FutureOr<List<McpClientUsage>>
        >
    with
        $FutureModifier<List<McpClientUsage>>,
        $FutureProvider<List<McpClientUsage>> {
  /// #1630 — this person's own assistant usage today.
  MyMcpUsageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myMcpUsageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myMcpUsageHash();

  @$internal
  @override
  $FutureProviderElement<List<McpClientUsage>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<McpClientUsage>> create(Ref ref) {
    return myMcpUsage(ref);
  }
}

String _$myMcpUsageHash() => r'34626a01dcf0c0e9974f5c5498f520b71fe55f12';

@ProviderFor(mcpPolicyEditor)
final mcpPolicyEditorProvider = McpPolicyEditorProvider._();

final class McpPolicyEditorProvider
    extends
        $FunctionalProvider<McpPolicyEditor, McpPolicyEditor, McpPolicyEditor>
    with $Provider<McpPolicyEditor> {
  McpPolicyEditorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mcpPolicyEditorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mcpPolicyEditorHash();

  @$internal
  @override
  $ProviderElement<McpPolicyEditor> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  McpPolicyEditor create(Ref ref) {
    return mcpPolicyEditor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(McpPolicyEditor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<McpPolicyEditor>(value),
    );
  }
}

String _$mcpPolicyEditorHash() => r'5cf5176e3714d6df21cad8481a9dd1d5ef04dcde';

/// The pending eligibility requests on this database (administrators only).
/// #1625 — the installation's queue, whatever workspace is selected.

@ProviderFor(eligibilityRequests)
final eligibilityRequestsProvider = EligibilityRequestsProvider._();

/// The pending eligibility requests on this database (administrators only).
/// #1625 — the installation's queue, whatever workspace is selected.

final class EligibilityRequestsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<EligibilityRequest>>,
          List<EligibilityRequest>,
          FutureOr<List<EligibilityRequest>>
        >
    with
        $FutureModifier<List<EligibilityRequest>>,
        $FutureProvider<List<EligibilityRequest>> {
  /// The pending eligibility requests on this database (administrators only).
  /// #1625 — the installation's queue, whatever workspace is selected.
  EligibilityRequestsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eligibilityRequestsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eligibilityRequestsHash();

  @$internal
  @override
  $FutureProviderElement<List<EligibilityRequest>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<EligibilityRequest>> create(Ref ref) {
    return eligibilityRequests(ref);
  }
}

String _$eligibilityRequestsHash() =>
    r'c2f005b9e3252ade237480a4a10f00242c7cafd0';

@ProviderFor(eligibilityReview)
final eligibilityReviewProvider = EligibilityReviewProvider._();

final class EligibilityReviewProvider
    extends
        $FunctionalProvider<
          EligibilityReview,
          EligibilityReview,
          EligibilityReview
        >
    with $Provider<EligibilityReview> {
  EligibilityReviewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eligibilityReviewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eligibilityReviewHash();

  @$internal
  @override
  $ProviderElement<EligibilityReview> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EligibilityReview create(Ref ref) {
    return eligibilityReview(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EligibilityReview value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EligibilityReview>(value),
    );
  }
}

String _$eligibilityReviewHash() => r'803e70d448affcff27b8b93fd16acfaf11f45413';

@ProviderFor(assistantAccess)
final assistantAccessProvider = AssistantAccessProvider._();

final class AssistantAccessProvider
    extends
        $FunctionalProvider<AssistantAccess, AssistantAccess, AssistantAccess>
    with $Provider<AssistantAccess> {
  AssistantAccessProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assistantAccessProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assistantAccessHash();

  @$internal
  @override
  $ProviderElement<AssistantAccess> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AssistantAccess create(Ref ref) {
    return assistantAccess(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AssistantAccess value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AssistantAccess>(value),
    );
  }
}

String _$assistantAccessHash() => r'0d97c437347dfea75eae6255350d942121cd5e7c';
