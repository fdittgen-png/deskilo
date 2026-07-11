// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_focus_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Cross-tab signal carrier for [PlanFocus] (#182). KeepAlive on purpose:
/// `PlanScreen` lives in the shell's indexed stack, so the request must
/// survive until its listener picks it up after the tab switch — route
/// params can't reach the already-built const screen.

@ProviderFor(PlanFocusController)
final planFocusControllerProvider = PlanFocusControllerProvider._();

/// Cross-tab signal carrier for [PlanFocus] (#182). KeepAlive on purpose:
/// `PlanScreen` lives in the shell's indexed stack, so the request must
/// survive until its listener picks it up after the tab switch — route
/// params can't reach the already-built const screen.
final class PlanFocusControllerProvider
    extends $NotifierProvider<PlanFocusController, PlanFocus?> {
  /// Cross-tab signal carrier for [PlanFocus] (#182). KeepAlive on purpose:
  /// `PlanScreen` lives in the shell's indexed stack, so the request must
  /// survive until its listener picks it up after the tab switch — route
  /// params can't reach the already-built const screen.
  PlanFocusControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'planFocusControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$planFocusControllerHash();

  @$internal
  @override
  PlanFocusController create() => PlanFocusController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlanFocus? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlanFocus?>(value),
    );
  }
}

String _$planFocusControllerHash() =>
    r'8b9ce33885a935e9d0a6650ef0fe24cf32630d86';

/// Cross-tab signal carrier for [PlanFocus] (#182). KeepAlive on purpose:
/// `PlanScreen` lives in the shell's indexed stack, so the request must
/// survive until its listener picks it up after the tab switch — route
/// params can't reach the already-built const screen.

abstract class _$PlanFocusController extends $Notifier<PlanFocus?> {
  PlanFocus? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<PlanFocus?, PlanFocus?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PlanFocus?, PlanFocus?>,
              PlanFocus?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
