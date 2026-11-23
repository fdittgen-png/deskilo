// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_floor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The floor of the installation this device is signed in to (or would
/// sign in to): the personal home's client.

@ProviderFor(appFloorSource)
final appFloorSourceProvider = AppFloorSourceProvider._();

/// The floor of the installation this device is signed in to (or would
/// sign in to): the personal home's client.

final class AppFloorSourceProvider
    extends $FunctionalProvider<AppFloorSource, AppFloorSource, AppFloorSource>
    with $Provider<AppFloorSource> {
  /// The floor of the installation this device is signed in to (or would
  /// sign in to): the personal home's client.
  AppFloorSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appFloorSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appFloorSourceHash();

  @$internal
  @override
  $ProviderElement<AppFloorSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppFloorSource create(Ref ref) {
    return appFloorSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppFloorSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppFloorSource>(value),
    );
  }
}

String _$appFloorSourceHash() => r'e35d35e455d2cfb7aaace33c425737d853e8ddd3';

@ProviderFor(appFloorMemory)
final appFloorMemoryProvider = AppFloorMemoryProvider._();

final class AppFloorMemoryProvider
    extends $FunctionalProvider<AppFloorMemory, AppFloorMemory, AppFloorMemory>
    with $Provider<AppFloorMemory> {
  AppFloorMemoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appFloorMemoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appFloorMemoryHash();

  @$internal
  @override
  $ProviderElement<AppFloorMemory> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppFloorMemory create(Ref ref) {
    return appFloorMemory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppFloorMemory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppFloorMemory>(value),
    );
  }
}

String _$appFloorMemoryHash() => r'2f959cf3f629c95b8032d9664c02d57ad44eb1b8';

/// How the installation this device uses judges this app.
///
/// - A successful answer decides, and is remembered.
/// - A failed read keeps the remembered verdict: an installation known to
///   refuse this app stays refused while it cannot be asked. A floor never
///   read is [AppFloorVerdict.unknown], which never blocks.
/// - It is asked again each time the app returns to the foreground (an
///   event, never a timer), so a lowered floor or an updated installation
///   is seen without a restart.

@ProviderFor(appFloor)
final appFloorProvider = AppFloorProvider._();

/// How the installation this device uses judges this app.
///
/// - A successful answer decides, and is remembered.
/// - A failed read keeps the remembered verdict: an installation known to
///   refuse this app stays refused while it cannot be asked. A floor never
///   read is [AppFloorVerdict.unknown], which never blocks.
/// - It is asked again each time the app returns to the foreground (an
///   event, never a timer), so a lowered floor or an updated installation
///   is seen without a restart.

final class AppFloorProvider
    extends
        $FunctionalProvider<
          AsyncValue<AppFloorVerdict>,
          AppFloorVerdict,
          FutureOr<AppFloorVerdict>
        >
    with $FutureModifier<AppFloorVerdict>, $FutureProvider<AppFloorVerdict> {
  /// How the installation this device uses judges this app.
  ///
  /// - A successful answer decides, and is remembered.
  /// - A failed read keeps the remembered verdict: an installation known to
  ///   refuse this app stays refused while it cannot be asked. A floor never
  ///   read is [AppFloorVerdict.unknown], which never blocks.
  /// - It is asked again each time the app returns to the foreground (an
  ///   event, never a timer), so a lowered floor or an updated installation
  ///   is seen without a restart.
  AppFloorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appFloorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appFloorHash();

  @$internal
  @override
  $FutureProviderElement<AppFloorVerdict> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AppFloorVerdict> create(Ref ref) {
    return appFloor(ref);
  }
}

String _$appFloorHash() => r'45fbc4ec1bec07aa7c54d154e7470fd6be9c35a9';
