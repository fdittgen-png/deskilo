// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'money_focus_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One-shot "open the Money tab on this period" request (#718): the
/// calendar hub sets it before switching branches; the Money screen
/// consumes it and clears it. Same shape and reason as
/// [PlanFocusController] (#182) — the branch is kept alive by the
/// shell, so route params cannot reach it.

@ProviderFor(MoneyFocusController)
final moneyFocusControllerProvider = MoneyFocusControllerProvider._();

/// One-shot "open the Money tab on this period" request (#718): the
/// calendar hub sets it before switching branches; the Money screen
/// consumes it and clears it. Same shape and reason as
/// [PlanFocusController] (#182) — the branch is kept alive by the
/// shell, so route params cannot reach it.
final class MoneyFocusControllerProvider
    extends $NotifierProvider<MoneyFocusController, String?> {
  /// One-shot "open the Money tab on this period" request (#718): the
  /// calendar hub sets it before switching branches; the Money screen
  /// consumes it and clears it. Same shape and reason as
  /// [PlanFocusController] (#182) — the branch is kept alive by the
  /// shell, so route params cannot reach it.
  MoneyFocusControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'moneyFocusControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$moneyFocusControllerHash();

  @$internal
  @override
  MoneyFocusController create() => MoneyFocusController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$moneyFocusControllerHash() =>
    r'17be3642af755bdeb75ca57ef832763e32acc97b';

/// One-shot "open the Money tab on this period" request (#718): the
/// calendar hub sets it before switching branches; the Money screen
/// consumes it and clears it. Same shape and reason as
/// [PlanFocusController] (#182) — the branch is kept alive by the
/// shell, so route params cannot reach it.

abstract class _$MoneyFocusController extends $Notifier<String?> {
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
