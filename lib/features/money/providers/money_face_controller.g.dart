// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'money_face_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which face of the Finances tab is showing (#720). Kept alive so a
/// deep link (the calendar hub landing on a payment, an invoice row)
/// can pick the face before the screen is built, and so the tab
/// survives leaving and returning — the same idiom as the inbox tab.

@ProviderFor(MoneyFaceController)
final moneyFaceControllerProvider = MoneyFaceControllerProvider._();

/// Which face of the Finances tab is showing (#720). Kept alive so a
/// deep link (the calendar hub landing on a payment, an invoice row)
/// can pick the face before the screen is built, and so the tab
/// survives leaving and returning — the same idiom as the inbox tab.
final class MoneyFaceControllerProvider
    extends $NotifierProvider<MoneyFaceController, MoneyFace> {
  /// Which face of the Finances tab is showing (#720). Kept alive so a
  /// deep link (the calendar hub landing on a payment, an invoice row)
  /// can pick the face before the screen is built, and so the tab
  /// survives leaving and returning — the same idiom as the inbox tab.
  MoneyFaceControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'moneyFaceControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$moneyFaceControllerHash();

  @$internal
  @override
  MoneyFaceController create() => MoneyFaceController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MoneyFace value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MoneyFace>(value),
    );
  }
}

String _$moneyFaceControllerHash() =>
    r'23dbde1ec4e6d708dbce73b7fbdee1700bf79f74';

/// Which face of the Finances tab is showing (#720). Kept alive so a
/// deep link (the calendar hub landing on a payment, an invoice row)
/// can pick the face before the screen is built, and so the tab
/// survives leaving and returning — the same idiom as the inbox tab.

abstract class _$MoneyFaceController extends $Notifier<MoneyFace> {
  MoneyFace build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<MoneyFace, MoneyFace>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MoneyFace, MoneyFace>,
              MoneyFace,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
