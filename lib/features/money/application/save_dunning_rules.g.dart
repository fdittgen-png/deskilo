// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'save_dunning_rules.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The dunning policy's one write.

@ProviderFor(saveDunningRules)
final saveDunningRulesProvider = SaveDunningRulesProvider._();

/// The dunning policy's one write.

final class SaveDunningRulesProvider
    extends
        $FunctionalProvider<
          SaveDunningRules,
          SaveDunningRules,
          SaveDunningRules
        >
    with $Provider<SaveDunningRules> {
  /// The dunning policy's one write.
  SaveDunningRulesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'saveDunningRulesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saveDunningRulesHash();

  @$internal
  @override
  $ProviderElement<SaveDunningRules> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SaveDunningRules create(Ref ref) {
    return saveDunningRules(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaveDunningRules value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaveDunningRules>(value),
    );
  }
}

String _$saveDunningRulesHash() => r'3c9081d9aea07ed327aa1691023e2272b367a6cd';
