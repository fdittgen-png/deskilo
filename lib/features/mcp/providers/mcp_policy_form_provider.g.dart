// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_policy_form_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(McpPolicyForm)
final mcpPolicyFormProvider = McpPolicyFormProvider._();

final class McpPolicyFormProvider
    extends $NotifierProvider<McpPolicyForm, McpPolicyFormState> {
  McpPolicyFormProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mcpPolicyFormProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mcpPolicyFormHash();

  @$internal
  @override
  McpPolicyForm create() => McpPolicyForm();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(McpPolicyFormState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<McpPolicyFormState>(value),
    );
  }
}

String _$mcpPolicyFormHash() => r'cd69adfd5febd1cfa1654199eab49a73c70fea97';

abstract class _$McpPolicyForm extends $Notifier<McpPolicyFormState> {
  McpPolicyFormState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<McpPolicyFormState, McpPolicyFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<McpPolicyFormState, McpPolicyFormState>,
              McpPolicyFormState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
