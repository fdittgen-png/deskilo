// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setup_return_bar.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether a step of the setup guide is open over the guide.

@ProviderFor(SetupReturnPending)
final setupReturnPendingProvider = SetupReturnPendingProvider._();

/// Whether a step of the setup guide is open over the guide.
final class SetupReturnPendingProvider
    extends $NotifierProvider<SetupReturnPending, bool> {
  /// Whether a step of the setup guide is open over the guide.
  SetupReturnPendingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'setupReturnPendingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$setupReturnPendingHash();

  @$internal
  @override
  SetupReturnPending create() => SetupReturnPending();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$setupReturnPendingHash() =>
    r'0f4bc54b08c63d3114e5f5c064fa4d51bad6568c';

/// Whether a step of the setup guide is open over the guide.

abstract class _$SetupReturnPending extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// #3076 — the step of the guide that is open over it; null when none.

@ProviderFor(SetupOpenStep)
final setupOpenStepProvider = SetupOpenStepProvider._();

/// #3076 — the step of the guide that is open over it; null when none.
final class SetupOpenStepProvider
    extends $NotifierProvider<SetupOpenStep, String?> {
  /// #3076 — the step of the guide that is open over it; null when none.
  SetupOpenStepProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'setupOpenStepProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$setupOpenStepHash();

  @$internal
  @override
  SetupOpenStep create() => SetupOpenStep();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$setupOpenStepHash() => r'3c2e415f3eae40ec2edf95a91425f6af74ad3dbd';

/// #3076 — the step of the guide that is open over it; null when none.

abstract class _$SetupOpenStep extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
