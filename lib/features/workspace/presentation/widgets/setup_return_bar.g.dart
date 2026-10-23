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
