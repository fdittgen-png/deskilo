// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assistant_setup_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #1827 — the setup checklist for one person on one workspace. The four
/// server answers are asked in parallel; one that fails is `unavailable`
/// on its step, never a reason to hide the others. A switch of workspace,
/// account or installation while they are pending discards the answer.

@ProviderFor(assistantSetup)
final assistantSetupProvider = AssistantSetupFamily._();

/// #1827 — the setup checklist for one person on one workspace. The four
/// server answers are asked in parallel; one that fails is `unavailable`
/// on its step, never a reason to hide the others. A switch of workspace,
/// account or installation while they are pending discards the answer.

final class AssistantSetupProvider
    extends
        $FunctionalProvider<
          AsyncValue<AssistantSetup>,
          AssistantSetup,
          FutureOr<AssistantSetup>
        >
    with $FutureModifier<AssistantSetup>, $FutureProvider<AssistantSetup> {
  /// #1827 — the setup checklist for one person on one workspace. The four
  /// server answers are asked in parallel; one that fails is `unavailable`
  /// on its step, never a reason to hide the others. A switch of workspace,
  /// account or installation while they are pending discards the answer.
  AssistantSetupProvider._({
    required AssistantSetupFamily super.from,
    required McpContextRef super.argument,
  }) : super(
         retry: null,
         name: r'assistantSetupProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$assistantSetupHash();

  @override
  String toString() {
    return r'assistantSetupProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AssistantSetup> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AssistantSetup> create(Ref ref) {
    final argument = this.argument as McpContextRef;
    return assistantSetup(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AssistantSetupProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$assistantSetupHash() => r'a8fa5090870033a7b6132b3367c82e316e40e288';

/// #1827 — the setup checklist for one person on one workspace. The four
/// server answers are asked in parallel; one that fails is `unavailable`
/// on its step, never a reason to hide the others. A switch of workspace,
/// account or installation while they are pending discards the answer.

final class AssistantSetupFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AssistantSetup>, McpContextRef> {
  AssistantSetupFamily._()
    : super(
        retry: null,
        name: r'assistantSetupProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #1827 — the setup checklist for one person on one workspace. The four
  /// server answers are asked in parallel; one that fails is `unavailable`
  /// on its step, never a reason to hide the others. A switch of workspace,
  /// account or installation while they are pending discards the answer.

  AssistantSetupProvider call(McpContextRef context) =>
      AssistantSetupProvider._(argument: context, from: this);

  @override
  String toString() => r'assistantSetupProvider';
}

/// #1827 — the connector URL of the backend this process talks to; null
/// in Demo and tests, which run without one.

@ProviderFor(mcpConnectorUrl)
final mcpConnectorUrlProvider = McpConnectorUrlProvider._();

/// #1827 — the connector URL of the backend this process talks to; null
/// in Demo and tests, which run without one.

final class McpConnectorUrlProvider
    extends $FunctionalProvider<Uri?, Uri?, Uri?>
    with $Provider<Uri?> {
  /// #1827 — the connector URL of the backend this process talks to; null
  /// in Demo and tests, which run without one.
  McpConnectorUrlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mcpConnectorUrlProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mcpConnectorUrlHash();

  @$internal
  @override
  $ProviderElement<Uri?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Uri? create(Ref ref) {
    return mcpConnectorUrl(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Uri? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Uri?>(value),
    );
  }
}

String _$mcpConnectorUrlHash() => r'2ae8328373a088582ecf4159bc2e5ba1af91cd82';

/// #2145 — what consent would offer this person on this installation:
/// every workspace whose owner offers assistants, with the operations
/// this person may use there. Read through the active target's client.

@ProviderFor(myMcpConsentOptions)
final myMcpConsentOptionsProvider = MyMcpConsentOptionsProvider._();

/// #2145 — what consent would offer this person on this installation:
/// every workspace whose owner offers assistants, with the operations
/// this person may use there. Read through the active target's client.

final class MyMcpConsentOptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ConsentOptions>,
          ConsentOptions,
          FutureOr<ConsentOptions>
        >
    with $FutureModifier<ConsentOptions>, $FutureProvider<ConsentOptions> {
  /// #2145 — what consent would offer this person on this installation:
  /// every workspace whose owner offers assistants, with the operations
  /// this person may use there. Read through the active target's client.
  MyMcpConsentOptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myMcpConsentOptionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myMcpConsentOptionsHash();

  @$internal
  @override
  $FutureProviderElement<ConsentOptions> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ConsentOptions> create(Ref ref) {
    return myMcpConsentOptions(ref);
  }
}

String _$myMcpConsentOptionsHash() =>
    r'40ceb9f84686299222a619c65e2d945de9df8024';

/// #2145 — the 0358 onboarding RPCs: consent status, published endpoint,
/// installation notices.

@ProviderFor(mcpOnboardingRepository)
final mcpOnboardingRepositoryProvider = McpOnboardingRepositoryProvider._();

/// #2145 — the 0358 onboarding RPCs: consent status, published endpoint,
/// installation notices.

final class McpOnboardingRepositoryProvider
    extends
        $FunctionalProvider<
          McpOnboardingRepository,
          McpOnboardingRepository,
          McpOnboardingRepository
        >
    with $Provider<McpOnboardingRepository> {
  /// #2145 — the 0358 onboarding RPCs: consent status, published endpoint,
  /// installation notices.
  McpOnboardingRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mcpOnboardingRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mcpOnboardingRepositoryHash();

  @$internal
  @override
  $ProviderElement<McpOnboardingRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  McpOnboardingRepository create(Ref ref) {
    return mcpOnboardingRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(McpOnboardingRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<McpOnboardingRepository>(value),
    );
  }
}

String _$mcpOnboardingRepositoryHash() =>
    r'c277d66fd443dfda333a208bdd3c7deafaddd917';

/// #2145 — the client, its approval and who decides, for one pending
/// authorization; read BEFORE Auth is asked for the authorization itself.

@ProviderFor(mcpConsentStatus)
final mcpConsentStatusProvider = McpConsentStatusFamily._();

/// #2145 — the client, its approval and who decides, for one pending
/// authorization; read BEFORE Auth is asked for the authorization itself.

final class McpConsentStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<ConsentStatus>,
          ConsentStatus,
          FutureOr<ConsentStatus>
        >
    with $FutureModifier<ConsentStatus>, $FutureProvider<ConsentStatus> {
  /// #2145 — the client, its approval and who decides, for one pending
  /// authorization; read BEFORE Auth is asked for the authorization itself.
  McpConsentStatusProvider._({
    required McpConsentStatusFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'mcpConsentStatusProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mcpConsentStatusHash();

  @override
  String toString() {
    return r'mcpConsentStatusProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ConsentStatus> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ConsentStatus> create(Ref ref) {
    final argument = this.argument as String;
    return mcpConsentStatus(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is McpConsentStatusProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mcpConsentStatusHash() => r'a40bcb921a0f0ab362684b6271e0f480d16d92ed';

/// #2145 — the client, its approval and who decides, for one pending
/// authorization; read BEFORE Auth is asked for the authorization itself.

final class McpConsentStatusFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ConsentStatus>, String> {
  McpConsentStatusFamily._()
    : super(
        retry: null,
        name: r'mcpConsentStatusProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #2145 — the client, its approval and who decides, for one pending
  /// authorization; read BEFORE Auth is asked for the authorization itself.

  McpConsentStatusProvider call(String authorizationId) =>
      McpConsentStatusProvider._(argument: authorizationId, from: this);

  @override
  String toString() => r'mcpConsentStatusProvider';
}

/// #2145 — the endpoint this installation publishes for assistants.

@ProviderFor(mcpPublishedEndpoint)
final mcpPublishedEndpointProvider = McpPublishedEndpointProvider._();

/// #2145 — the endpoint this installation publishes for assistants.

final class McpPublishedEndpointProvider
    extends
        $FunctionalProvider<
          AsyncValue<McpEndpointInfo>,
          McpEndpointInfo,
          FutureOr<McpEndpointInfo>
        >
    with $FutureModifier<McpEndpointInfo>, $FutureProvider<McpEndpointInfo> {
  /// #2145 — the endpoint this installation publishes for assistants.
  McpPublishedEndpointProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mcpPublishedEndpointProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mcpPublishedEndpointHash();

  @$internal
  @override
  $FutureProviderElement<McpEndpointInfo> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<McpEndpointInfo> create(Ref ref) {
    return mcpPublishedEndpoint(ref);
  }
}

String _$mcpPublishedEndpointHash() =>
    r'f4ddd7443df412684248e7800a689ee018710f4e';

/// #2145 — the installation notices addressed to the caller.

@ProviderFor(myInstanceNotices)
final myInstanceNoticesProvider = MyInstanceNoticesProvider._();

/// #2145 — the installation notices addressed to the caller.

final class MyInstanceNoticesProvider
    extends
        $FunctionalProvider<
          AsyncValue<InstanceNotices>,
          InstanceNotices,
          FutureOr<InstanceNotices>
        >
    with $FutureModifier<InstanceNotices>, $FutureProvider<InstanceNotices> {
  /// #2145 — the installation notices addressed to the caller.
  MyInstanceNoticesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myInstanceNoticesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myInstanceNoticesHash();

  @$internal
  @override
  $FutureProviderElement<InstanceNotices> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InstanceNotices> create(Ref ref) {
    return myInstanceNotices(ref);
  }
}

String _$myInstanceNoticesHash() => r'4c265493c570e19570f1812247dedf347f7056c7';
