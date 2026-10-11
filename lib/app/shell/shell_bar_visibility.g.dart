// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shell_bar_visibility.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(shellBarHiddenStore)
final shellBarHiddenStoreProvider = ShellBarHiddenStoreProvider._();

final class ShellBarHiddenStoreProvider
    extends $FunctionalProvider<ShellFlagStore, ShellFlagStore, ShellFlagStore>
    with $Provider<ShellFlagStore> {
  ShellBarHiddenStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shellBarHiddenStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shellBarHiddenStoreHash();

  @$internal
  @override
  $ProviderElement<ShellFlagStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShellFlagStore create(Ref ref) {
    return shellBarHiddenStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShellFlagStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShellFlagStore>(value),
    );
  }
}

String _$shellBarHiddenStoreHash() =>
    r'5664c5d5ee64202c69404c11402d1ba7dd88a390';

@ProviderFor(shellSwipeCoachStore)
final shellSwipeCoachStoreProvider = ShellSwipeCoachStoreProvider._();

final class ShellSwipeCoachStoreProvider
    extends $FunctionalProvider<ShellFlagStore, ShellFlagStore, ShellFlagStore>
    with $Provider<ShellFlagStore> {
  ShellSwipeCoachStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shellSwipeCoachStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shellSwipeCoachStoreHash();

  @$internal
  @override
  $ProviderElement<ShellFlagStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShellFlagStore create(Ref ref) {
    return shellSwipeCoachStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShellFlagStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShellFlagStore>(value),
    );
  }
}

String _$shellSwipeCoachStoreHash() =>
    r'442e2160e00d71304e62b9f4f5c23b2fe08dc0c3';

/// The swiped-away state. Loading reads as SHOWN: the safe state, since
/// it is the one that carries its own way out.

@ProviderFor(ShellBarHidden)
final shellBarHiddenProvider = ShellBarHiddenProvider._();

/// The swiped-away state. Loading reads as SHOWN: the safe state, since
/// it is the one that carries its own way out.
final class ShellBarHiddenProvider
    extends $AsyncNotifierProvider<ShellBarHidden, bool> {
  /// The swiped-away state. Loading reads as SHOWN: the safe state, since
  /// it is the one that carries its own way out.
  ShellBarHiddenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shellBarHiddenProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shellBarHiddenHash();

  @$internal
  @override
  ShellBarHidden create() => ShellBarHidden();
}

String _$shellBarHiddenHash() => r'1b9fea1a78be6ff0be35a156848a245251381bc1';

/// The swiped-away state. Loading reads as SHOWN: the safe state, since
/// it is the one that carries its own way out.

abstract class _$ShellBarHidden extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether the swipe coach mark has been shown (#1173).
///
/// Once ever, like the tip carousels of #610: a gesture needs
/// introducing exactly one time, and a hint that returns is an
/// annoyance rather than help. Loading reads as SEEN, so a member can
/// never be shown a hint that cannot be remembered as dismissed.

@ProviderFor(ShellSwipeCoachSeen)
final shellSwipeCoachSeenProvider = ShellSwipeCoachSeenProvider._();

/// Whether the swipe coach mark has been shown (#1173).
///
/// Once ever, like the tip carousels of #610: a gesture needs
/// introducing exactly one time, and a hint that returns is an
/// annoyance rather than help. Loading reads as SEEN, so a member can
/// never be shown a hint that cannot be remembered as dismissed.
final class ShellSwipeCoachSeenProvider
    extends $AsyncNotifierProvider<ShellSwipeCoachSeen, bool> {
  /// Whether the swipe coach mark has been shown (#1173).
  ///
  /// Once ever, like the tip carousels of #610: a gesture needs
  /// introducing exactly one time, and a hint that returns is an
  /// annoyance rather than help. Loading reads as SEEN, so a member can
  /// never be shown a hint that cannot be remembered as dismissed.
  ShellSwipeCoachSeenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shellSwipeCoachSeenProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shellSwipeCoachSeenHash();

  @$internal
  @override
  ShellSwipeCoachSeen create() => ShellSwipeCoachSeen();
}

String _$shellSwipeCoachSeenHash() =>
    r'bdf9d0d487fbd4c3c5b9dcb5be97b1072cfb9ca7';

/// Whether the swipe coach mark has been shown (#1173).
///
/// Once ever, like the tip carousels of #610: a gesture needs
/// introducing exactly one time, and a hint that returns is an
/// annoyance rather than help. Loading reads as SEEN, so a member can
/// never be shown a hint that cannot be remembered as dismissed.

abstract class _$ShellSwipeCoachSeen extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(shellBarProgress)
final shellBarProgressProvider = ShellBarProgressProvider._();

final class ShellBarProgressProvider
    extends $FunctionalProvider<ShellBarMotion, ShellBarMotion, ShellBarMotion>
    with $Provider<ShellBarMotion> {
  ShellBarProgressProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shellBarProgressProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shellBarProgressHash();

  @$internal
  @override
  $ProviderElement<ShellBarMotion> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShellBarMotion create(Ref ref) {
    return shellBarProgress(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShellBarMotion value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShellBarMotion>(value),
    );
  }
}

String _$shellBarProgressHash() => r'2d499afb48ed9b33aea81adb3734eaae7d2bf35c';
