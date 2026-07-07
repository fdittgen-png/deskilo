// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The level shown on the Plan tab (defaults to the first level).

@ProviderFor(SelectedLevelId)
final selectedLevelIdProvider = SelectedLevelIdProvider._();

/// The level shown on the Plan tab (defaults to the first level).
final class SelectedLevelIdProvider
    extends $NotifierProvider<SelectedLevelId, String?> {
  /// The level shown on the Plan tab (defaults to the first level).
  SelectedLevelIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedLevelIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedLevelIdHash();

  @$internal
  @override
  SelectedLevelId create() => SelectedLevelId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$selectedLevelIdHash() => r'4b763f39f40f8d633a34ed42491b4b9e799e664b';

/// The level shown on the Plan tab (defaults to the first level).

abstract class _$SelectedLevelId extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
