// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'help_arbiter.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HelpArbiter)
final helpArbiterProvider = HelpArbiterProvider._();

final class HelpArbiterProvider
    extends $NotifierProvider<HelpArbiter, HelpArbiterState> {
  HelpArbiterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'helpArbiterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$helpArbiterHash();

  @$internal
  @override
  HelpArbiter create() => HelpArbiter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HelpArbiterState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HelpArbiterState>(value),
    );
  }
}

String _$helpArbiterHash() => r'0c8e8aaf3fb79cf377bfe11e84091e94433c8845';

abstract class _$HelpArbiter extends $Notifier<HelpArbiterState> {
  HelpArbiterState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<HelpArbiterState, HelpArbiterState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<HelpArbiterState, HelpArbiterState>,
              HelpArbiterState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// What the single help surface shows now.

@ProviderFor(helpSlot)
final helpSlotProvider = HelpSlotProvider._();

/// What the single help surface shows now.

final class HelpSlotProvider
    extends $FunctionalProvider<HelpSlot, HelpSlot, HelpSlot>
    with $Provider<HelpSlot> {
  /// What the single help surface shows now.
  HelpSlotProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'helpSlotProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$helpSlotHash();

  @$internal
  @override
  $ProviderElement<HelpSlot> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HelpSlot create(Ref ref) {
    return helpSlot(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HelpSlot value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HelpSlot>(value),
    );
  }
}

String _$helpSlotHash() => r'96d6f70f021e68a51c29adb9cdaa441b0141cbf5';
