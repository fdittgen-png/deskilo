// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'save_allocation_rule.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #2582 — saving a revision of an allocation rule.

@ProviderFor(saveAllocationRule)
final saveAllocationRuleProvider = SaveAllocationRuleProvider._();

/// #2582 — saving a revision of an allocation rule.

final class SaveAllocationRuleProvider
    extends
        $FunctionalProvider<
          SaveAllocationRule,
          SaveAllocationRule,
          SaveAllocationRule
        >
    with $Provider<SaveAllocationRule> {
  /// #2582 — saving a revision of an allocation rule.
  SaveAllocationRuleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'saveAllocationRuleProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saveAllocationRuleHash();

  @$internal
  @override
  $ProviderElement<SaveAllocationRule> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SaveAllocationRule create(Ref ref) {
    return saveAllocationRule(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaveAllocationRule value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaveAllocationRule>(value),
    );
  }
}

String _$saveAllocationRuleHash() =>
    r'eed57c2a83ab6dd9f8bb0504a1a98c8432994cc2';
