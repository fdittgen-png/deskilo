// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'held_setup_choices.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HeldSetupChoicesController)
final heldSetupChoicesControllerProvider =
    HeldSetupChoicesControllerProvider._();

final class HeldSetupChoicesControllerProvider
    extends $NotifierProvider<HeldSetupChoicesController, HeldSetupChoices?> {
  HeldSetupChoicesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'heldSetupChoicesControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$heldSetupChoicesControllerHash();

  @$internal
  @override
  HeldSetupChoicesController create() => HeldSetupChoicesController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HeldSetupChoices? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HeldSetupChoices?>(value),
    );
  }
}

String _$heldSetupChoicesControllerHash() =>
    r'a69f1b753431f824dd36e0210b494d57a86fa8d7';

abstract class _$HeldSetupChoicesController
    extends $Notifier<HeldSetupChoices?> {
  HeldSetupChoices? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<HeldSetupChoices?, HeldSetupChoices?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<HeldSetupChoices?, HeldSetupChoices?>,
              HeldSetupChoices?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
