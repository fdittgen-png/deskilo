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

@ProviderFor(mcpPolicy)
final mcpPolicyProvider = McpPolicyFamily._();

/// The owner's policy for one workspace, as the server holds it now.

final class McpPolicyProvider
    extends
        $FunctionalProvider<
          AsyncValue<McpPolicy>,
          McpPolicy,
          FutureOr<McpPolicy>
        >
    with $FutureModifier<McpPolicy>, $FutureProvider<McpPolicy> {
  /// The owner's policy for one workspace, as the server holds it now.
  McpPolicyProvider._({
    required McpPolicyFamily super.from,
    required String super.argument,
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
    final argument = this.argument as String;
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

String _$mcpPolicyHash() => r'db094c2207d37221f6b29b34a52574efb23c8613';

/// The owner's policy for one workspace, as the server holds it now.

final class McpPolicyFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<McpPolicy>, String> {
  McpPolicyFamily._()
    : super(
        retry: null,
        name: r'mcpPolicyProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The owner's policy for one workspace, as the server holds it now.

  McpPolicyProvider call(String workspaceId) =>
      McpPolicyProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'mcpPolicyProvider';
}

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

String _$mcpPolicyEditorHash() => r'be948e59c62b548b34dda08f7aa9bc2b1ccd63ca';

/// The pending eligibility requests on this database (administrators only).

@ProviderFor(eligibilityRequests)
final eligibilityRequestsProvider = EligibilityRequestsProvider._();

/// The pending eligibility requests on this database (administrators only).

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
    r'6e3c3a4d4a18203eb72646a0ea248fc2305baba5';

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

String _$eligibilityReviewHash() => r'572f7623152a58396a274d9161da0acc2db06ab5';

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

String _$assistantAccessHash() => r'07a7f9dc58dc25bac5393851b614eb48379cce3d';
