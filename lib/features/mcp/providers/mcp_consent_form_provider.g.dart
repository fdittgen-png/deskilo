// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_consent_form_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(McpConsentForm)
final mcpConsentFormProvider = McpConsentFormProvider._();

final class McpConsentFormProvider
    extends $NotifierProvider<McpConsentForm, McpConsentFormState> {
  McpConsentFormProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mcpConsentFormProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mcpConsentFormHash();

  @$internal
  @override
  McpConsentForm create() => McpConsentForm();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(McpConsentFormState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<McpConsentFormState>(value),
    );
  }
}

String _$mcpConsentFormHash() => r'cfdbf4909b93e7edcee6003a627d53113ad13436';

abstract class _$McpConsentForm extends $Notifier<McpConsentFormState> {
  McpConsentFormState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<McpConsentFormState, McpConsentFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<McpConsentFormState, McpConsentFormState>,
              McpConsentFormState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
