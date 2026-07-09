// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(localeStore)
final localeStoreProvider = LocaleStoreProvider._();

final class LocaleStoreProvider
    extends $FunctionalProvider<LocaleStore, LocaleStore, LocaleStore>
    with $Provider<LocaleStore> {
  LocaleStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localeStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localeStoreHash();

  @$internal
  @override
  $ProviderElement<LocaleStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocaleStore create(Ref ref) {
    return localeStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocaleStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocaleStore>(value),
    );
  }
}

String _$localeStoreHash() => r'448b8cd7a461a799a01f45d22c045ec4f4251f78';

/// The user's language override; null means "follow the system locale".
/// Feeding this into `MaterialApp.locale` applies a change instantly,
/// no restart needed.

@ProviderFor(LocaleController)
final localeControllerProvider = LocaleControllerProvider._();

/// The user's language override; null means "follow the system locale".
/// Feeding this into `MaterialApp.locale` applies a change instantly,
/// no restart needed.
final class LocaleControllerProvider
    extends $AsyncNotifierProvider<LocaleController, Locale?> {
  /// The user's language override; null means "follow the system locale".
  /// Feeding this into `MaterialApp.locale` applies a change instantly,
  /// no restart needed.
  LocaleControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localeControllerHash();

  @$internal
  @override
  LocaleController create() => LocaleController();
}

String _$localeControllerHash() => r'4707abbd20e9fa8619676b58c4acf35eb7462f06';

/// The user's language override; null means "follow the system locale".
/// Feeding this into `MaterialApp.locale` applies a change instantly,
/// no restart needed.

abstract class _$LocaleController extends $AsyncNotifier<Locale?> {
  FutureOr<Locale?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Locale?>, Locale?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Locale?>, Locale?>,
              AsyncValue<Locale?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
