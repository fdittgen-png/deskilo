// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apply_approvals_preset.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The approvals step's write of the default rule.

@ProviderFor(applyApprovalsPreset)
final applyApprovalsPresetProvider = ApplyApprovalsPresetProvider._();

/// The approvals step's write of the default rule.

final class ApplyApprovalsPresetProvider
    extends
        $FunctionalProvider<
          ApplyApprovalsPreset,
          ApplyApprovalsPreset,
          ApplyApprovalsPreset
        >
    with $Provider<ApplyApprovalsPreset> {
  /// The approvals step's write of the default rule.
  ApplyApprovalsPresetProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'applyApprovalsPresetProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$applyApprovalsPresetHash();

  @$internal
  @override
  $ProviderElement<ApplyApprovalsPreset> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ApplyApprovalsPreset create(Ref ref) {
    return applyApprovalsPreset(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ApplyApprovalsPreset value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ApplyApprovalsPreset>(value),
    );
  }
}

String _$applyApprovalsPresetHash() =>
    r'c1fde03d673257548470ee922b5813cd1627746e';
