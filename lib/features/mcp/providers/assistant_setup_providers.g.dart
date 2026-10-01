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
